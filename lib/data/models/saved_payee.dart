import 'dart:convert';

/// Model danh bạ người nhận chuyển khoản thường xuyên
class SavedPayee {
  final String id;
  final String nickname; // Tên gợi nhớ: "Chủ nhà trọ", "Mẹ", "Bạn Nam"
  final String bankBin; // Mã BIN ngân hàng (VD: 970407)
  final String accountNo; // Số tài khoản
  final String? defaultCategoryId;
  final String? defaultNote;
  final DateTime createdAt;

  const SavedPayee({
    required this.id,
    required this.nickname,
    required this.bankBin,
    required this.accountNo,
    this.defaultCategoryId,
    this.defaultNote,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'bankBin': bankBin,
      'accountNo': accountNo,
      'defaultCategoryId': defaultCategoryId,
      'defaultNote': defaultNote,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedPayee.fromMap(Map<String, dynamic> map) {
    return SavedPayee(
      id: map['id'] ?? '',
      nickname: map['nickname'] ?? '',
      bankBin: map['bankBin'] ?? '',
      accountNo: map['accountNo'] ?? '',
      defaultCategoryId: map['defaultCategoryId'],
      defaultNote: map['defaultNote'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SavedPayee.fromJson(String source) =>
      SavedPayee.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
