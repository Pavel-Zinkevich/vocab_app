import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/calendar_page.dart';
import '../utils/calendar_utils.dart'; // ✅ shared calendar helper
import '../pages/history_page.dart';

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

  Future<Map<DateTime, int>> _getWordStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .get();

    Map<DateTime, int> dailyCounts = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['createdAt'];
      if (timestamp != null) {
        final date = (timestamp as Timestamp).toDate();
        final day = DateTime(date.year, date.month, date.day);
        dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
      }
    }
    return dailyCounts;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.info), text: 'Info'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async => await _auth.signOut()),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FutureBuilder<Map<DateTime, int>>(
            future: _getWordStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple));
              }
              final data = snapshot.data!;
              final maxCount = data.values.isEmpty
                  ? 1
                  : data.values.reduce((a, b) => a > b ? a : b);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Learning Activity',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CalendarPage(data: data),
                            ),
                          ),
                          child: buildMonthGrid(
                            DateTime.now().year,
                            DateTime.now().month,
                            data,
                            context,
                          ),
                        ),

                        SizedBox(height: 12),

                        buildLegend(maxCount, context), // ✅ ADD THIS
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          HistoryPage(), // ✅ move history tab to its own page
        ],
      ),
    );
  }
}
