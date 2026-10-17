import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Model đại diện cho một Ngân hàng hoặc Ví điện tử tại Việt Nam
class BankAppModel {
  final String id;
  final String shortName;
  final String fullName;
  final String bin; // Napas BIN code
  final String iosScheme;
  final String androidPackage;
  final Color brandColor;
  final String? logoUrl;

  const BankAppModel({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.bin,
    required this.iosScheme,
    required this.androidPackage,
    required this.brandColor,
    this.logoUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankAppModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class BankDeeplinkService {
  /// Danh mục các ngân hàng và ví điện tử phổ biến nhất tại Việt Nam
  static final List<BankAppModel> supportedBanks = [
    const BankAppModel(
      id: 'vcb',
      shortName: 'Vietcombank',
      fullName: 'Ngân hàng TMCP Ngoại Thương Việt Nam (VCB Digibank)',
      bin: '970436',
      iosScheme: 'vcb://',
      androidPackage: 'com.VCB',
      brandColor: Color(0xFF005A36),
      logoUrl: 'https://api.vietqr.io/img/VCB.png',
    ),
    const BankAppModel(
      id: 'techcombank',
      shortName: 'Techcombank',
      fullName: 'Ngân hàng TMCP Kỹ Thương Việt Nam (Techcombank Mobile)',
      bin: '970407',
      iosScheme: 'techcombank://',
      androidPackage: 'vn.com.techcombank.bb.app',
      brandColor: Color(0xFFE60000),
      logoUrl: 'https://api.vietqr.io/img/TCB.png',
    ),
    const BankAppModel(
      id: 'mb',
      shortName: 'MBBank',
      fullName: 'Ngân hàng TMCP Quân Đội (MB Bank)',
      bin: '970422',
      iosScheme: 'mbmobile://',
      androidPackage: 'com.mbmobile',
      brandColor: Color(0xFF002D72),
      logoUrl: 'https://api.vietqr.io/img/MB.png',
    ),
    const BankAppModel(
      id: 'momo',
      shortName: 'MoMo',
      fullName: 'Ví Điện Tử MoMo',
      bin: 'momo',
      iosScheme: 'momo://',
      androidPackage: 'com.mservice.momopay',
      brandColor: Color(0xFFA50064),
      logoUrl: 'https://api.vietqr.io/img/momo.png',
    ),
    const BankAppModel(
      id: 'tpb',
      shortName: 'TPBank',
      fullName: 'Ngân hàng TMCP Tiên Phong (TPBank Mobile)',
      bin: '970423',
      iosScheme: 'tpb://',
      androidPackage: 'com.tpb.mb.gprsandroid',
      brandColor: Color(0xFF6B2D8C),
      logoUrl: 'https://api.vietqr.io/img/TPB.png',
    ),
    const BankAppModel(
      id: 'vpbank',
      shortName: 'VPBank',
      fullName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng (VPBank NEO)',
      bin: '970432',
      iosScheme: 'vpbankneo://',
      androidPackage: 'com.vnpay.vpbankonline',
      brandColor: Color(0xFF009140),
      logoUrl: 'https://api.vietqr.io/img/VPB.png',
    ),
    const BankAppModel(
      id: 'acb',
      shortName: 'ACB',
      fullName: 'Ngân hàng TMCP Á Châu (ACB ONE)',
      bin: '970416',
      iosScheme: 'acbone://',
      androidPackage: 'mobile.acb.com.vn',
      brandColor: Color(0xFF005BAC),
      logoUrl: 'https://api.vietqr.io/img/ACB.png',
    ),
    const BankAppModel(
      id: 'bidv',
      shortName: 'BIDV',
      fullName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam',
      bin: '970418',
      iosScheme: 'bidvsmartbanking://',
      androidPackage: 'com.vnpay.bidv',
      brandColor: Color(0xFF006A4E),
      logoUrl: 'https://api.vietqr.io/img/BIDV.png',
    ),
    const BankAppModel(
      id: 'vietinbank',
      shortName: 'VietinBank',
      fullName: 'Ngân hàng TMCP Công Thương Việt Nam (iPay)',
      bin: '970415',
      iosScheme: 'vietinbankipay://',
      androidPackage: 'com.vietinbank.ipay',
      brandColor: Color(0xFF0072CE),
      logoUrl: 'https://api.vietqr.io/img/CTG.png',
    ),
    const BankAppModel(
      id: 'zalopay',
      shortName: 'ZaloPay',
      fullName: 'Ví Điện Tử ZaloPay',
      bin: 'zalopay',
      iosScheme: 'zalopay://',
      androidPackage: 'com.vng.zalopay',
      brandColor: Color(0xFF0068FF),
      logoUrl: 'https://api.vietqr.io/img/zalopay.png',
    ),
    const BankAppModel(
      id: 'timo',
      shortName: 'Timo',
      fullName: 'Ngân hàng số Timo Digital Bank',
      bin: '963388',
      iosScheme: 'timo://',
      androidPackage: 'vn.timo.mobile',
      brandColor: Color(0xFF7B1FA2),
      logoUrl: 'https://api.vietqr.io/img/TIMO.png',
    ),
    const BankAppModel(
      id: 'cake',
      shortName: 'Cake by VPBank',
      fullName: 'Ngân hàng số Cake by VPBank',
      bin: '546034',
      iosScheme: 'cake://',
      androidPackage: 'xyz.be.cake',
      brandColor: Color(0xFFFF5252),
      logoUrl: 'https://api.vietqr.io/img/CAKE.png',
    ),
  ];

  /// Tìm ngân hàng theo mã BIN Napas
  static BankAppModel? findByBin(String? bin) {
    if (bin == null || bin.isEmpty) return null;
    try {
      return supportedBanks.firstWhere((b) => b.bin == bin);
    } catch (_) {
      return null;
    }
  }

  /// Tìm ngân hàng theo ID
  static BankAppModel? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return supportedBanks.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Kiểm tra xem ứng dụng ngân hàng này có được cài trên thiết bị không
  static Future<bool> isAppInstalled(BankAppModel bank) async {
    try {
      if (Platform.isIOS) {
        final uri = Uri.parse(bank.iosScheme);
        return await canLaunchUrl(uri);
      } else if (Platform.isAndroid) {
        final uri = Uri.parse('android-app://${bank.androidPackage}');
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) return true;
        // Fallback kiểm tra URL scheme
        return await canLaunchUrl(Uri.parse(bank.iosScheme));
      }
    } catch (_) {}
    return false;
  }

  /// Lọc danh sách các ứng dụng ngân hàng đã cài trên máy (nếu kiểm tra được)
  static Future<List<BankAppModel>> getAvailableBanks({
    List<String>? preferredIds,
  }) async {
    // Nếu người dùng đã chọn trước danh sách ưa thích trong Settings
    if (preferredIds != null && preferredIds.isNotEmpty) {
      final preferred = <BankAppModel>[];
      for (final id in preferredIds) {
        final bank = findById(id);
        if (bank != null) preferred.add(bank);
      }
      if (preferred.isNotEmpty) return preferred;
    }

    // Mặc định trả về 6 ngân hàng / ví phổ biến nhất làm gợi ý nhanh
    return supportedBanks.take(6).toList();
  }

  /// Mở ứng dụng ngân hàng qua App-to-App Deeplink hoặc Universal Link Napas VietQR
  static Future<bool> launchBankApp({
    required BankAppModel bank,
    required String qrPayload,
    String? accountNo,
    double? amount,
    String? note,
  }) async {
    // Kịch bản 1: Mở trực tiếp bằng URL Scheme của ngân hàng truyền payload VietQR
    // Chuẩn: [scheme]qr?data=[payload]
    final directSchemeUris = [
      Uri.parse('${bank.iosScheme}qr?data=${Uri.encodeComponent(qrPayload)}'),
      Uri.parse('${bank.iosScheme}pay?data=${Uri.encodeComponent(qrPayload)}'),
      Uri.parse('${bank.iosScheme}transfer?data=${Uri.encodeComponent(qrPayload)}'),
      Uri.parse(bank.iosScheme), // Mở app
    ];

    for (final uri in directSchemeUris) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (_) {}
    }

    // Kịch bản 2: Universal Link App-to-App (Napas VietQR Gateway)
    // Link chuẩn Napas mở thẳng ứng dụng ngân hàng theo BIN và STK
    if (accountNo != null && accountNo.isNotEmpty && bank.bin != 'momo' && bank.bin != 'zalopay') {
      final intAmount = amount?.toInt() ?? 0;
      final encodedNote = Uri.encodeComponent(note ?? '');
      
      final universalLinks = [
        Uri.parse('https://dl.vietqr.io/pay?bin=${bank.bin}&ba=$accountNo&am=$intAmount&des=$encodedNote'),
        Uri.parse('https://api.vietqr.io/${bank.bin}/$accountNo-$intAmount-compact2.jpg?accountName=&amount=$intAmount&addInfo=$encodedNote'),
      ];

      for (final uri in universalLinks) {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}
      }
    }

    // Kịch bản 3: Thử mở scheme gốc của app
    try {
      final fallbackScheme = Uri.parse(bank.iosScheme);
      return await launchUrl(
        fallbackScheme,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
