import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/calendar_page.dart';
import '../utils/calendar_utils.dart';
import '../pages/history_page.dart';
import '../utils/diagram.dart';

import '../theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// ✅ REAL-TIME STREAM (FIX)
  Stream<List<Map<String, dynamic>>> _vocabularyStream() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'step': data['step'] ?? 0,
          'createdAt': data['createdAt'],
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
    final bg = AppColors.background;
    final tabBg = AppColors.navBar;
    final textColor = AppColors.textForBackground(tabBg);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: tabBg,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.learning,
          labelColor: AppColors.learning,
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
        children: [
          /// ================= INFO TAB (FIXED REAL-TIME) =================
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _vocabularyStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.learning,
                  ),
                );
              }

              final words = snapshot.data!;
              final calendarData = _buildDailyStats(words);

              final maxCount = calendarData.values.isEmpty
                  ? 1
                  : calendarData.values.reduce((a, b) => a > b ? a : b);

              final pageTextColor =
                  AppColors.textForBackground(AppColors.background);

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            builder: (_) => CalendarPage(data: calendarData),
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
                    ],
                  ),
                ),
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
