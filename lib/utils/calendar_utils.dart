import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

Color getColor(BuildContext context, int count, int maxCount) {
  final colors = Theme.of(context).extension<AppSemanticColors>()!;
  return colors.heatFromCount(count, maxCount);
}

Color getHeatColor(BuildContext context, int value, int maxCount) {
  final colors = context.colors;

  if (maxCount == 0) return colors.heatEmpty;

  final ratio = value / maxCount;

  if (ratio <= 0) return colors.heatEmpty;
  if (ratio < 0.25) return colors.heatLow;
  if (ratio < 0.5) return colors.heatMidLow;
  if (ratio < 0.75) return colors.heatMid;
  return colors.heatHigh;
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
              backgroundColor:
                  Theme.of(context).extension<AppSemanticColors>()?.background,
              title: Text(
                "How we count words",
                style: TextStyle(
                  color: Theme.of(context)
                      .extension<AppSemanticColors>()
                      ?.textForBackground(Theme.of(context)
                          .extension<AppSemanticColors>()!
                          .background),
                ),
              ),
              content: Text(
                "Each square shows how many words you added that day.",
                style: TextStyle(
                  color: Theme.of(context)
                      .extension<AppSemanticColors>()
                      ?.textForBackground(Theme.of(context)
                          .extension<AppSemanticColors>()!
                          .background),
                ),
              ),
            ),
          );
        },
        child: Text(
          "How we count words",
          style: TextStyle(
            color: Theme.of(context).extension<AppSemanticColors>()?.infoLink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Row(
        children: [
          Text(
            "Less",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(5, (index) {
              final colors = [
                context.colors.heatEmpty,
                context.colors.heatLow,
                context.colors.heatMidLow,
                context.colors.heatMid,
                context.colors.heatHigh,
              ];

              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: colors[index],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          Text(
            "More",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      )
    ],
  );
}

Widget buildMonthGrid(
  int year,
  int month,
  Map<DateTime, int> data,
  BuildContext context, {
  void Function(DateTime date)? onDayTap,
}) {
  final maxCount =
      data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

  final firstDayOfMonth = DateTime(year, month, 1);
  final lastDayOfMonth = DateTime(year, month + 1, 0);
  final daysInMonth = lastDayOfMonth.day;
  final startWeekday = firstDayOfMonth.weekday;

  final today = DateTime.now();

  List<Widget> dayWidgets = [];

  // Weekday headers
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  for (var day in weekdays) {
    dayWidgets.add(
      Center(
        child: Text(
          day,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).extension<AppSemanticColors>()?.learning,
          ),
        ),
      ),
    );
  }

  // Empty cells before first day
  for (int i = 1; i < startWeekday; i++) {
    dayWidgets.add(Container());
  }

  // Days
  for (int day = 1; day <= daysInMonth; day++) {
    final date = DateTime(year, month, day);

    final count = data[DateTime(date.year, date.month, date.day)] ?? 0;

    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    dayWidgets.add(
      GestureDetector(
        onTap: onDayTap != null ? () => onDayTap(date) : null,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: getColor(context, count, maxCount),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday && count > 0
                    ? Colors.white
                    : Theme.of(context)
                        .extension<AppSemanticColors>()
                        ?.textForBackground(Theme.of(context)
                            .extension<AppSemanticColors>()!
                            .background),
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
    physics: const NeverScrollableScrollPhysics(),
    children: dayWidgets,
  );
}
