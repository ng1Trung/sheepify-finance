/// A balance-change alert from a bank app (or SMS banking), reduced to what
/// the ledger needs. Formats differ per bank, so parsing is deliberately
/// loose: a signed amount decides everything, the rest is best effort.
class ParsedBankAlert {
  final double amount;
  final bool isExpense;
  final String note;

  const ParsedBankAlert({
    required this.amount,
    required this.isExpense,
    required this.note,
  });
}

class BankAlertParser {
  // "-50,000 VND", "+1.200.000đ", "- 35,000VND", "-50,000 VNĐ"
  static final RegExp _signedAmount = RegExp(
    r'([+\-])\s?(\d{1,3}(?:[.,]\d{3})+)\s?(?:VND|VNĐ|đ|₫)',
    caseSensitive: false,
  );

  // Text right before an amount that marks it as the balance, not the change.
  static final RegExp _balanceBefore = RegExp(
    r'(số dư|so du|\bSD\b|\bSDC\b|balance)\W{0,4}$',
    caseSensitive: false,
  );

  // "ND: ...", "Nội dung: ...", "ND GD: ...", "Content: ..."
  static final RegExp _content = RegExp(
    r'(?:\bND(?:\s?GD)?|Nội dung(?: GD)?|Noi dung|Content|Mô tả|Mo ta)\s*[:：]\s*(.+)',
    caseSensitive: false,
  );

  static ParsedBankAlert? parse(String text) {
    if (text.trim().isEmpty) return null;

    RegExpMatch? amountMatch;
    for (final m in _signedAmount.allMatches(text)) {
      final before = text.substring(m.start < 20 ? 0 : m.start - 20, m.start);
      if (_balanceBefore.hasMatch(before)) continue;
      amountMatch = m;
      break;
    }
    if (amountMatch == null) return null;

    final digits = amountMatch.group(2)!.replaceAll(RegExp(r'[.,]'), '');
    final amount = double.tryParse(digits);
    if (amount == null || amount <= 0) return null;

    return ParsedBankAlert(
      amount: amount,
      isExpense: amountMatch.group(1) == '-',
      note: _extractNote(text),
    );
  }

  static String _extractNote(String text) {
    final m = _content.firstMatch(text);
    if (m == null) return '';
    var note = m.group(1)!.trim();
    // Stop at the next field some banks put on the same line.
    final cut = RegExp(
      r'\s*(?:\||\bSD\b|Số dư|So du|\bRef\b|Mã GD|Ma GD)',
      caseSensitive: false,
    ).firstMatch(note);
    if (cut != null && cut.start > 0) note = note.substring(0, cut.start);
    note = note.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (note.endsWith('.')) note = note.substring(0, note.length - 1);
    return note.length > 50 ? note.substring(0, 50).trim() : note;
  }
}
