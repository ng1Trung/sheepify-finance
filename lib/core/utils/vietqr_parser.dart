import 'dart:convert';

/// Model chứa dữ liệu giải mã từ mã VietQR
class VietQrModel {
  final String rawPayload;
  final String? bankBin;
  final String? bankAccount;
  final double? amount;
  final String? purpose;
  final String? serviceCode;
  final bool isDynamic;
  final bool isValid;
  final String? errorMessage;

  const VietQrModel({
    required this.rawPayload,
    this.bankBin,
    this.bankAccount,
    this.amount,
    this.purpose,
    this.serviceCode,
    this.isDynamic = false,
    this.isValid = true,
    this.errorMessage,
  });

  bool get hasAmount => amount != null && amount! > 0;
  bool get hasAccount => bankAccount != null && bankAccount!.isNotEmpty;
  bool get hasBankBin => bankBin != null && bankBin!.isNotEmpty;

  @override
  String toString() {
    return 'VietQrModel(bankBin: $bankBin, bankAccount: $bankAccount, amount: $amount, purpose: $purpose, isDynamic: $isDynamic, isValid: $isValid)';
  }
}

/// Bộ phân tích (Parser) và Tạo mã (Generator) theo chuẩn EMVCo VietQR của NAPAS
class VietQrParser {
  static const String napasGuid = 'A000000727';
  static const String defaultServiceCode = 'QRIBFTTA'; // Chuyển nhanh qua STK
  static const String defaultCurrency = '704'; // VND
  static const String defaultCountry = 'VN';

  /// Giải mã một chuỗi bất kỳ (chuỗi EMVCo hoặc URL VietQR)
  static VietQrModel parse(String rawInput) {
    final text = rawInput.trim();
    if (text.isEmpty) {
      return const VietQrModel(
        rawPayload: '',
        isValid: false,
        errorMessage: 'Mã QR rỗng',
      );
    }

    // 1. Nếu là URL VietQR (dạng https://img.vietqr.io/... hoặc https://dl.vietqr.io/pay?...)
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return _parseFromUrl(text);
    }

    // 2. Kiểm tra format EMVCo bắt đầu bằng "000201"
    if (!text.startsWith('000201')) {
      return VietQrModel(
        rawPayload: text,
        isValid: false,
        errorMessage: 'Mã QR không đúng định dạng thanh toán VietQR (EMVCo)',
      );
    }

    try {
      final tlvMap = _parseTlv(text);

      // Tag 01: Initiation Method (11: Static, 12: Dynamic)
      final initiationMethod = tlvMap['01'] ?? '11';
      final isDynamic = initiationMethod == '12';

      // Tag 38: Thông tin người thụ hưởng Napas
      String? bankBin;
      String? bankAccount;
      String? serviceCode;

      if (tlvMap.containsKey('38')) {
        final tag38Content = tlvMap['38']!;
        final subMap38 = _parseTlv(tag38Content);

        // Sub-tag 01: Consumer Account Info
        if (subMap38.containsKey('01')) {
          final subMap01 = _parseTlv(subMap38['01']!);
          bankBin = subMap01['00']; // Mã BIN ngân hàng (VD: 970407)
          bankAccount = subMap01['01']; // Số tài khoản người nhận
        }

        // Sub-tag 02: Service Code (QRIBFTTA hoặc QRIBFTTC)
        serviceCode = subMap38['02'];
      }

      // Tag 54: Số tiền giao dịch
      double? amount;
      if (tlvMap.containsKey('54')) {
        amount = double.tryParse(tlvMap['54']!);
      }

      // Tag 62: Thông tin bổ sung (Nội dung giao dịch)
      String? purpose;
      if (tlvMap.containsKey('62')) {
        final subMap62 = _parseTlv(tlvMap['62']!);
        // Sub-tag 08: Purpose of transaction (Nội dung)
        // Sub-tag 01: Bill Number
        purpose = subMap62['08'] ?? subMap62['01'] ?? subMap62['07'];
      }

      // Kiểm tra tính hợp lệ cơ bản
      if (bankBin == null && bankAccount == null) {
        return VietQrModel(
          rawPayload: text,
          isValid: false,
          errorMessage: 'Không tìm thấy thông tin tài khoản ngân hàng trong mã QR',
        );
      }

      return VietQrModel(
        rawPayload: text,
        bankBin: bankBin,
        bankAccount: bankAccount,
        amount: amount,
        purpose: purpose,
        serviceCode: serviceCode ?? defaultServiceCode,
        isDynamic: isDynamic,
        isValid: true,
      );
    } catch (e) {
      return VietQrModel(
        rawPayload: text,
        isValid: false,
        errorMessage: 'Lỗi bóc tách mã QR: $e',
      );
    }
  }

  /// Tạo chuỗi EMVCo VietQR hoàn chỉnh có đính kèm số tiền và nội dung
  static String generateVietQr({
    required String bankBin,
    required String bankAccount,
    double? amount,
    String? purpose,
    String serviceCode = defaultServiceCode,
  }) {
    final buffer = StringBuffer();

    // 00: Payload Format Indicator (01)
    _appendTlv(buffer, '00', '01');

    // 01: Initiation Method (12: Dynamic nếu có số tiền, 11: Static nếu không có số tiền)
    final isDynamic = amount != null && amount > 0;
    _appendTlv(buffer, '01', isDynamic ? '12' : '11');

    // 38: Merchant Account Information
    final sub38Buffer = StringBuffer();
    // 38-00: GUID Napas
    _appendTlv(sub38Buffer, '00', napasGuid);
    // 38-01: Beneficiary (00: Bank BIN, 01: Account No)
    final sub01Buffer = StringBuffer();
    _appendTlv(sub01Buffer, '00', bankBin.trim());
    _appendTlv(sub01Buffer, '01', bankAccount.trim());
    _appendTlv(sub38Buffer, '01', sub01Buffer.toString());
    // 38-02: Service Code
    _appendTlv(sub38Buffer, '02', serviceCode);
    _appendTlv(buffer, '38', sub38Buffer.toString());

    // 53: Transaction Currency (704 = VND)
    _appendTlv(buffer, '53', defaultCurrency);

    // 54: Transaction Amount
    if (amount != null && amount > 0) {
      // Định dạng số nguyên (VND không dùng số thập phân)
      final formattedAmount = amount.toInt().toString();
      _appendTlv(buffer, '54', formattedAmount);
    }

    // 58: Country Code (VN)
    _appendTlv(buffer, '58', defaultCountry);

    // 62: Additional Data Field (Nội dung chuyển khoản)
    if (purpose != null && purpose.trim().isNotEmpty) {
      final sub62Buffer = StringBuffer();
      // Loại bỏ dấu tiếng Việt để tương thích tốt nhất với hệ thống ngân hàng
      final cleanPurpose = _removeVietnameseDiacritics(purpose.trim());
      _appendTlv(sub62Buffer, '08', cleanPurpose);
      _appendTlv(buffer, '62', sub62Buffer.toString());
    }

    // 63: CRC16 Checksum
    final payloadBeforeCrc = '${buffer.toString()}6304';
    final crcValue = calculateCrc16(payloadBeforeCrc);
    final crcHex = crcValue.toRadixString(16).toUpperCase().padLeft(4, '0');

    return '$payloadBeforeCrc$crcHex';
  }

  /// Cập nhật số tiền và nội dung vào một chuỗi VietQR sẵn có
  static String updatePayloadWithAmountAndNote({
    required String existingPayload,
    required double amount,
    String? note,
  }) {
    final parsed = parse(existingPayload);
    if (!parsed.isValid || parsed.bankBin == null || parsed.bankAccount == null) {
      return existingPayload;
    }

    return generateVietQr(
      bankBin: parsed.bankBin!,
      bankAccount: parsed.bankAccount!,
      amount: amount,
      purpose: note ?? parsed.purpose,
      serviceCode: parsed.serviceCode ?? defaultServiceCode,
    );
  }

  /// Tính mã CRC-16-CCITT (Polynomial 0x1021, Initial value 0xFFFF)
  static int calculateCrc16(String input) {
    final bytes = utf8.encode(input);
    int crc = 0xFFFF;
    const int polynomial = 0x1021;

    for (final byte in bytes) {
      for (int i = 0; i < 8; i++) {
        final bool bit = ((byte >> (7 - i)) & 1) == 1;
        final bool c15 = ((crc >> 15) & 1) == 1;
        crc <<= 1;
        crc &= 0xFFFF;
        if (c15 ^ bit) {
          crc ^= polynomial;
        }
      }
    }

    return crc & 0xFFFF;
  }

  // --- HÀM TRỢ GIÚP NỘI BỘ (INTERNAL HELPERS) ---

  /// Bóc tách chuỗi TLV (Tag 2 chars, Length 2 chars, Value)
  static Map<String, String> _parseTlv(String input) {
    final Map<String, String> result = {};
    int index = 0;

    while (index + 4 <= input.length) {
      final tag = input.substring(index, index + 2);
      final lengthStr = input.substring(index + 2, index + 4);
      final length = int.tryParse(lengthStr);

      if (length == null || index + 4 + length > input.length) {
        break;
      }

      final value = input.substring(index + 4, index + 4 + length);
      result[tag] = value;
      index += 4 + length;
    }

    return result;
  }

  static void _appendTlv(StringBuffer buffer, String tag, String value) {
    final lengthStr = value.length.toString().padLeft(2, '0');
    buffer.write('$tag$lengthStr$value');
  }

  static VietQrModel _parseFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final query = uri.queryParameters;

      final amount = double.tryParse(query['amount'] ?? query['am'] ?? '');
      final purpose = query['memo'] ?? query['des'] ?? query['note'];
      final bankBin = query['bin'] ?? query['bankCode'];
      final bankAccount = query['accountNo'] ?? query['ba'];

      if (bankBin != null || bankAccount != null) {
        return VietQrModel(
          rawPayload: url,
          bankBin: bankBin,
          bankAccount: bankAccount,
          amount: amount,
          purpose: purpose,
          isDynamic: amount != null && amount > 0,
          isValid: true,
        );
      }
    } catch (_) {}

    return VietQrModel(
      rawPayload: url,
      isValid: false,
      errorMessage: 'URL không chứa dữ liệu VietQR hợp lệ',
    );
  }

  /// Loại bỏ dấu tiếng Việt để an toàn khi gửi sang hệ thống ngân hàng
  static String _removeVietnameseDiacritics(String str) {
    const vietnamese = 'aAeEoOuUiIdDyY';
    final patterns = [
      RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'),
      RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'),
      RegExp(r'[èéẹẻẽêềếệểễ]'),
      RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'),
      RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'),
      RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'),
      RegExp(r'[ùúụủũưừứựửữ]'),
      RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'),
      RegExp(r'[ìíịỉĩ]'),
      RegExp(r'[ÌÍỊỈĨ]'),
      RegExp(r'[đ]'),
      RegExp(r'[Đ]'),
      RegExp(r'[ỳýỵỷỹ]'),
      RegExp(r'[ỲÝỴỶỸ]'),
    ];

    String result = str;
    for (int i = 0; i < patterns.length; i++) {
      result = result.replaceAll(patterns[i], vietnamese[i]);
    }
    return result;
  }
}
