import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sheepify/core/utils/category_image_store.dart';
import 'package:sheepify/core/constants/constants.dart';
import 'package:sheepify/data/models/category_model.dart';
import 'package:sheepify/data/models/settings_model.dart';
import 'package:sheepify/data/models/transaction.dart';
import 'package:sheepify/data/services/data_portability_service.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'sheepify_restore_test_',
    );
    Hive.init(hiveDirectory.path);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      hiveDirectory.path,
    );
    await CategoryImageStore.initialize();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  setUp(() async {
    await _resetHiveBoxes();
  });

  tearDown(() async {
    await _resetHiveBoxes();
  });

  group('Data portability mappers', () {
    test('transaction mapper roundtrips all fields', () {
      final tx = Transaction(
        id: 'tx_1',
        note: 'Cafe, "quoted"\nnew line',
        amount: 125000.5,
        date: DateTime.utc(2026, 6, 11, 8, 30),
        isExpense: true,
        categoryId: 'cat_food',
        imagePath: 'transaction_images/receipt.jpg',
      );

      final dto = TransactionBackupDto.fromJson(
        TransactionBackupDto.fromModel(tx).toJson(),
      );
      final restored = dto.toModel();

      expect(restored.id, tx.id);
      expect(restored.note, tx.note);
      expect(restored.amount, tx.amount);
      expect(restored.date, tx.date);
      expect(restored.isExpense, tx.isExpense);
      expect(restored.categoryId, tx.categoryId);
      expect(restored.imagePath, tx.imagePath);
    });

    test('category mapper roundtrips goal and visual fields', () {
      final category = CategoryModel(
        id: 'cat_goal',
        name: 'Du lịch',
        iconCode: 123,
        isExpense: false,
        budget: 1000000,
        colorValue: 0xFF00AA66,
        typeIndex: 2,
        targetAmount: 5000000,
        targetDate: DateTime.utc(2026, 12, 31),
        goalTypeIndex: 2,
        reminderDay: 15,
        targetYear: 2026,
        targetMonth: 12,
        imagePath: 'category_images/travel.jpg',
      );

      final dto = CategoryBackupDto.fromJson(
        CategoryBackupDto.fromModel(category).toJson(),
      );
      final restored = dto.toModel();

      expect(restored.id, category.id);
      expect(restored.name, category.name);
      expect(restored.iconCode, category.iconCode);
      expect(restored.isExpense, category.isExpense);
      expect(restored.budget, category.budget);
      expect(restored.colorValue, category.colorValue);
      expect(restored.typeIndex, category.typeIndex);
      expect(restored.targetAmount, category.targetAmount);
      expect(restored.targetDate, category.targetDate);
      expect(restored.goalTypeIndex, category.goalTypeIndex);
      expect(restored.reminderDay, category.reminderDay);
      expect(restored.targetYear, category.targetYear);
      expect(restored.targetMonth, category.targetMonth);
      expect(restored.imagePath, category.imagePath);
    });

    test('settings mapper roundtrips privacy and theme fields', () {
      final settings = AppSettings(
        accumulateBalance: false,
        themePresetName: 'Sheep Green',
        languageCode: 'en',
        currencyCode: 'USD',
        fontFamily: 'Quicksand',
        isDarkMode: true,
        avatarImageRef: 'avatar_images/me.jpg',
        financialCycleStartDay: 10,
        themeMode: 'dark',
        hideAmounts: true,
        weekStartDay: DateTime.sunday,
      );

      final dto = SettingsBackupDto.fromJson(
        SettingsBackupDto.fromModel(settings).toJson(),
      );
      final restored = dto.toModel();

      expect(restored.accumulateBalance, settings.accumulateBalance);
      expect(restored.themePresetName, settings.themePresetName);
      expect(restored.languageCode, settings.languageCode);
      expect(restored.currencyCode, settings.currencyCode);
      expect(restored.fontFamily, settings.fontFamily);
      expect(restored.isDarkMode, settings.isDarkMode);
      expect(restored.hideAmounts, settings.hideAmounts);
      expect(restored.themeMode, settings.themeMode);
      expect(restored.avatarImageRef, settings.avatarImageRef);
      expect(restored.financialCycleStartDay, settings.financialCycleStartDay);
      expect(restored.weekStartDay, settings.weekStartDay);
    });
  });

  group('CSV export', () {
    test('escapes commas, quotes, newlines, and keeps UTF-8 BOM', () {
      final csv = DataExportService.csvForRows([
        ['note'],
        ['Cà phê, "quoted"\nnew line'],
      ]);

      expect(csv.startsWith('\ufeff'), isTrue);
      expect(csv, contains('"Cà phê, ""quoted""\nnew line"'));
    });
  });

  group('Restore', () {
    test('merges backup without deleting existing data', () async {
      final moneyBox = Hive.box<Transaction>(kMoneyBox);
      final categoryBox = Hive.box<CategoryModel>(kCatBox);
      final streakBox = Hive.box(kStreakBox);

      await categoryBox.add(
        CategoryModel(id: 'cat_existing', name: 'Existing', iconCode: 1),
      );
      await moneyBox.add(
        Transaction(
          id: 'tx_existing',
          note: 'Existing',
          amount: 100,
          date: DateTime.utc(2026, 6, 11),
          isExpense: true,
          categoryId: 'cat_existing',
        ),
      );
      await streakBox.put('existing_streak', true);

      final backupFile = await _createBackupFile(
        BackupPayload(
          transactions: [
            TransactionBackupDto(
              id: 'tx_existing',
              note: 'Duplicate',
              amount: 999,
              date: DateTime.utc(2026, 6, 12),
              isExpense: false,
              categoryId: 'cat_existing',
            ),
            TransactionBackupDto(
              id: 'tx_new',
              note: 'New',
              amount: 200,
              date: DateTime.utc(2026, 6, 12),
              isExpense: false,
              categoryId: 'cat_new',
            ),
          ],
          categories: [
            CategoryBackupDto(
              id: 'cat_existing',
              name: 'Duplicate category',
              iconCode: 2,
              isExpense: true,
            ),
            CategoryBackupDto(
              id: 'cat_new',
              name: 'New category',
              iconCode: 3,
              isExpense: false,
            ),
          ],
          settings: null,
          streaks: {'existing_streak': false, 'new_streak': true},
        ),
      );

      final summary = await DataRestoreService().restoreBackupFile(backupFile);

      expect(summary.categoriesAdded, 1);
      expect(summary.categoriesSkipped, 1);
      expect(summary.transactionsAdded, 1);
      expect(summary.transactionsSkipped, 1);
      expect(summary.streaksAdded, 1);
      expect(summary.streaksSkipped, 1);
      expect(categoryBox.length, 2);
      expect(moneyBox.length, 2);
      expect(streakBox.get('existing_streak'), isTrue);
      expect(streakBox.get('new_streak'), isTrue);
      expect(
        moneyBox.values.firstWhere((tx) => tx.id == 'tx_existing').amount,
        100,
      );
      expect(
        categoryBox.values.firstWhere((cat) => cat.id == 'cat_existing').name,
        'Existing',
      );
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    });

    test('backs up and restores category images', () async {
      final categoryBox = Hive.box<CategoryModel>(kCatBox);
      final imageBytes = [1, 2, 3, 4, 5];
      final imageRef = await CategoryImageStore.saveBytesFromBackup(
        'goal.jpg',
        imageBytes,
      );

      await categoryBox.add(
        CategoryModel(
          id: 'cat_goal',
          name: 'Goal',
          iconCode: 3,
          isExpense: false,
          typeIndex: 2,
          imagePath: imageRef,
        ),
      );

      final backupFile = await DataBackupService().createBackupFile();
      final backupArchive = ZipDecoder().decodeBytes(
        await backupFile.readAsBytes(),
      );
      final portableImageRef = imageRef.replaceAll('\\', '/');
      expect(backupArchive.find('images/$portableImageRef'), isNotNull);

      await categoryBox.clear();
      await CategoryImageStore.deleteAll();

      final summary = await DataRestoreService().restoreBackupFile(backupFile);

      expect(summary.categoriesAdded, 1);
      expect(summary.imagesRestored, 1);
      final restored = categoryBox.values.single;
      expect(
        restored.imagePath?.replaceAll('\\', '/'),
        startsWith('category_images/'),
      );
      final restoredFile = CategoryImageStore.resolve(restored.imagePath);
      expect(restoredFile, isNotNull);
      expect(await restoredFile!.readAsBytes(), imageBytes);

      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    });
  });
}

Future<void> _resetHiveBoxes() async {
  final moneyBox = await _openBox<Transaction>(kMoneyBox);
  final categoryBox = await _openBox<CategoryModel>(kCatBox);
  final settingsBox = await _openBox<AppSettings>(kSettingsBox);
  final streakBox = await _openBox(kStreakBox);

  await moneyBox.clear();
  await categoryBox.clear();
  await settingsBox.clear();
  await streakBox.clear();
  await CategoryImageStore.deleteAll();
}

Future<Box<T>> _openBox<T>(String name) async {
  if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
  return Hive.openBox<T>(name);
}

Future<File> _createBackupFile(BackupPayload payload) async {
  final archive = Archive()
    ..add(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode(BackupManifest.current().toJson()),
      ),
    )
    ..add(ArchiveFile.string('data.json', jsonEncode(payload.toJson())));

  final file = File(
    '${Directory.systemTemp.path}/sheepify_restore_${DateTime.now().microsecondsSinceEpoch}.sheepify-backup',
  );
  await file.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
  return file;
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String rootPath;

  _FakePathProviderPlatform(this.rootPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}
