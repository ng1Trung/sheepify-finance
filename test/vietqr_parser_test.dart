import 'package:flutter_test/flutter_test.dart';
import 'package:sheepify/core/utils/vietqr_parser.dart';

void main() {
  group('VietQrParser Tests', () {
    test('Generate and parse dynamic VietQR round-trip', () {
      final generated = VietQrParser.generateVietQr(
        bankBin: '970407', // Techcombank
        bankAccount: '1903456789',
        amount: 50000,
        purpose: 'An trua com tam',
      );

      expect(generated.startsWith('000201'), isTrue);
      expect(generated.contains('970407'), isTrue);
      expect(generated.contains('1903456789'), isTrue);

      final parsed = VietQrParser.parse(generated);
      expect(parsed.isValid, isTrue);
      expect(parsed.bankBin, '970407');
      expect(parsed.bankAccount, '1903456789');
      expect(parsed.amount, 50000);
      expect(parsed.purpose, 'An trua com tam');
      expect(parsed.isDynamic, isTrue);
    });

    test('Generate and parse static VietQR (no amount, no note)', () {
      final generated = VietQrParser.generateVietQr(
        bankBin: '970436', // Vietcombank
        bankAccount: '0011001234567',
      );

      final parsed = VietQrParser.parse(generated);
      expect(parsed.isValid, isTrue);
      expect(parsed.bankBin, '970436');
      expect(parsed.bankAccount, '0011001234567');
      expect(parsed.hasAmount, isFalse);
      expect(parsed.isDynamic, isFalse);
    });

    test('Update static VietQR with amount and note', () {
      final staticQr = VietQrParser.generateVietQr(
        bankBin: '970422', // MBBank
        bankAccount: '0987654321',
      );

      final updatedQr = VietQrParser.updatePayloadWithAmountAndNote(
        existingPayload: staticQr,
        amount: 85000,
        note: 'Highlands Coffee',
      );

      final parsed = VietQrParser.parse(updatedQr);
      expect(parsed.isValid, isTrue);
      expect(parsed.bankBin, '970422');
      expect(parsed.bankAccount, '0987654321');
      expect(parsed.amount, 85000);
      expect(parsed.purpose, 'Highlands Coffee');
      expect(parsed.isDynamic, isTrue);
    });

    test('Parse URL format', () {
      const url = 'https://dl.vietqr.io/pay?ba=123456789&bin=970407&am=100000&des=TraTienNha';
      final parsed = VietQrParser.parse(url);
      expect(parsed.isValid, isTrue);
      expect(parsed.bankAccount, '123456789');
      expect(parsed.bankBin, '970407');
      expect(parsed.amount, 100000);
      expect(parsed.purpose, 'TraTienNha');
    });

    test('Calculate CRC16 produces valid 4-character hex', () {
      final crc = VietQrParser.calculateCrc16('0002010102116304');
      final hex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');
      expect(hex.length, 4);
    });
  });
}
