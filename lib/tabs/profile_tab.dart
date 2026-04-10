import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/calendar_page.dart';
import '../utils/calendar_utils.dart';
import '../pages/history_page.dart';
import '../utils/diagram.dart'; // ProgressPage is here

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

  /// ✅ Fetch raw vocabulary (single source of truth)
  Future<List<Map<String, dynamic>>> _getVocabulary() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'step': data['step'] ?? 0,
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  /// ✅ Build calendar map from words
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Info'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await _auth.signOut(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          /// ================= INFO TAB =================
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getVocabulary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.deepPurple,
                  ),
                );
              }

              final words = snapshot.data!;
              final calendarData = _buildDailyStats(words);

              final maxCount = calendarData.values.isEmpty
                  ? 1
                  : calendarData.values.reduce((a, b) => a > b ? a : b);

              return SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Learning Activity',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        /// 📅 Calendar
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

                        const Text(
                          "Vocabulary Progress",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        /// 📊 Progress ring (FIXED TYPE)
                        ProgressPage(words: words),
                      ],
                    )),
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
