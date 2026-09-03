import 'package:flutter/cupertino.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart'; // swap in whichever screen

void main() => runApp(const PennyPreview());

class PennyPreview extends StatelessWidget {
  const PennyPreview({super.key});
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: AppTheme.cupertino,
      home: const DashboardScreen(),
    );
  }
}