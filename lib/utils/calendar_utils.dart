import 'package:flutter/material.dart';

Color getColor(int count, int maxCount) {
  if (count == 0) return Colors.grey[200]!;
  final intensity = count / maxCount;
  return Color.lerp(
    Colors.green[200],
    const Color.fromARGB(255, 73, 96, 165),
    intensity,
  )!;
}

Widget buildMonthGrid(int year, int month, Map<DateTime, int> data) {
  final maxCount =
      data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

  final firstDayOfMonth = DateTime(year, month, 1);
  final lastDayOfMonth = DateTime(year, month + 1, 0);

  final daysInMonth = lastDayOfMonth.day;
  final startWeekday = firstDayOfMonth.weekday; // 1 = Mon

  List<Widget> dayWidgets = [];

  // Weekday headers
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  for (var day in weekdays) {
    dayWidgets.add(
      Center(
        child: Text(
          day,
          style:
              TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
      ),
    );
  }

  // Empty slots before month starts
  for (int i = 1; i < startWeekday; i++) {
    dayWidgets.add(Container());
  }

  final today = DateTime.now();

  // Actual days
  for (int day = 1; day <= daysInMonth; day++) {
    final date = DateTime(year, month, day);
    final count = data[DateTime(date.year, date.month, date.day)] ?? 0;

    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    dayWidgets.add(Container(
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: getColor(count, maxCount),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday && count > 0 ? Colors.white : Colors.black,
          ),
        ),
      ),
    ));
  }

  return GridView.count(
    crossAxisCount: 7,
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    children: dayWidgets,
  );
}
