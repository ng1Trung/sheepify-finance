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

      final agribank = BankDeeplinkService.findByBin('970405');
      expect(agribank, isNotNull);
      expect(agribank!.shortName, 'Agribank');

      final vib = BankDeeplinkService.findByBin('970441');
      expect(vib, isNotNull);
      expect(vib!.shortName, 'VIB');

      final stb = BankDeeplinkService.findByBin('970403');
      expect(stb, isNotNull);
      expect(stb!.shortName, 'Sacombank');

      final shb = BankDeeplinkService.findByBin('970443');
      expect(shb, isNotNull);
      expect(shb!.shortName, 'SHB');

      final hdb = BankDeeplinkService.findByBin('970437');
      expect(hdb, isNotNull);
      expect(hdb!.shortName, 'HDBank');

      final lpb = BankDeeplinkService.findByBin('970449');
      expect(lpb, isNotNull);
      expect(lpb!.shortName, 'LPBank');

      final viettel = BankDeeplinkService.findByBin('viettelmoney');
      expect(viettel, isNotNull);
      expect(viettel!.shortName, 'Viettel Money');
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
        expect(bank.allSchemes.every((s) => s.endsWith('://')), isTrue);
        expect(bank.androidPackage.isNotEmpty, isTrue);
        expect(bank.allAndroidPackages.every((p) => p.isNotEmpty), isTrue);
      }
    });

    test('Build VietQR deeplink URI for bank transfer', () {
      final mb = BankDeeplinkService.findById('mb')!;
      final uri = BankDeeplinkService.buildVietQrDeeplinkUri(
        bank: mb,
        accountNo: '0011001234567',
        recipientBin: '970436', // Vietcombank
        amount: 150000,
        note: 'Trả tiền ăn trưa',
      );

      expect(uri, isNotNull);
      expect(uri!.host, 'dl.vietqr.io');
      expect(uri.path, '/pay');
      expect(uri.queryParameters['app'], 'mb');
      expect(uri.queryParameters['ba'], '0011001234567@vcb');
      expect(uri.queryParameters['am'], '150000');
      expect(uri.queryParameters['tn'], 'Tra tien an trua');
      expect(uri.queryParameters['url'], 'https://www.vietqr.io/deeplink');
      expect(uri.toString(), contains('ba=0011001234567@vcb'));
      expect(uri.toString(), contains('url=https://www.vietqr.io/deeplink'));
    });

    test('canAutofillPayment identifies automatic vs manual type 2 banks/wallets', () {
      // Nhóm tự động điền thông tin (Techcombank, Vietcombank, MB, ACB, BIDV, VietinBank, OCB)
      expect(BankDeeplinkService.findById('techcombank')!.canAutofillPayment, isTrue);
      expect(BankDeeplinkService.findById('vcb')!.canAutofillPayment, isTrue);
      expect(BankDeeplinkService.findById('mb')!.canAutofillPayment, isTrue);
      expect(BankDeeplinkService.findById('acb')!.canAutofillPayment, isTrue);
      expect(BankDeeplinkService.findById('bidv')!.canAutofillPayment, isTrue);
      expect(BankDeeplinkService.findById('vietinbank')!.canAutofillPayment, isTrue);
      expect(BankDeeplinkService.findById('ocb')!.canAutofillPayment, isTrue);

      // Nhóm Loại 2 (Ví điện tử hoặc ngân hàng cần xác nhận thủ công)
      expect(BankDeeplinkService.findById('momo')!.canAutofillPayment, isFalse);
      expect(BankDeeplinkService.findById('zalopay')!.canAutofillPayment, isFalse);
      expect(BankDeeplinkService.findById('viettelmoney')!.canAutofillPayment, isFalse);
      expect(BankDeeplinkService.findById('tpb')!.canAutofillPayment, isFalse);
      expect(BankDeeplinkService.findById('vpbank')!.canAutofillPayment, isFalse);
      expect(BankDeeplinkService.findById('timo')!.canAutofillPayment, isFalse);
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
