import 'package:flutter_test/flutter_test.dart';
import 'package:sheepify/core/utils/bank_alert_parser.dart';

void main() {
  group('BankAlertParser', () {
    test('Vietcombank style: change first, balance after', () {
      final r = BankAlertParser.parse(
        'Biến động số dư\nSố dư TK VCB 0011001234567 -50,000 VND lúc '
        '25-11-2026 10:00:00. Số dư 1,250,000 VND. Ref MBVCB.123. '
        'ND: THANH TOAN QR CAFE ABC',
      );
      expect(r, isNotNull);
      expect(r!.amount, 50000);
      expect(r.isExpense, isTrue);
      expect(r.note, 'THANH TOAN QR CAFE ABC');
    });

    test('MB style with pipes and SD field', () {
      final r = BankAlertParser.parse(
        'TK 0123xxx789|GD: +1,200,000VND 25/11/26 09:12|SD: 5,000,000VND|ND: Luong thang 11',
      );
      expect(r!.amount, 1200000);
      expect(r.isExpense, isFalse);
      expect(r.note, 'Luong thang 11');
    });

    test('dot thousands separator and đ suffix', () {
      final r = BankAlertParser.parse(
        'Tài khoản 1903xxxx: -35.000đ. Số dư: 2.000.000đ. Nội dung: tra sua',
      );
      expect(r!.amount, 35000);
      expect(r.isExpense, isTrue);
      expect(r.note, 'tra sua');
    });

    test('a signed balance is not taken for the change', () {
      final r = BankAlertParser.parse(
        'SD: +9,000,000 VND. GD -120,000 VND. ND: an trua',
      );
      expect(r!.amount, 120000);
      expect(r.isExpense, isTrue);
    });

    test('no signed amount means not a transaction', () {
      expect(BankAlertParser.parse('Mã OTP của bạn là 123456'), isNull);
      expect(BankAlertParser.parse('Số dư hiện tại 1,000,000 VND'), isNull);
    });

    test('missing content gives an empty note', () {
      final r = BankAlertParser.parse('TK 123: -10,000 VND. SD 90,000 VND');
      expect(r!.note, '');
    });
  });
}
