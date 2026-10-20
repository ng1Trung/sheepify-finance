import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/vietqr_parser.dart';
import 'notification_service.dart';

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
  final String? vietQrAppId; // Mã định danh app trên cổng dl.vietqr.io
  final List<String> alternativeSchemes; // Các URL scheme bổ sung trên Android/iOS
  final List<String> alternativeAndroidPackages; // Các package name bổ sung trên Android
  final bool supportsVietQrAutofill; // Ngân hàng hỗ trợ điền sẵn STK + số tiền qua VietQR deeplink

  const BankAppModel({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.bin,
    required this.iosScheme,
    required this.androidPackage,
    required this.brandColor,
    this.logoUrl,
    this.vietQrAppId,
    this.alternativeSchemes = const [],
    this.alternativeAndroidPackages = const [],
    this.supportsVietQrAutofill = false,
  });

  /// Danh sách tất cả các URL scheme hỗ trợ (ưu tiên scheme chuẩn VietQR hiện hành trước)
  List<String> get allSchemes => <String>{
        ...alternativeSchemes,
        iosScheme,
      }.toList();

  /// Danh sách tất cả các Android package hỗ trợ
  List<String> get allAndroidPackages => <String>{
        ...alternativeAndroidPackages,
        androidPackage,
      }.toList();

  /// Cho biết ngân hàng này có hỗ trợ điền sẵn thông tin thanh toán tự động không
  bool get canAutofillPayment =>
      supportsVietQrAutofill || id == 'techcombank' || id == 'vcb';

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
      alternativeSchemes: ['vietcombankmobile://'],
      androidPackage: 'com.VCB',
      vietQrAppId: 'vcb',
      supportsVietQrAutofill: true,
      brandColor: Color(0xFF005A36),
      logoUrl: 'https://api.vietqr.io/img/VCB.png',
    ),
    const BankAppModel(
      id: 'techcombank',
      shortName: 'Techcombank',
      fullName: 'Ngân hàng TMCP Kỹ Thương Việt Nam (Techcombank Mobile)',
      bin: '970407',
      iosScheme: 'techcombank://',
      alternativeSchemes: ['tcb://'],
      androidPackage: 'vn.com.techcombank.bb.app',
      vietQrAppId: 'tcb',
      supportsVietQrAutofill: true,
      brandColor: Color(0xFFE60000),
      logoUrl: 'https://api.vietqr.io/img/TCB.png',
    ),
    const BankAppModel(
      id: 'mb',
      shortName: 'MBBank',
      fullName: 'Ngân hàng TMCP Quân Đội (MB Bank)',
      bin: '970422',
      iosScheme: 'mbmobile://',
      alternativeSchemes: ['mbbank://'],
      androidPackage: 'com.mbmobile',
      vietQrAppId: 'mb',
      supportsVietQrAutofill: true,
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
      vietQrAppId: 'momo',
      brandColor: Color(0xFFA50064),
      logoUrl: 'https://api.vietqr.io/img/momo.png',
    ),
    const BankAppModel(
      id: 'tpb',
      shortName: 'TPBank',
      fullName: 'Ngân hàng TMCP Tiên Phong (TPBank Mobile)',
      bin: '970423',
      iosScheme: 'tpb://',
      alternativeSchemes: ['hydro://'],
      androidPackage: 'com.tpb.mb.gprsandroid',
      vietQrAppId: 'tpb',
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
      vietQrAppId: 'vpb',
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
      vietQrAppId: 'acb',
      supportsVietQrAutofill: true,
      brandColor: Color(0xFF005BAC),
      logoUrl: 'https://api.vietqr.io/img/ACB.png',
    ),
    const BankAppModel(
      id: 'bidv',
      shortName: 'BIDV',
      fullName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam',
      bin: '970418',
      iosScheme: 'bidvsmartbanking://',
      alternativeSchemes: ['bidv.smartbanking.partner://'],
      androidPackage: 'com.vnpay.bidv',
      vietQrAppId: 'bidv',
      supportsVietQrAutofill: true,
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
      vietQrAppId: 'icb',
      supportsVietQrAutofill: true,
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
      vietQrAppId: 'zalopay',
      brandColor: Color(0xFF0068FF),
      logoUrl: 'https://api.vietqr.io/img/zalopay.png',
    ),
    const BankAppModel(
      id: 'timo',
      shortName: 'Timo',
      fullName: 'Ngân hàng số Timo Digital Bank',
      bin: '963388',
      iosScheme: 'timo://',
      alternativeSchemes: ['plus://'],
      androidPackage: 'vn.timo.mobile',
      alternativeAndroidPackages: ['io.lifestyle.plus'],
      vietQrAppId: 'timo',
      brandColor: Color(0xFF7B1FA2),
      logoUrl: 'https://api.vietqr.io/img/TIMO.png',
    ),
    const BankAppModel(
      id: 'cake',
      shortName: 'Cake by VPBank',
      fullName: 'Ngân hàng số Cake by VPBank',
      bin: '546034',
      iosScheme: 'cake://',
      alternativeSchemes: ['cake.vn://'],
      androidPackage: 'xyz.be.cake',
      vietQrAppId: 'cake',
      brandColor: Color(0xFFFF5252),
      logoUrl: 'https://api.vietqr.io/img/CAKE.png',
    ),
    const BankAppModel(
      id: 'ocb',
      shortName: 'OCB',
      fullName: 'Ngân hàng TMCP Phương Đông (OCB OMNI)',
      bin: '970448',
      iosScheme: 'ocbomni40://',
      alternativeSchemes: ['ocbomni://'],
      androidPackage: 'vn.com.ocb.awe',
      vietQrAppId: 'ocb',
      supportsVietQrAutofill: true,
      brandColor: Color(0xFF008345),
      logoUrl: 'https://api.vietqr.io/img/OCB.png',
    ),
    const BankAppModel(
      id: 'agribank',
      shortName: 'Agribank',
      fullName: 'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam (Agribank Plus)',
      bin: '970405',
      iosScheme: 'agribankplus://',
      alternativeSchemes: ['vba://'],
      androidPackage: 'com.vnpay.agribank',
      vietQrAppId: 'vba',
      brandColor: Color(0xFF8B1D24),
      logoUrl: 'https://api.vietqr.io/img/VBA.png',
    ),
    const BankAppModel(
      id: 'vib',
      shortName: 'VIB',
      fullName: 'Ngân hàng TMCP Quốc tế Việt Nam (MyVIB)',
      bin: '970441',
      iosScheme: 'vib://',
      alternativeSchemes: ['myvib2://'],
      androidPackage: 'com.vib.myvib2',
      alternativeAndroidPackages: ['com.vng.vib'],
      vietQrAppId: 'vib-2',
      brandColor: Color(0xFF0054A6),
      logoUrl: 'https://api.vietqr.io/img/VIB.png',
    ),
    const BankAppModel(
      id: 'sacombank',
      shortName: 'Sacombank',
      fullName: 'Ngân hàng TMCP Sài Gòn Thương Tín (Sacombank Pay)',
      bin: '970403',
      iosScheme: 'sacombankpay://',
      androidPackage: 'com.vnpay.sacombank',
      vietQrAppId: 'stb',
      brandColor: Color(0xFF00529C),
      logoUrl: 'https://api.vietqr.io/img/STB.png',
    ),
    const BankAppModel(
      id: 'shb',
      shortName: 'SHB',
      fullName: 'Ngân hàng TMCP Sài Gòn - Hà Nội (SHB SAHA)',
      bin: '970443',
      iosScheme: 'shbsaha://',
      androidPackage: 'com.vnpay.shb',
      vietQrAppId: 'shb',
      brandColor: Color(0xFFFF6600),
      logoUrl: 'https://api.vietqr.io/img/SHB.png',
    ),
    const BankAppModel(
      id: 'hdbank',
      shortName: 'HDBank',
      fullName: 'Ngân hàng TMCP Phát triển Thành phố Hồ Chí Minh (HDBank)',
      bin: '970437',
      iosScheme: 'hdbank://',
      androidPackage: 'com.vnpay.hdbank',
      vietQrAppId: 'hdb',
      brandColor: Color(0xFFE50914),
      logoUrl: 'https://api.vietqr.io/img/HDB.png',
    ),
    const BankAppModel(
      id: 'lpbank',
      shortName: 'LPBank',
      fullName: 'Ngân hàng TMCP Lộc Phát Việt Nam (LPBank)',
      bin: '970449',
      iosScheme: 'lpbank://',
      alternativeSchemes: ['lpb://'],
      androidPackage: 'com.vnpay.lpb',
      vietQrAppId: 'lpb',
      brandColor: Color(0xFFDF7401),
      logoUrl: 'https://api.vietqr.io/img/LPB.png',
    ),
    const BankAppModel(
      id: 'viettelmoney',
      shortName: 'Viettel Money',
      fullName: 'Hệ sinh thái tài chính số Viettel Money',
      bin: 'viettelmoney',
      iosScheme: 'viettelmoney://',
      alternativeSchemes: ['viettelpay://'],
      androidPackage: 'com.bplus.vtpay',
      vietQrAppId: 'viettelmoney',
      brandColor: Color(0xFFEE0033),
      logoUrl: 'https://api.vietqr.io/img/VIETTELMONEY.png',
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

  /// Tìm ngân hàng theo ID hoặc mã VietQR App ID
  static BankAppModel? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    final clean = id.trim().toLowerCase();
    try {
      return supportedBanks.firstWhere(
        (b) =>
            b.id.toLowerCase() == clean ||
            (b.vietQrAppId != null && b.vietQrAppId!.toLowerCase() == clean),
      );
    } catch (_) {
      return null;
    }
  }

  /// Tạo URI chuẩn VietQR Deeplink theo tài liệu chính thức (https://www.vietqr.io/deeplink.md):
  /// https://dl.vietqr.io/pay?app={appId}&am={soTien}&tn={noiDung}&ba={soTaiKhoan}@{maNganHang}&url=https://www.vietqr.io/deeplink
  static Uri? buildVietQrDeeplinkUri({
    required BankAppModel bank,
    required String accountNo,
    String? recipientBin,
    double? amount,
    String? note,
  }) {
    final cleanAccount = accountNo.trim();
    if (cleanAccount.isEmpty || bank.bin == 'momo' || bank.bin == 'zalopay') {
      return null;
    }

    final sendingAppId = bank.vietQrAppId ?? bank.id;
    final recipientBank =
        findByBin(recipientBin) ?? findById(recipientBin);
    final recipientCode = recipientBank?.vietQrAppId ??
        ((recipientBin != null && recipientBin.trim().isNotEmpty)
            ? recipientBin.trim()
            : sendingAppId);

    final intAmount = (amount != null && amount > 0) ? amount.toInt() : 0;
    final cleanNote = VietQrParser.sanitizeTransferNote(note ?? '');

    final buffer = StringBuffer(
      'https://dl.vietqr.io/pay?app=${Uri.encodeQueryComponent(sendingAppId)}',
    );
    if (intAmount > 0) {
      buffer.write('&am=$intAmount');
    }
    if (cleanNote.isNotEmpty) {
      buffer.write('&tn=${Uri.encodeQueryComponent(cleanNote)}');
    }
    // Lưu ý theo chuẩn VietQR: ký tự '@' trong `ba` và 'https://' trong `url` không được percent-encode
    buffer.write(
      '&ba=${Uri.encodeQueryComponent(cleanAccount)}@${Uri.encodeQueryComponent(recipientCode)}'
      '&url=https://www.vietqr.io/deeplink',
    );

    return Uri.parse(buffer.toString());
  }

  /// Kiểm tra xem ứng dụng ngân hàng này có được cài trên thiết bị không
  static Future<bool> isAppInstalled(BankAppModel bank) async {
    try {
      if (Platform.isIOS) {
        for (final scheme in bank.allSchemes) {
          if (await canLaunchUrl(Uri.parse(scheme))) {
            return true;
          }
        }
      } else if (Platform.isAndroid) {
        // Kiểm tra qua URL Scheme chuẩn
        for (final scheme in bank.allSchemes) {
          if (await canLaunchUrl(Uri.parse(scheme))) {
            return true;
          }
        }
        // Kiểm tra qua Android Intent URI có chỉ định package
        for (final pkg in bank.allAndroidPackages) {
          for (final scheme in bank.allSchemes) {
            final schemeName = scheme.replaceAll('://', '');
            try {
              final intentUri = Uri.parse(
                'intent://applink#Intent;scheme=$schemeName;package=$pkg;end',
              );
              if (await canLaunchUrl(intentUri)) {
                return true;
              }
            } catch (_) {}
          }
        }
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

  /// Mở ứng dụng ngân hàng qua cổng VietQR Deeplink (autofill STK, số tiền, nội dung)
  /// hoặc fallback về URL Scheme / Android Intent của ngân hàng.
  /// Tự động sao chép STK vào Clipboard và đẩy thông báo Trợ lý chuyển khoản để hỗ trợ người dùng.
  static Future<bool> launchBankApp({
    required BankAppModel bank,
    required String qrPayload,
    String? accountNo,
    String? recipientBin,
    double? amount,
    String? note,
  }) async {
    // Tự động trích xuất thông tin người nhận từ qrPayload nếu chưa truyền trực tiếp
    final parsedQr = VietQrParser.parse(qrPayload);
    final resolvedAccountNo =
        (accountNo != null && accountNo.trim().isNotEmpty)
            ? accountNo.trim()
            : parsedQr.bankAccount;
    final resolvedRecipientBin =
        (recipientBin != null && recipientBin.trim().isNotEmpty)
            ? recipientBin.trim()
            : parsedQr.bankBin;
    final resolvedAmount = amount ?? parsedQr.amount;
    final resolvedNote = note ?? parsedQr.purpose;

    // 1. TỰ ĐỘNG SAO CHÉP STK VÀO CLIPBOARD (BỘ NHỚ TẠM)
    // Các ngân hàng như Techcombank, Vietcombank, TPBank... không có API autofill công khai
    // từ app bên ngoài vì lý do bảo mật. Khi STK đã có sẵn trong clipboard:
    // - App ngân hàng sẽ tự động hiện thông báo "Bạn có muốn chuyển tiền đến STK...?"
    // - Hoặc người dùng chỉ cần chạm "Dán" trong ô STK nhận mà không cần gõ thủ công.
    if (resolvedAccountNo != null && resolvedAccountNo.isNotEmpty) {
      try {
        await Clipboard.setData(ClipboardData(text: resolvedAccountNo));
      } catch (_) {}
    }

    // 2. ĐẨY THÔNG BÁO LOCAL NOTIFICATION (TRỢ LÝ CHUYỂN KHOẢN)
    // Khi đang trong app ngân hàng, người dùng chỉ cần vuốt thanh thông báo xuống
    // là thấy ngay STK, số tiền, nội dung mà không phải chuyển qua lại giữa các app.
    if (resolvedAccountNo != null && resolvedAccountNo.isNotEmpty) {
      final recipientBank = findByBin(resolvedRecipientBin) ?? findById(resolvedRecipientBin);
      try {
        await NotificationService.showPaymentAssistantNotification(
          bankName: bank.shortName,
          recipientBankName: recipientBank?.shortName ?? 'Ngân hàng nhận',
          accountNo: resolvedAccountNo,
          amount: resolvedAmount,
          note: resolvedNote,
        );
      } catch (_) {}
    }

    final vietQrUri = (resolvedAccountNo != null && resolvedAccountNo.isNotEmpty)
        ? buildVietQrDeeplinkUri(
            bank: bank,
            accountNo: resolvedAccountNo,
            recipientBin: resolvedRecipientBin,
            amount: resolvedAmount,
            note: resolvedNote,
          )
        : null;

    // Kịch bản 1: Với các ngân hàng hỗ trợ VietQR Autofill (MB, ACB, BIDV, VietinBank, OCB),
    // mở qua cổng dl.vietqr.io/pay bằng LaunchMode.externalApplication để cổng thực thi
    // handshake /pay/claim và điều hướng thẳng vào màn hình chuyển khoản đã điền sẵn STK, số tiền, nội dung.
    if (bank.supportsVietQrAutofill && vietQrUri != null) {
      try {
        final launched = await launchUrl(
          vietQrUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {}
    }

    // Kịch bản 2: Mở trực tiếp bằng URL Scheme gốc của ngân hàng (cả Android & iOS)
    // Không ghép các hậu tố giả (?data=...) vì canLaunchUrl chỉ kiểm tra scheme,
    // nếu truyền route không tồn tại app ngân hàng sẽ bỏ qua và chỉ mở màn hình chính.
    for (final scheme in bank.allSchemes) {
      final uri = Uri.parse(scheme);
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

    // Kịch bản 3: Trên Android, hỗ trợ mở qua Android Intent URI có chỉ định package
    // hoặc cổng điều hướng VietQR Deeplink chuẩn
    if (Platform.isAndroid) {
      for (final pkg in bank.allAndroidPackages) {
        for (final scheme in bank.allSchemes) {
          final schemeName = scheme.replaceAll('://', '');
          try {
            final intentUri = Uri.parse(
              'intent://applink#Intent;scheme=$schemeName;package=$pkg;end',
            );
            if (await canLaunchUrl(intentUri)) {
              final launched = await launchUrl(
                intentUri,
                mode: LaunchMode.externalApplication,
              );
              if (launched) return true;
            }
          } catch (_) {}
        }
      }

      if (vietQrUri != null) {
        try {
          final launched = await launchUrl(
            vietQrUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}
      }
    }

    // Kịch bản 4: Thử mở trực tiếp các scheme gốc không qua canLaunchUrl (phòng trường hợp OS chặn query)
    for (final scheme in bank.allSchemes) {
      try {
        final launched = await launchUrl(
          Uri.parse(scheme),
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {}
    }

    return false;
  }
}
