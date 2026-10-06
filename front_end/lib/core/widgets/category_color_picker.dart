import 'package:flutter/material.dart';

import '../theme/chart_colors.dart';
import '../theme/theme_x.dart';

class CategoryColorPicker extends StatelessWidget {
  final String? selectedHex;
  final ValueChanged<String> onChanged;
  const CategoryColorPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final hex in categorySwatches)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onChanged(hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorFromHex(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedHex?.toUpperCase() == hex
                      ? context.colors.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: selectedHex?.toUpperCase() == hex
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet for recoloring an existing category. Returns the chosen hex.
Future<String?> showCategoryColorSheet(
  BuildContext context, {
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category color', style: context.text.titleMedium),
          const SizedBox(height: 16),
          CategoryColorPicker(
            selectedHex: current,
            onChanged: (hex) => Navigator.of(context).pop(hex),
          ),
        ],
      ),
    ),
  );
}
