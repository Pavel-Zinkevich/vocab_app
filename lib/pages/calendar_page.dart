import 'package:flutter/material.dart';
import '../utils/calendar_utils.dart';

class CalendarPage extends StatelessWidget {
  final Map<DateTime, int> data;

  const CalendarPage({required this.data});

  static const List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  Widget build(BuildContext context) {
    // First month with data
    DateTime firstMonth = data.keys.isEmpty
        ? DateTime.now()
        : data.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final startMonth = DateTime(firstMonth.year, firstMonth.month, 1);
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    // Number of months
    int monthCount = (currentMonth.year - startMonth.year) * 12 +
        (currentMonth.month - startMonth.month) +
        1;

    return Scaffold(
      appBar: AppBar(title: Text('Full Calendar')),
      body: SingleChildScrollView(
        child: Column(
          children: List.generate(monthCount, (index) {
            final year = startMonth.year + (startMonth.month + index - 1) ~/ 12;
            final month = (startMonth.month + index - 1) % 12 + 1;

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${monthNames[month - 1]} $year',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  buildMonthGrid(year, month, data), // reused from profile_tab
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
