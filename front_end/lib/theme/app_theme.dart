import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Penny's design language: a ledger, not a dashboard.
/// Hairline rules over shadows. Copper as the one accent. Numbers set in
/// monospace so amounts line up the way they would in a real passbook.
class AppColors {
  AppColors._();

  static const Color paper = Color(0xFFF7F3EC);
  static const Color paperDim = Color(0xFFEFE9DD);
  static const Color ink = Color(0xFF1B2430);
  static const Color inkSoft = Color(0xFF2C3444);

  static const Color copper = Color(0xFFA8623B);
  static const Color copperDark = Color(0xFF7E4A2B);

  static const Color ledgerGreen = Color(0xFF3F6B4F);
  static const Color rust = Color(0xFFA13D2D);

  static const Color slate = Color(0xFF5B6472);
  static const Color slateLight = Color(0xFF8A93A0);

  static const Color hairline = Color(0xFFDCD5C8);
}

class AppType {
  AppType._();

  static TextStyle get wordmark => GoogleFonts.ibmPlexSerif(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get title => GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get body => GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.4,
      );

  static TextStyle get label => GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.slate,
      );

  static TextStyle get caption => GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.slateLight,
      );

  /// Every rendered amount in the app uses this family — never the UI sans.
  static TextStyle amount({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        letterSpacing: -0.2,
      );
}

class AppTheme {
  AppTheme._();

  static CupertinoThemeData get cupertino => CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.copper,
        scaffoldBackgroundColor: AppColors.paper,
        barBackgroundColor: AppColors.paper,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.copper,
          textStyle: AppType.body,
          navTitleTextStyle: AppType.title,
          navLargeTitleTextStyle: GoogleFonts.ibmPlexSerif(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
          actionTextStyle: AppType.body.copyWith(color: AppColors.copper),
        ),
      );
}

/// A ledger-style amount: monospace, sign-colored, right-alignable.
/// Positive amounts (income) read in ledger green, expenses in rust,
/// and neutral/pending figures stay ink so color always carries meaning.
class AmountText extends StatelessWidget {
  final String value;
  final double size;
  final FontWeight weight;
  final bool colorBySign;
  final String currencySymbol;

  const AmountText(
    this.value, {
    super.key,
    this.size = 16,
    this.weight = FontWeight.w500,
    this.colorBySign = true,
    this.currencySymbol = '\$',
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = double.parse(value) < 0;
    final display =
        '${isNegative ? '-' : ''}$currencySymbol${double.parse(value).abs().toStringAsFixed(2)}';
    final color = colorBySign
        ? (isNegative ? AppColors.rust : AppColors.ledgerGreen)
        : AppColors.ink;
    return Text(
      display,
      style: AppType.amount(size: size, weight: weight, color: color),
    );
  }
}

/// Thin ledger divider — used instead of card shadows throughout Penny.
class LedgerDivider extends StatelessWidget {
  final double indent;
  const LedgerDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: AppColors.hairline),
    );
  }
}