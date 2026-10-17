import 'dart:convert';

/// Model quản lý Ví / Tài khoản thanh toán trong Sheepify
class WalletModel {
  final String id;
  final String name; // Tên ví: "Techcombank", "Ví MoMo", "Tiền mặt"...
  final String? bankId; // ID liên kết trong BankDeeplinkService (VD: 'techcombank', 'momo', 'vcb')
  final String? bankBin; // Mã BIN ngân hàng (VD: '970407')
  final double initialBalance; // Số dư ban đầu lúc nhập
  final bool isDefault; // Ví mặc định khi quét QR hoặc chuyển tiền
  final int? colorValue; // Mã màu hiển thị
  final DateTime createdAt;

  const WalletModel({
    required this.id,
    required this.name,
    this.bankId,
    this.bankBin,
    this.initialBalance = 0,
    this.isDefault = false,
    this.colorValue,
    required this.createdAt,
  });

  WalletModel copyWith({
    String? id,
    String? name,
    String? bankId,
    String? bankBin,
    double? initialBalance,
    bool? isDefault,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bankId: bankId ?? this.bankId,
      bankBin: bankBin ?? this.bankBin,
      initialBalance: initialBalance ?? this.initialBalance,
      isDefault: isDefault ?? this.isDefault,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bankId': bankId,
      'bankBin': bankBin,
      'initialBalance': initialBalance,
      'isDefault': isDefault,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      bankId: map['bankId'],
      bankBin: map['bankBin'],
      initialBalance: (map['initialBalance'] as num?)?.toDouble() ?? 0,
      isDefault: map['isDefault'] ?? false,
      colorValue: map['colorValue'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WalletModel.fromJson(String source) =>
      WalletModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
