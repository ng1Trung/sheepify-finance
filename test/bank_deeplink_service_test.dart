import 'package:flutter_test/flutter_test.dart';
import 'package:sheepify/data/models/saved_payee.dart';
import 'package:sheepify/data/services/bank_deeplink_service.dart';

void main() {
  group('BankDeeplinkService Tests', () {
    test('Find bank by BIN', () {
      final tcb = BankDeeplinkService.findByBin('970407');
      expect(tcb, isNotNull);
      expect(tcb!.shortName, 'Techcombank');

      final vcb = BankDeeplinkService.findByBin('970436');
      expect(vcb, isNotNull);
      expect(vcb!.shortName, 'Vietcombank');

      final mb = BankDeeplinkService.findByBin('970422');
      expect(mb, isNotNull);
      expect(mb!.shortName, 'MBBank');

      final momo = BankDeeplinkService.findByBin('momo');
      expect(momo, isNotNull);
      expect(momo!.shortName, 'MoMo');
    });

    test('Find bank by ID', () {
      final acb = BankDeeplinkService.findById('acb');
      expect(acb, isNotNull);
      expect(acb!.shortName, 'ACB');
      expect(acb.bin, '970416');

      final nonExistent = BankDeeplinkService.findById('xyz_bank');
      expect(nonExistent, isNull);
    });

    test('All supported banks have valid schemes and BINs', () {
      for (final bank in BankDeeplinkService.supportedBanks) {
        expect(bank.id.isNotEmpty, isTrue);
        expect(bank.shortName.isNotEmpty, isTrue);
        expect(bank.fullName.isNotEmpty, isTrue);
        expect(bank.iosScheme.endsWith('://'), isTrue);
        expect(bank.androidPackage.isNotEmpty, isTrue);
      }
    });
  });

  group('SavedPayee Model Tests', () {
    test('SavedPayee serialization round-trip', () {
      final now = DateTime.now();
      final payee = SavedPayee(
        id: 'payee_001',
        nickname: 'Chủ nhà trọ',
        bankBin: '970436',
        accountNo: '0011001234567',
        defaultCategoryId: 'cat_rent',
        defaultNote: 'Tien phong thang 10',
        createdAt: now,
      );

      final jsonStr = payee.toJson();
      final restored = SavedPayee.fromJson(jsonStr);

      expect(restored.id, payee.id);
      expect(restored.nickname, payee.nickname);
      expect(restored.bankBin, payee.bankBin);
      expect(restored.accountNo, payee.accountNo);
      expect(restored.defaultCategoryId, payee.defaultCategoryId);
      expect(restored.defaultNote, payee.defaultNote);
    });
  });
}
