import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

AppSemanticColors? _semanticColors(BuildContext context) {
  return Theme.of(context).extension<AppSemanticColors>();
}

Color _fallbackHeatColor(BuildContext context, int value, int maxCount) {
  final scheme = Theme.of(context).colorScheme;

  if (maxCount <= 0 || value <= 0) {
    return scheme.surfaceVariant.withOpacity(0.7);
  }

  final ratio = value / maxCount;

  if (ratio < 0.25) return scheme.primary.withOpacity(0.25);
  if (ratio < 0.5) return scheme.primary.withOpacity(0.45);
  if (ratio < 0.75) return scheme.primary.withOpacity(0.70);
  return scheme.primary;
}

Color _textForBackground(BuildContext context, Color bg) {
  final semantic = _semanticColors(context);
  if (semantic != null) {
    return semantic.textForBackground(bg);
  }

  return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

Color getColor(BuildContext context, int count, int maxCount) {
  final colors = _semanticColors(context);
  if (colors != null) {
    return colors.heatFromCount(count, maxCount);
  }
  return _fallbackHeatColor(context, count, maxCount);
}

Color getHeatColor(BuildContext context, int value, int maxCount) {
  final colors = _semanticColors(context);

  if (colors != null) {
    if (maxCount == 0) return colors.heatEmpty;

    final ratio = value / maxCount;

    if (ratio <= 0) return colors.heatEmpty;
    if (ratio < 0.25) return colors.heatLow;
    if (ratio < 0.5) return colors.heatMidLow;
    if (ratio < 0.75) return colors.heatMid;
    return colors.heatHigh;
  }

  return _fallbackHeatColor(context, value, maxCount);
}

Widget buildLegend(int maxCount, BuildContext context) {
  final semantic = _semanticColors(context);
  final scheme = Theme.of(context).colorScheme;

  final dialogBg = semantic?.background ?? scheme.surface;
  final dialogText = _textForBackground(context, dialogBg);
  final linkColor = semantic?.infoLink ?? scheme.primary;

  final legendColors = semantic != null
      ? [
          semantic.heatEmpty,
          semantic.heatLow,
          semantic.heatMidLow,
          semantic.heatMid,
          semantic.heatHigh,
        ]
      : [
          getHeatColor(context, 0, maxCount),
          getHeatColor(context, 1, maxCount <= 0 ? 4 : maxCount),
          getHeatColor(context, 2, maxCount <= 0 ? 4 : maxCount),
          getHeatColor(context, 3, maxCount <= 0 ? 4 : maxCount),
          getHeatColor(context, maxCount <= 0 ? 4 : maxCount,
              maxCount <= 0 ? 4 : maxCount),
        ];

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                "How we count words",
                style: TextStyle(color: dialogText),
              ),
              content: Text(
                "Each square shows how many words you added that day.",
                style: TextStyle(color: dialogText),
              ),
            ),
          );
        },
        child: Text(
          "How we count words",
          style: TextStyle(
            color: linkColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Row(
        children: [
          Text(
            "Less",
            style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(5, (index) {
              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: legendColors[index],
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
            style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
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
  final semantic = _semanticColors(context);
  final scheme = Theme.of(context).colorScheme;

  final maxCount =
      data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

  final firstDayOfMonth = DateTime(year, month, 1);
  final lastDayOfMonth = DateTime(year, month + 1, 0);
  final daysInMonth = lastDayOfMonth.day;
  final startWeekday = firstDayOfMonth.weekday;

  final today = DateTime.now();

  List<Widget> dayWidgets = [];

  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  for (var day in weekdays) {
    dayWidgets.add(
      Center(
        child: Text(
          day,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: semantic?.learning ?? scheme.primary,
          ),
        ),
      ),
    );
  }

  for (int i = 1; i < startWeekday; i++) {
    dayWidgets.add(Container());
  }

  for (int day = 1; day <= daysInMonth; day++) {
    final date = DateTime(year, month, day);

    final normalized = DateTime(date.year, date.month, date.day);
    final count = data[normalized] ?? 0;

    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    final bg = getColor(context, count, maxCount);
    final textColor = _textForBackground(context, bg);

    dayWidgets.add(
      GestureDetector(
        onTap: onDayTap != null ? () => onDayTap(date) : null,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: isToday
                ? Border.all(
                    color: semantic?.infoLink ?? scheme.primary,
                    width: 1.4,
                  )
                : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: textColor,
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
