import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyUtil {
  static String formatMoney(
    double amount, {
    String locale = 'en_US',
    String? symbol,
  }) {
    return formatNumber(amount, locale: locale);
  }

  static String formatNumber(num amount, {String locale = 'en_US'}) {
    return NumberFormat.decimalPattern(locale).format(amount);
  }

  static String formatVND(double amount) {
    return formatNumber(amount);
  }

  static String formatByCurrency(double amount, String currencyCode) {
    return formatNumber(amount);
  }

  static String getCurrencySymbol(String currencyCode) {
    return '';
  }

  static String formatMaskedByCurrency(String currencyCode) {
    return '********';
  }

  static String formatDisplayAmount(
    double amount,
    String currencyCode, {
    required bool isHidden,
  }) {
    return isHidden
        ? formatMaskedByCurrency(currencyCode)
        : formatNumber(amount);
  }

  static String formatDisplayCompact(
    double amount, {
    required bool isHidden,
    String locale = 'vi_VN',
  }) {
    return isHidden ? '****' : formatCompact(amount, locale: locale);
  }

  static String formatCompact(double amount, {String locale = 'vi_VN'}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final isVi = locale.startsWith('vi');

    String result;
    if (absAmount >= 1000000) {
      final value = absAmount / 1000000;
      final suffix = isVi ? 'Tr' : 'M';
      result = value % 1 == 0
          ? '${value.toInt()}$suffix'
          : '${value.toStringAsFixed(1)}$suffix';
    } else if (absAmount >= 1000) {
      final value = absAmount / 1000;
      result = value % 1 == 0
          ? '${value.toInt()}K'
          : '${value.toStringAsFixed(1)}K';
    } else {
      result = absAmount.toInt().toString();
    }

    return (isNegative ? '-' : '') + result;
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  final String locale;

  CurrencyInputFormatter({this.locale = 'en_US'});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    final value = double.parse(cleanText);
    final newText = NumberFormat.decimalPattern(locale).format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

extension CurrencyParsing on CurrencyUtil {
  static double parseAmount(String text) {
    if (text.isEmpty) return 0;
    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanText) ?? 0;
  }
}
