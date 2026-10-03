import 'package:flutter/material.dart';

import 'app_colors.dart';

extension ThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  FinanceColors get finance => Theme.of(this).extension<FinanceColors>()!;
}
