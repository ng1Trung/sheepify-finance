import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CurrencyUtil {
  /// Default formatting for money with currency symbol
  /// e.g. 30.000 ₫ or $30.00
  static String formatMoney(double amount, {String locale = 'vi_VN', String? symbol}) {
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol ?? (locale == 'vi_VN' ? '₫' : null),
      decimalDigits: locale == 'vi_VN' ? 0 : 2,
    ).format(amount);
  }

  /// Formats only the number with thousands separators as requested (e.g., 3000 -> 3.000)
  /// Uses Vietnamese locale by default to provide the dot separator.
  static String formatNumber(num amount, {String locale = 'vi_VN'}) {
    return NumberFormat.decimalPattern(locale).format(amount);
  }

  /// Specific format for VND (dots for thousands, ₫ at the end, no decimals)
  static String formatVND(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(amount);
  }

  /// Formats amount based on currency code
  static String formatByCurrency(double amount, String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'VND':
        return formatVND(amount);
      case 'USD':
        return NumberFormat.simpleCurrency(locale: 'en_US', name: 'USD').format(amount);
      case 'EUR':
        return NumberFormat.simpleCurrency(locale: 'fr_FR', name: 'EUR').format(amount);
      default:
        return NumberFormat.simpleCurrency(name: currencyCode.toUpperCase()).format(amount);
    }
  }

  static String getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'VND': return 'đ';
      case 'USD': return '\$';
      case 'EUR': return '€';
      default: return currencyCode;
    }
  }

  /// Compact formatting for amounts (e.g., 8.000.000 -> 8M or 8Tr)
  static String formatCompact(double amount, {String locale = 'vi_VN'}) {
    bool isNegative = amount < 0;
    double absAmount = amount.abs();
    bool isVi = locale.startsWith('vi');
    
    String result;
    if (absAmount >= 1000000) {
      double value = absAmount / 1000000;
      String suffix = isVi ? 'Tr' : 'M';
      result = value % 1 == 0 ? '${value.toInt()}$suffix' : '${value.toStringAsFixed(1)}$suffix';
    } else if (absAmount >= 1000) {
      double value = absAmount / 1000;
      result = value % 1 == 0 ? '${value.toInt()}K' : '${value.toStringAsFixed(1)}K';
    } else {
      result = absAmount.toInt().toString();
    }

    return (isNegative ? '-' : '') + result;
  }
}

/// A Custom TextInputFormatter to format numbers as the user types
/// e.g., 30000 becomes 30,000 in the UI but remains numeric in logic
class CurrencyInputFormatter extends TextInputFormatter {
  final String locale;
  
  CurrencyInputFormatter({this.locale = 'vi_VN'});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove all non-numeric characters
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    double value = double.parse(cleanText);
    
    // Format the numeric value
    final formatter = NumberFormat.decimalPattern(locale);
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

extension CurrencyParsing on CurrencyUtil {
  /// Converts a formatted string (e.g., 30,000 or 30.000đ) back to a numeric double
  static double parseAmount(String text) {
    if (text.isEmpty) return 0;
    // Remove all non-numeric characters (keeping only digits)
    // This works well for integer-based currencies like VND
    String cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanText) ?? 0;
  }
}
