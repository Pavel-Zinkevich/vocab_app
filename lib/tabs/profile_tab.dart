import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../pages/calendar_page.dart';
import '../service/language_service.dart';
import '../utils/cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/calendar_utils.dart';
import '../pages/history_page.dart';
import '../utils/diagram.dart';
import '../theme/theme_controller.dart' as tc;

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _uploadingPhoto = false;
  File? _localPhotoFile;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<String> _localPhotoPathForUser(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/profile_photos');

    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    return '${photoDir.path}/$uid.jpg';
  }

  Future<void> _loadLocalPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final path = await _localPhotoPathForUser(user.uid);
      final file = File(path);

      if (await file.exists()) {
        if (!mounted) return;
        setState(() {
          _localPhotoFile = file;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _localPhotoFile = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localPhotoFile = null;
      });
    }
  }

  Future<File> _compressAndSaveLocally(File originalFile, String uid) async {
    final targetPath = await _localPhotoPathForUser(uid);

    try {
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
        originalFile.absolute.path,
        minWidth: 1080,
        minHeight: 1080,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      final outputFile = File(targetPath);

      if (compressedBytes == null) {
        // Fallback: just copy original to the local app folder
        return await originalFile.copy(targetPath);
      }

      await outputFile.writeAsBytes(compressedBytes, flush: true);
      return outputFile;
    } catch (_) {
      // Fallback: copy original if compression fails
      return await originalFile.copy(targetPath);
    }
  }

  Future<void> _pickImage() async {
    if (_uploadingPhoto) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final croppedResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropPage(imageFile: File(picked.path)),
      ),
    );

    if (croppedResult == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _uploadingPhoto = true;
      });

      final File croppedFile;
      if (croppedResult is File) {
        croppedFile = croppedResult;
      } else if (croppedResult is String) {
        croppedFile = File(croppedResult);
      } else {
        throw Exception(
          'CropPage returned unsupported type: ${croppedResult.runtimeType}',
        );
      }

      if (!await croppedFile.exists()) {
        throw Exception('Cropped image file does not exist');
      }

      final savedFile = await _compressAndSaveLocally(croppedFile, user.uid);

      if (!await savedFile.exists()) {
        throw Exception('Failed to save local profile image');
      }

      if (!mounted) return;
      setState(() {
        _localPhotoFile = savedFile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated on this device')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save local photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit name"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) return;

              await _firestore.collection('users').doc(user.uid).set({
                'name': controller.text.trim(),
              }, SetOptions(merge: true));

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    LanguageService.instance.addListener(_onLangChanged);
    _loadLocalPhoto();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    LanguageService.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _vocabularyStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .snapshots()
        .map((snapshot) {
      final currentLang = LanguageService.instance.currentLang;

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'step': data['step'] ?? 0,
              'createdAt': data['createdAt'],
              'word': data['word'] ?? '',
              'translation': data['translation'] ?? '',
              'status': data['status'] ?? data['category'] ?? '',
              'category': data['category'] ?? '',
              'language': data['language'],
            };
          })
          .where((m) => m['language'] == null || m['language'] == currentLang)
          .toList();
    });
  }

  Map<DateTime, int> _buildDailyStats(List<Map<String, dynamic>> words) {
    final Map<DateTime, int> data = {};

    for (final w in words) {
      final timestamp = w['createdAt'];
      if (timestamp != null) {
        final date = (timestamp as Timestamp).toDate();
        final day = DateTime(date.year, date.month, date.day);
        data[day] = (data[day] ?? 0) + 1;
      }
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final tabBg = Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).appBarTheme.titleTextStyle?.color ??
        Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: tabBg,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Profile', style: TextStyle(color: textColor)),
            const SizedBox(width: 8),
            Text(
              LanguageService.instance.currentLang == 'fr' ? '🇫🇷' : '🇪🇸',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: textColor.withOpacity(0.6),
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Info'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: textColor),
            onPressed: () async => await _auth.signOut(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userStream(),
            builder: (context, userSnap) {
              final data = userSnap.data?.data();

              final name = data?['name'] ?? 'User';

              ImageProvider? imageProvider;
              if (_localPhotoFile != null && _localPhotoFile!.existsSync()) {
                imageProvider = FileImage(_localPhotoFile!);
              }

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _vocabularyStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }

                  final words = snapshot.data!;
                  final calendarData = _buildDailyStats(words);

                  final maxCount = calendarData.values.isEmpty
                      ? 1
                      : calendarData.values.reduce((a, b) => a > b ? a : b);

                  final pageTextColor =
                      Theme.of(context).colorScheme.onBackground;

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundImage: imageProvider,
                                        child: imageProvider == null
                                            ? const Icon(Icons.person, size: 40)
                                            : null,
                                      ),
                                      if (_uploadingPhoto)
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: const BoxDecoration(
                                            color: Colors.black45,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => _editName(name),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your Learning Activity',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: pageTextColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CalendarPage(data: calendarData),
                              ),
                            ),
                            child: buildMonthGrid(
                              DateTime.now().year,
                              DateTime.now().month,
                              calendarData,
                              context,
                            ),
                          ),
                          const SizedBox(height: 12),
                          buildLegend(maxCount, context),
                          const SizedBox(height: 24),
                          Text(
                            "Vocabulary Progress",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: pageTextColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ProgressPage(words: words),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Icons.dark_mode
                                          : Icons.light_mode,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text("Dark Mode"),
                                  ],
                                ),
                                ValueListenableBuilder<ThemeMode>(
                                  valueListenable: tc.ThemeController.themeMode,
                                  builder: (context, mode, _) {
                                    return Switch(
                                      value: mode == ThemeMode.dark,
                                      onChanged: (value) {
                                        tc.ThemeController.toggle(value);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const HistoryPage(),
        ],
      ),
    );
  }
}
