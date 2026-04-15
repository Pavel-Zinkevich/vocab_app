import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../pages/calendar_page.dart';

import 'package:crop_image/crop_image.dart';

import '../utils/cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/calendar_utils.dart';
import '../pages/history_page.dart';
import '../utils/diagram.dart';

import '../theme/theme_controller.dart' as tc;
// using Theme.of(context) for colors instead of AppColors to support dynamic themes

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
  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final croppedPath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropPage(imageFile: File(picked.path)),
      ),
    );

    if (croppedPath == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'photoPath': croppedPath,
    }, SetOptions(merge: true));
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
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      // Return full-ish word objects so downstream UI (diagram, lists)
      // can show word text and translation when needed.
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          // numeric study step
          'step': data['step'] ?? 0,
          // timestamps (may be a Firestore Timestamp)
          'createdAt': data['createdAt'],
          // user-facing fields used by ProgressPage and lists
          'word': data['word'] ?? '',
          'translation': data['translation'] ?? '',
          'category': data['category'] ?? 'uncategorized',
        };
      }).toList();
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
        title: Text('Profile', style: TextStyle(color: textColor)),
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
          /// ================= INFO TAB =================
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userStream(),
            builder: (context, userSnap) {
              final data = userSnap.data?.data();

              final name = data?['name'] ?? 'User';
              final photoPath = data?['photoPath'];

              ImageProvider? imageProvider;

              if (photoPath != null) {
                if (photoPath.toString().startsWith('http')) {
                  imageProvider = NetworkImage(photoPath);
                } else if (File(photoPath).existsSync()) {
                  imageProvider = FileImage(File(photoPath));
                }
              }

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _vocabularyStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
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
                          /// PROFILE HEADER
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundImage: imageProvider,
                                    child: imageProvider == null
                                        ? const Icon(Icons.person, size: 40)
                                        : null,
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
                                const SizedBox(height: 5),
                                const Text(
                                  "Tap avatar to change photo • Tap name to edit",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
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

                          // ⚠️ Make sure this widget exists
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

          /// ================= HISTORY TAB =================
          const HistoryPage(),
        ],
      ),
    );
  }
}
