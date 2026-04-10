import 'package:flutter/material.dart';
import '../pages/words_added_page.dart';

Color getColor(int count, int maxCount) {
  if (count == 0) return Colors.grey[200]!;

  final ratio = count / maxCount;

  if (ratio < 0.25) return Color(0xFFB2DFDB);
  if (ratio < 0.5) return Color(0xFF80CBC4);
  if (ratio < 0.75) return Color(0xFF4DB6AC);
  return Color(0xFF26A69A);
}

Widget buildLegend(int maxCount, BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("How we count words"),
              content: Text(
                "Each square shows how many words you added that day.",
              ),
            ),
          );
        },
        child: Text(
          "Learn how we count words",
          style: TextStyle(
            color: Colors.blue,
          ),
        ),
      ),
      Row(
        children: [
          Text("Less"),
          SizedBox(width: 8),
          Row(
            children: List.generate(5, (index) {
              final value = ((index + 1) / 5) * maxCount;

              return Container(
                width: 14,
                height: 14,
                margin: EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: getColor(value.toInt(), maxCount), // ✅ FIXED
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black12),
                  boxShadow: value > 0
                      ? [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(1, 1),
                          ),
                        ]
                      : [],
                ),
              );
            }),
          ),
          SizedBox(width: 8),
          Text("More"),
        ],
      ),
    ],
  );
}

Widget buildMonthGrid(
  int year,
  int month,
  Map<DateTime, int> data,
  BuildContext context, {
  void Function(DateTime date)? onDayTap, // callback when a day is tapped
}) {
  final maxCount =
      data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

  final firstDayOfMonth = DateTime(year, month, 1);
  final lastDayOfMonth = DateTime(year, month + 1, 0);
  final daysInMonth = lastDayOfMonth.day;
  final startWeekday = firstDayOfMonth.weekday;

  List<Widget> dayWidgets = [];

  // Weekday headers
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  for (var day in weekdays) {
    dayWidgets.add(Center(
      child: Text(
        day,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
      ),
    ));
  }

  // Empty cells before the first day
  for (int i = 1; i < startWeekday; i++) {
    dayWidgets.add(Container());
  }

  final today = DateTime.now();

  // Days of the month
  for (int day = 1; day <= daysInMonth; day++) {
    final date = DateTime(year, month, day);
    final count = data[DateTime(date.year, date.month, date.day)] ?? 0;
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    dayWidgets.add(
      GestureDetector(
        onTap: onDayTap != null
            ? () {
                onDayTap(date); // just call the callback
              }
            : null,
        child: Container(
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
        ),
      ),
    );
  }

  return GridView.count(
    crossAxisCount: 7,
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    children: dayWidgets,
  );
}
