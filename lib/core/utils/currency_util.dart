import 'package:intl/intl.dart';

class CurrencyUtil {
  static String formatMoney(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(amount);
  }
}
