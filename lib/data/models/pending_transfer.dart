import 'dart:convert';

/// Model đại diện cho một giao dịch chuyển khoản đang ở trạng thái Chờ xác nhận (Pending).
/// Tiền trong ví CHƯA bị trừ và Transaction CHƯA được ghi vào sổ chi tiêu
/// cho đến khi người dùng quay lại và xác nhận đã chuyển tiền thành công.
class PendingTransfer {
  final String id;
  final double amount;
  final String note;
  final String categoryId;
  final String? walletId;
  final String? sendingBankId;
  final String? recipientBankBin;
  final String? recipientBankName;
  final String accountNo;
  final String? qrPayload;
  final DateTime createdAt;
  final String status; // 'pending', 'confirmed', 'cancelled'

  const PendingTransfer({
    required this.id,
    required this.amount,
    required this.note,
    required this.categoryId,
    this.walletId,
    this.sendingBankId,
    this.recipientBankBin,
    this.recipientBankName,
    required this.accountNo,
    this.qrPayload,
    required this.createdAt,
    this.status = 'pending',
  });

  bool get isPending => status == 'pending';

  PendingTransfer copyWith({
    String? id,
    double? amount,
    String? note,
    String? categoryId,
    String? walletId,
    String? sendingBankId,
    String? recipientBankBin,
    String? recipientBankName,
    String? accountNo,
    String? qrPayload,
    DateTime? createdAt,
    String? status,
  }) {
    return PendingTransfer(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      sendingBankId: sendingBankId ?? this.sendingBankId,
      recipientBankBin: recipientBankBin ?? this.recipientBankBin,
      recipientBankName: recipientBankName ?? this.recipientBankName,
      accountNo: accountNo ?? this.accountNo,
      qrPayload: qrPayload ?? this.qrPayload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'categoryId': categoryId,
      'walletId': walletId,
      'sendingBankId': sendingBankId,
      'recipientBankBin': recipientBankBin,
      'recipientBankName': recipientBankName,
      'accountNo': accountNo,
      'qrPayload': qrPayload,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory PendingTransfer.fromMap(Map<String, dynamic> map) {
    return PendingTransfer(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] ?? '',
      categoryId: map['categoryId'] ?? '',
      walletId: map['walletId'],
      sendingBankId: map['sendingBankId'],
      recipientBankBin: map['recipientBankBin'],
      recipientBankName: map['recipientBankName'],
      accountNo: map['accountNo'] ?? '',
      qrPayload: map['qrPayload'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PendingTransfer.fromJson(String source) =>
      PendingTransfer.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
