import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'language_service.dart';

class VocabularyTabController {
  bool _syncing = false;
  bool _disposed = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Box? _box;
  bool _hiveReady = false;
  String? _boxName;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  Timer? _pendingSyncTimer;
  Timer? _syncDebounce;

  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;
  bool get hiveReady => _hiveReady;
  Box get box => _box!;

  DateTime parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.utc(2000);

    if (value is Timestamp) {
      return value.toDate().toUtc();
    }

    if (value is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toUtc();
      } catch (_) {
        return DateTime.utc(2000);
      }
    }

    if (value is String) {
      try {
        return DateTime.parse(value).toUtc();
      } catch (_) {
        return DateTime.utc(2000);
      }
    }

    return DateTime.utc(2000);
  }

  String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâäãå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[òóôöõ]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y');
  }

  Map<String, dynamic> toStringKeyedMap(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      final out = <String, dynamic>{};
      raw.forEach((k, v) {
        try {
          out[k?.toString() ?? ''] = v;
        } catch (_) {}
      });
      return out;
    }
    return <String, dynamic>{};
  }

  Future<bool> _ensureBoxReady() async {
    if (_disposed) return false;

    final user = _auth.currentUser;
    if (user == null) return false;

    _boxName ??= 'vocab_${user.uid}_${LanguageService.instance.currentLang}';

    if (_box != null && _box!.isOpen) {
      _hiveReady = true;
      return true;
    }

    try {
      if (Hive.isBoxOpen(_boxName!)) {
        _box = Hive.box(_boxName!);
      } else {
        _box = await Hive.openBox(_boxName!);
      }
      _hiveReady = _box != null && _box!.isOpen;
      return _hiveReady;
    } catch (_) {
      _hiveReady = false;
      return false;
    }
  }

  Future<void> initHive() async {
    if (_disposed) return;

    final ok = await _ensureBoxReady();
    if (!ok) return;

    startFirestoreListenerForCurrentUser();
    startSyncTimer();
    // Listen for language changes and switch boxes
    LanguageService.instance.addListener(_onLanguageChanged);
  }

  Future<void> _onLanguageChanged() async {
    if (_disposed) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // cancel listeners and timers
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _pendingSyncTimer?.cancel();
    _pendingSyncTimer = null;

    final newName = 'vocab_${user.uid}_${LanguageService.instance.currentLang}';

    try {
      if (_box != null && _box!.isOpen) await _box!.close();
    } catch (_) {}

    _box = Hive.isBoxOpen(newName)
        ? Hive.box(newName)
        : await Hive.openBox(newName);
    _boxName = newName;
    _hiveReady = _box != null && _box!.isOpen;

    startFirestoreListenerForCurrentUser();
    startSyncTimer();
  }

  void startSyncTimer() {
    _pendingSyncTimer?.cancel();
    _pendingSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _safeSync(),
    );
  }

  void scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(
      const Duration(seconds: 2),
      () => _safeSync(),
    );
  }

  Future<void> _safeSync() async {
    if (_disposed) return;
    try {
      await syncPendingItems();
    } catch (_) {
      // offline safe
    }
  }

  bool _changedWhileSyncing(
    Map<String, dynamic> original,
    Map<String, dynamic> latest,
  ) {
    final originalUpdatedAt = original['updatedAt']?.toString() ?? '';
    final latestUpdatedAt = latest['updatedAt']?.toString() ?? '';
    return originalUpdatedAt != latestUpdatedAt;
  }

  Map<String, dynamic> _buildPayload(
    Map<String, dynamic> v, {
    required bool isCreate,
  }) {
    DateTime? nextReviewDate;
    final nr = v['nextReview'];
    if (nr is String) {
      nextReviewDate = DateTime.tryParse(nr);
    }

    final payload = <String, dynamic>{
      'word': v['word'] ?? '',
      'translation': v['translation'] ?? '',
      'context': v['context'] ?? '',
      'status': v['status'] ?? 'learning',
      'step': v['step'] ?? 0,
      'nextReview': nextReviewDate != null
          ? Timestamp.fromDate(nextReviewDate)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isCreate) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    return payload;
  }

  void startFirestoreListenerForCurrentUser() {
    if (_disposed) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final coll =
        _firestore.collection('users').doc(user.uid).collection('vocabulary');

    _firestoreSub?.cancel();

    _firestoreSub = coll.snapshots().listen((snapshot) async {
      if (_disposed) return;

      final ok = await _ensureBoxReady();
      if (!ok) return;

      for (final change in snapshot.docChanges) {
        if (_disposed) return;

        final ready = await _ensureBoxReady();
        if (!ready) return;

        final doc = change.doc;
        final data = doc.data();
        final localKey = doc.id;

        if (change.type == DocumentChangeType.removed) {
          final localRaw = _box!.get(localKey);
          final local = localRaw != null ? toStringKeyedMap(localRaw) : null;

          if (local != null &&
              local['pending'] == true &&
              local['deleted'] != true) {
            continue;
          }

          await _box!.delete(localKey);
          continue;
        }

        if (data == null) continue;

        final remoteItem = <String, dynamic>{
          'word': data['word'] ?? '',
          'translation': data['translation'] ?? '',
          'context': data['context'] ?? '',
          'status': data['status'] ?? 'learning',
          'step': data['step'] ?? 0,
          'nextReview': data['nextReview'] != null
              ? (data['nextReview'] as Timestamp).toDate().toIso8601String()
              : null,
          'remoteId': doc.id,
          'deleted': false,
          'pending': false,
          'createdAt': parseCreatedAt(data['createdAt']).toIso8601String(),
          'updatedAt': parseCreatedAt(data['updatedAt']).toIso8601String(),
          '__localKey': localKey,
        };

        final localRaw = _box!.get(localKey);
        final local = localRaw != null ? toStringKeyedMap(localRaw) : null;

        if (local == null) {
          await _box!.put(localKey, remoteItem);
          continue;
        }

        if (local['pending'] == true || local['deleted'] == true) {
          continue;
        }

        final localUpdatedAt = parseCreatedAt(local['updatedAt']);
        final remoteUpdatedAt = parseCreatedAt(remoteItem['updatedAt']);

        // Don't overwrite newer local state with older remote snapshot
        if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
          continue;
        }

        final merged = <String, dynamic>{
          ...local,
          ...remoteItem,
          '__localKey': localKey,
        };

        await _box!.put(localKey, merged);
      }
    }, onError: (_) {
      // offline safe
    });
  }

  Future<void> syncPendingItems() async {
    if (_disposed || _syncing) return;

    final ok = await _ensureBoxReady();
    if (!ok) return;

    _syncing = true;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final coll =
          _firestore.collection('users').doc(user.uid).collection('vocabulary');

      final keys = List<dynamic>.from(_box!.keys);

      for (final key in keys) {
        if (_disposed) return;

        final ready = await _ensureBoxReady();
        if (!ready) return;

        final raw = _box!.get(key);
        if (raw == null) continue;

        final v = toStringKeyedMap(raw);
        final remoteId = v['remoteId']?.toString();
        final isDeleted = v['deleted'] == true;
        final isPending = v['pending'] == true;

        if (!isDeleted && !isPending) {
          continue;
        }

        // DELETE
        if (isDeleted) {
          if (remoteId == null || remoteId.isEmpty) {
            await _box!.delete(key);
            continue;
          }

          try {
            await coll.doc(remoteId).delete();

            final readyAfterDelete = await _ensureBoxReady();
            if (!readyAfterDelete) return;

            await _box!.delete(key);
          } catch (_) {
            continue;
          }

          continue;
        }

        if (!isPending) continue;

        final sentSnapshot = Map<String, dynamic>.from(v);
        final payload = _buildPayload(
          sentSnapshot,
          isCreate: remoteId == null || remoteId.isEmpty,
        );

        // CREATE
        if (remoteId == null || remoteId.isEmpty) {
          final newRemoteId = key.toString();

          try {
            await coll.doc(newRemoteId).set(payload, SetOptions(merge: true));

            final readyAfterCreate = await _ensureBoxReady();
            if (!readyAfterCreate) return;

            final latestRaw = _box!.get(key);
            if (latestRaw == null) continue;

            final latest = toStringKeyedMap(latestRaw);
            final changed = _changedWhileSyncing(sentSnapshot, latest);

            final updated = Map<String, dynamic>.from(latest);
            updated['remoteId'] = newRemoteId;
            updated['__localKey'] = key.toString();

            if (latest['deleted'] == true) {
              updated['pending'] = true;
            } else if (changed) {
              updated['pending'] = true;
            } else {
              updated['pending'] = false;
              updated['deleted'] = false;
            }

            updated['updatedAt'] =
                latest['updatedAt'] ?? DateTime.now().toUtc().toIso8601String();
            updated['createdAt'] ??= DateTime.now().toUtc().toIso8601String();

            await _box!.put(key, updated);

            if (updated['pending'] == true) {
              scheduleSync();
            }
          } catch (_) {
            continue;
          }

          continue;
        }

        // UPDATE
        try {
          await coll.doc(remoteId).set(payload, SetOptions(merge: true));

          final readyAfterUpdate = await _ensureBoxReady();
          if (!readyAfterUpdate) return;

          final latestRaw = _box!.get(key);
          if (latestRaw == null) continue;

          final latest = toStringKeyedMap(latestRaw);
          final changed = _changedWhileSyncing(sentSnapshot, latest);

          final updated = Map<String, dynamic>.from(latest);
          updated['remoteId'] = remoteId;
          updated['__localKey'] = latest['__localKey'] ?? key.toString();

          if (latest['deleted'] == true) {
            updated['pending'] = true;
          } else if (changed) {
            updated['pending'] = true;
          } else {
            updated['pending'] = false;
          }

          updated['updatedAt'] =
              latest['updatedAt'] ?? DateTime.now().toUtc().toIso8601String();

          await _box!.put(key, updated);

          if (updated['pending'] == true) {
            scheduleSync();
          }
        } catch (_) {
          continue;
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> addWord({
    required String word,
    required String translation,
    required String context,
  }) async {
    final ok = await _ensureBoxReady();
    if (!ok) return;

    final now = DateTime.now().toUtc();
    final localKey = 'local_${const Uuid().v4()}';

    final item = {
      'word': word,
      'translation': translation,
      'context': context,
      'language': LanguageService.instance.currentLang,
      'status': 'learning',
      'step': 0,
      'nextReview': now.toIso8601String(),
      'pending': true,
      'deleted': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      '__localKey': localKey,
    };

    await _box!.put(localKey, item);
    scheduleSync();
  }

  Future<void> updateWord({
    required String docId,
    required String word,
    required String translation,
    required String context,
  }) async {
    final ok = await _ensureBoxReady();
    if (!ok) return;

    final raw = _box!.get(docId);
    final v = raw != null ? toStringKeyedMap(raw) : null;

    if (v == null) {
      final now = DateTime.now().toUtc();
      final newItem = {
        'word': word,
        'translation': translation,
        'context': context,
        'status': 'learning',
        'step': 0,
        'nextReview': now.toIso8601String(),
        'pending': true,
        'deleted': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        '__localKey': docId,
      };
      await _box!.put(docId, newItem);
    } else {
      final updated = Map<String, dynamic>.from(v);
      updated['word'] = word;
      updated['translation'] = translation;
      updated['context'] = context;
      updated['pending'] = true;
      updated['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      updated['step'] = v['step'] ?? 0;
      updated['nextReview'] = v['nextReview'];
      updated['status'] = v['status'] ?? 'learning';
      updated['__localKey'] = v['__localKey'] ?? docId;
      await _box!.put(docId, updated);
    }

    scheduleSync();
  }

  Future<void> recordLookupHistory(String word) async {
    if (_disposed) return;

    final user = _auth.currentUser;
    if (user != null) {
      final historyRef =
          _firestore.collection('users').doc(user.uid).collection('history');

      try {
        await historyRef.add({
          'word': word,
          'lookedUpAt': FieldValue.serverTimestamp(),
        });

        final snapshot =
            await historyRef.orderBy('lookedUpAt', descending: true).get();

        if (snapshot.docs.length > 100) {
          for (var doc in snapshot.docs.skip(100)) {
            await historyRef.doc(doc.id).delete();
          }
        }
      } catch (_) {
        // offline safe
      }
    }
  }

  Future<void> deleteWord(String docId) async {
    final ok = await _ensureBoxReady();
    if (!ok) return;

    final raw = _box!.get(docId);
    final v = raw != null ? toStringKeyedMap(raw) : null;
    if (v == null) return;

    final remoteId = v['remoteId']?.toString();

    if (remoteId == null || remoteId.isEmpty) {
      await _box!.delete(docId);
      return;
    }

    final updated = Map<String, dynamic>.from(v);
    updated['deleted'] = true;
    updated['pending'] = true;
    updated['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await _box!.put(docId, updated);
    scheduleSync();
  }

  void dispose() {
    _disposed = true;

    _firestoreSub?.cancel();
    _firestoreSub = null;

    _pendingSyncTimer?.cancel();
    _pendingSyncTimer = null;

    _syncDebounce?.cancel();
    _syncDebounce = null;

    // do not close Hive box here
  }
}
