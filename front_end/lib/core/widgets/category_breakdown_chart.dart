import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';

import '../../models/category_breakdown_item.dart';
import '../theme/chart_colors.dart';
import '../theme/theme_x.dart';

class CategoryBreakdownChart extends StatelessWidget {
  final List<CategoryBreakdownItem> items;
  const CategoryBreakdownChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // The backend LEFT JOINs, so zero-spend categories come back too.
    // Drop them here or they clutter the legend with 0% entries.
    final visible = items.where((i) => i.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No expenses in this period',
            style: context.text.bodySmall,
          ),
        ),
      );
    }

    final grandTotal = visible.fold<double>(0, (s, i) => s + i.total);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: [
                for (final item in visible)
                  PieChartSectionData(
                    value: item.total,
                    color: categoryColor(item.categoryId, hex: item.colorHex),
                    radius: 34,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final item in visible)
              _LegendItem(
                color: categoryColor(item.categoryId, hex: item.colorHex),
                label: item.categoryName,
                percent: item.total / grandTotal,
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${(percent * 100).round()}%',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}
