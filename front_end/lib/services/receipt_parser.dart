class ReceiptScanResult {
  const ReceiptScanResult({
    this.merchant,
    this.amount,
    this.date,
  });

  final String? merchant;
  final String? amount;
  final DateTime? date;
}

class ReceiptTextParser {
  static ReceiptScanResult parse(String rawText) {
    final normalized = rawText.replaceAll('\r', '');
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final merchant = _merchantFrom(lines);
    final amount = _amountFrom(lines);
    final date = _dateFrom(lines);

    return ReceiptScanResult(
      merchant: merchant,
      amount: amount,
      date: date,
    );
  }

  static String? _merchantFrom(List<String> lines) {
    for (final line in lines) {
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty) continue;
      final lower = normalized.toLowerCase();

      if (lower.contains('date') ||
          lower.contains('total') ||
          lower.contains('tax') ||
          _looksLikeMoney(normalized) ||
          _looksLikeDate(normalized)) {
        continue;
      }

      if (normalized.length <= 2) continue;
      return normalized;
    }

    return null;
  }

  static String? _amountFrom(List<String> lines) {
    final candidates = <String>[];

    for (final line in lines) {
      final value = _extractMoney(line);
      if (value != null) {
        candidates.add(value);
      }
    }

    if (candidates.isEmpty) return null;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('total') ||
          lower.contains('amount due') ||
          lower.contains('grand total') ||
          lower.contains('balance')) {
        final value = _extractMoney(line);
        if (value != null) {
          return _normalizedMoney(value);
        }
      }
    }

    return _normalizedMoney(candidates.last);
  }

  static DateTime? _dateFrom(List<String> lines) {
    for (final line in lines) {
      final parsed = _parseDate(line);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static DateTime? _parseDate(String line) {
    final patterns = <RegExp>[
      RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b'),
      RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;

      if (match.groupCount >= 3) {
        final first = match.group(1)!;
        final second = match.group(2)!;
        final third = match.group(3)!;

        if (first.length == 4) {
          return DateTime(
            int.parse(first),
            int.parse(second),
            int.parse(third),
          );
        }

        final yearPart = int.parse(third);
        final year = yearPart < 100 ? (yearPart >= 50 ? 1900 + yearPart : 2000 + yearPart) : yearPart;

        return DateTime(
          year,
          int.parse(first),
          int.parse(second),
        );
      }
    }

    return null;
  }

  static String? _extractMoney(String line) {
    final match = RegExp(
      r'\$?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})|\d+\.\d{1,2}',
    ).firstMatch(line);

    if (match == null) return null;
    return match.group(0);
  }

  static String _normalizedMoney(String value) {
    final cleaned = value.replaceAll(r'$', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return cleaned;
    return parsed.toStringAsFixed(2);
  }

  static bool _looksLikeMoney(String text) {
    return RegExp(r'\$?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})|\d+\.\d{1,2}').hasMatch(text);
  }

  static bool _looksLikeDate(String text) {
    return RegExp(
      r'(?:\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{4}[-/]\d{1,2}[-/]\d{1,2})',
    ).hasMatch(text);
  }
}
