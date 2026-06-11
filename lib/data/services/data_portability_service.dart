import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../../core/constants/constants.dart';
import '../../core/utils/avatar_image_store.dart';
import '../../core/utils/category_image_store.dart';
import '../../core/utils/transaction_image_store.dart';
import '../models/category_model.dart';
import '../models/settings_model.dart';
import '../models/transaction.dart';

const int kBackupSchemaVersion = 2;
const String kBackupAppVersion = '1.0.0+1';

class BackupManifest {
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;

  const BackupManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
  });

  factory BackupManifest.current() {
    return BackupManifest(
      schemaVersion: kBackupSchemaVersion,
      appVersion: kBackupAppVersion,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      schemaVersion: _asInt(json['schemaVersion']) ?? 0,
      appVersion: json['appVersion']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class BackupPayload {
  final List<TransactionBackupDto> transactions;
  final List<CategoryBackupDto> categories;
  final SettingsBackupDto? settings;
  final Map<String, dynamic> streaks;

  const BackupPayload({
    required this.transactions,
    required this.categories,
    required this.settings,
    required this.streaks,
  });

  factory BackupPayload.fromCurrentData() {
    final settingsBox = Hive.box<AppSettings>(kSettingsBox);
    final streakBox = Hive.box(kStreakBox);

    return BackupPayload(
      transactions: Hive.box<Transaction>(
        kMoneyBox,
      ).values.map(TransactionBackupDto.fromModel).toList(),
      categories: Hive.box<CategoryModel>(
        kCatBox,
      ).values.map(CategoryBackupDto.fromModel).toList(),
      settings: SettingsBackupDto.fromModel(settingsBox.get('current')),
      streaks: {
        for (final key in streakBox.keys) key.toString(): streakBox.get(key),
      },
    );
  }

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'] as List<dynamic>? ?? const [];
    final rawCategories = json['categories'] as List<dynamic>? ?? const [];
    final rawSettings = json['settings'];
    final rawStreaks = json['streaks'];

    return BackupPayload(
      transactions: rawTransactions
          .whereType<Map>()
          .map((item) => TransactionBackupDto.fromJson(_stringKeyMap(item)))
          .toList(),
      categories: rawCategories
          .whereType<Map>()
          .map((item) => CategoryBackupDto.fromJson(_stringKeyMap(item)))
          .toList(),
      settings: rawSettings is Map
          ? SettingsBackupDto.fromJson(_stringKeyMap(rawSettings))
          : null,
      streaks: rawStreaks is Map ? _stringKeyMap(rawStreaks) : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactions': transactions.map((dto) => dto.toJson()).toList(),
      'categories': categories.map((dto) => dto.toJson()).toList(),
      'settings': settings?.toJson(),
      'streaks': streaks,
    };
  }
}

class TransactionBackupDto {
  final String id;
  final String note;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final String categoryId;
  final String? imagePath;

  const TransactionBackupDto({
    required this.id,
    required this.note,
    required this.amount,
    required this.date,
    required this.isExpense,
    required this.categoryId,
    this.imagePath,
  });

  factory TransactionBackupDto.fromModel(Transaction tx) {
    return TransactionBackupDto(
      id: tx.id,
      note: tx.note,
      amount: tx.amount,
      date: tx.date,
      isExpense: tx.isExpense,
      categoryId: tx.categoryId,
      imagePath: tx.imagePath,
    );
  }

  factory TransactionBackupDto.fromJson(Map<String, dynamic> json) {
    return TransactionBackupDto(
      id: json['id']?.toString() ?? Transaction.createId(),
      note: json['note']?.toString() ?? '',
      amount: _asDouble(json['amount']) ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      isExpense: _asBool(json['isExpense']) ?? true,
      categoryId: json['categoryId']?.toString() ?? '',
      imagePath: _nullableString(json['imagePath']),
    );
  }

  Transaction toModel({String? restoredImagePath}) {
    return Transaction(
      id: id,
      note: note,
      amount: amount,
      date: date,
      isExpense: isExpense,
      categoryId: categoryId,
      imagePath: restoredImagePath ?? imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note': note,
      'amount': amount,
      'date': date.toIso8601String(),
      'isExpense': isExpense,
      'categoryId': categoryId,
      'imagePath': imagePath,
    };
  }
}

class CategoryBackupDto {
  final String id;
  final String name;
  final int iconCode;
  final bool isExpense;
  final double? budget;
  final int? colorValue;
  final int? typeIndex;
  final double? targetAmount;
  final DateTime? targetDate;
  final int? goalTypeIndex;
  final int? reminderDay;
  final int? targetYear;
  final int? targetMonth;
  final String? imagePath;

  const CategoryBackupDto({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.isExpense,
    this.budget,
    this.colorValue,
    this.typeIndex,
    this.targetAmount,
    this.targetDate,
    this.goalTypeIndex,
    this.reminderDay,
    this.targetYear,
    this.targetMonth,
    this.imagePath,
  });

  factory CategoryBackupDto.fromModel(CategoryModel category) {
    return CategoryBackupDto(
      id: category.id,
      name: category.name,
      iconCode: category.iconCode,
      isExpense: category.isExpense,
      budget: category.budget,
      colorValue: category.colorValue,
      typeIndex: category.typeIndex,
      targetAmount: category.targetAmount,
      targetDate: category.targetDate,
      goalTypeIndex: category.goalTypeIndex,
      reminderDay: category.reminderDay,
      targetYear: category.targetYear,
      targetMonth: category.targetMonth,
      imagePath: category.imagePath,
    );
  }

  factory CategoryBackupDto.fromJson(Map<String, dynamic> json) {
    return CategoryBackupDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      iconCode: _asInt(json['iconCode']) ?? 0,
      isExpense: _asBool(json['isExpense']) ?? true,
      budget: _asDouble(json['budget']),
      colorValue: _asInt(json['colorValue']),
      typeIndex: _asInt(json['typeIndex']),
      targetAmount: _asDouble(json['targetAmount']),
      targetDate: _asDate(json['targetDate']),
      goalTypeIndex: _asInt(json['goalTypeIndex']),
      reminderDay: _asInt(json['reminderDay']),
      targetYear: _asInt(json['targetYear']),
      targetMonth: _asInt(json['targetMonth']),
      imagePath: _nullableString(json['imagePath']),
    );
  }

  CategoryModel toModel({String? restoredImagePath}) {
    return CategoryModel(
      id: id,
      name: name,
      iconCode: iconCode,
      isExpense: isExpense,
      budget: budget,
      colorValue: colorValue,
      typeIndex: typeIndex,
      targetAmount: targetAmount,
      targetDate: targetDate,
      goalTypeIndex: goalTypeIndex,
      reminderDay: reminderDay,
      targetYear: targetYear,
      targetMonth: targetMonth,
      imagePath: restoredImagePath ?? imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'isExpense': isExpense,
      'budget': budget,
      'colorValue': colorValue,
      'typeIndex': typeIndex,
      'targetAmount': targetAmount,
      'targetDate': targetDate?.toIso8601String(),
      'goalTypeIndex': goalTypeIndex,
      'reminderDay': reminderDay,
      'targetYear': targetYear,
      'targetMonth': targetMonth,
      'imagePath': imagePath,
    };
  }
}

class SettingsBackupDto {
  final bool accumulateBalance;
  final String themePresetName;
  final String languageCode;
  final String currencyCode;
  final String fontFamily;
  final bool isDarkMode;
  final bool hideAmounts;
  final String themeMode;
  final String? avatarImageRef;
  final int financialCycleStartDay;
  final int weekStartDay;

  const SettingsBackupDto({
    required this.accumulateBalance,
    required this.themePresetName,
    required this.languageCode,
    required this.currencyCode,
    required this.fontFamily,
    required this.isDarkMode,
    required this.hideAmounts,
    required this.themeMode,
    required this.avatarImageRef,
    required this.financialCycleStartDay,
    required this.weekStartDay,
  });

  factory SettingsBackupDto.fromModel(AppSettings? settings) {
    final value = settings ?? AppSettings();
    return SettingsBackupDto(
      accumulateBalance: value.accumulateBalance,
      themePresetName: value.themePresetName,
      languageCode: value.languageCode,
      currencyCode: value.currencyCode,
      fontFamily: value.fontFamily,
      isDarkMode: value.isDarkMode,
      hideAmounts: value.hideAmounts,
      themeMode: value.themeMode,
      avatarImageRef: value.avatarImageRef,
      financialCycleStartDay: value.financialCycleStartDay,
      weekStartDay: value.weekStartDay,
    );
  }

  factory SettingsBackupDto.fromJson(Map<String, dynamic> json) {
    return SettingsBackupDto(
      accumulateBalance: _asBool(json['accumulateBalance']) ?? true,
      themePresetName: json['themePresetName']?.toString() ?? 'Midnight Black',
      languageCode: json['languageCode']?.toString() ?? 'vi',
      currencyCode: json['currencyCode']?.toString() ?? 'VND',
      fontFamily: json['fontFamily']?.toString() ?? 'Inter',
      isDarkMode: _asBool(json['isDarkMode']) ?? false,
      hideAmounts: _asBool(json['hideAmounts']) ?? false,
      themeMode: json['themeMode']?.toString() ?? 'system',
      avatarImageRef: _nullableString(json['avatarImageRef']),
      financialCycleStartDay: _asInt(json['financialCycleStartDay']) ?? 1,
      weekStartDay: _asInt(json['weekStartDay']) ?? DateTime.monday,
    );
  }

  AppSettings toModel({String? restoredAvatarRef}) {
    return AppSettings(
      accumulateBalance: accumulateBalance,
      themePresetName: themePresetName,
      languageCode: languageCode,
      currencyCode: currencyCode,
      fontFamily: fontFamily,
      isDarkMode: isDarkMode,
      avatarImageRef: restoredAvatarRef ?? avatarImageRef,
      financialCycleStartDay: financialCycleStartDay,
      themeMode: themeMode,
      hideAmounts: hideAmounts,
      weekStartDay: weekStartDay,
    );
  }

  void applyTo(AppSettings settings, {String? restoredAvatarRef}) {
    settings.accumulateBalance = accumulateBalance;
    settings.themePresetName = themePresetName;
    settings.languageCode = languageCode;
    settings.currencyCode = currencyCode;
    settings.fontFamily = fontFamily;
    settings.isDarkMode = isDarkMode;
    settings.hideAmounts = hideAmounts;
    settings.themeMode = themeMode;
    settings.avatarImageRef = restoredAvatarRef ?? avatarImageRef;
    settings.financialCycleStartDay = financialCycleStartDay;
    settings.weekStartDay = weekStartDay;
  }

  Map<String, dynamic> toJson() {
    return {
      'accumulateBalance': accumulateBalance,
      'themePresetName': themePresetName,
      'languageCode': languageCode,
      'currencyCode': currencyCode,
      'fontFamily': fontFamily,
      'isDarkMode': isDarkMode,
      'hideAmounts': hideAmounts,
      'themeMode': themeMode,
      'avatarImageRef': avatarImageRef,
      'financialCycleStartDay': financialCycleStartDay,
      'weekStartDay': weekStartDay,
    };
  }
}

class RestoreSummary {
  final int categoriesAdded;
  final int categoriesSkipped;
  final int transactionsAdded;
  final int transactionsSkipped;
  final int streaksAdded;
  final int streaksSkipped;
  final int imagesRestored;
  final bool settingsRestored;

  const RestoreSummary({
    required this.categoriesAdded,
    required this.categoriesSkipped,
    required this.transactionsAdded,
    required this.transactionsSkipped,
    required this.streaksAdded,
    required this.streaksSkipped,
    required this.imagesRestored,
    required this.settingsRestored,
  });
}

class DataBackupService {
  Future<File> createBackupFile() async {
    final payload = BackupPayload.fromCurrentData();
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'manifest.json',
          const JsonEncoder.withIndent(
            '  ',
          ).convert(BackupManifest.current().toJson()),
        ),
      )
      ..add(
        ArchiveFile.string(
          'data.json',
          const JsonEncoder.withIndent('  ').convert(payload.toJson()),
        ),
      );

    await _addImages(archive, payload);

    final file = await _createOutputFile(
      prefix: 'sheepify_backup',
      extension: 'sheepify-backup',
    );
    final bytes = ZipEncoder().encodeBytes(archive);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _addImages(Archive archive, BackupPayload payload) async {
    final addedPaths = <String>{};

    final avatarRef = payload.settings?.avatarImageRef;
    await _addImageRef(
      archive: archive,
      addedPaths: addedPaths,
      storedRef: avatarRef,
      fallbackDirectory: 'avatar_images',
      resolve: AvatarImageStore.resolve,
    );

    for (final category in payload.categories) {
      await _addImageRef(
        archive: archive,
        addedPaths: addedPaths,
        storedRef: category.imagePath,
        fallbackDirectory: CategoryImageStore.directoryName,
        resolve: CategoryImageStore.resolve,
      );
    }

    for (final tx in payload.transactions) {
      await _addImageRef(
        archive: archive,
        addedPaths: addedPaths,
        storedRef: tx.imagePath,
        fallbackDirectory: 'transaction_images',
        resolve: TransactionImageStore.resolve,
      );
    }
  }

  Future<void> _addImageRef({
    required Archive archive,
    required Set<String> addedPaths,
    required String? storedRef,
    required String fallbackDirectory,
    required File? Function(String? storedRef) resolve,
  }) async {
    if (storedRef == null || storedRef.isEmpty) return;

    final file = resolve(storedRef);
    if (file == null || !await file.exists()) return;

    final archivePath = _archiveImagePath(storedRef, fallbackDirectory);
    if (!addedPaths.add(archivePath)) return;

    archive.add(ArchiveFile.bytes(archivePath, await file.readAsBytes()));
  }
}

class DataRestoreService {
  Future<RestoreSummary> restoreBackupFile(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final manifestEntry = archive.find('manifest.json');
    final dataEntry = archive.find('data.json');
    if (manifestEntry == null || dataEntry == null) {
      throw const FormatException('Invalid Sheepify backup file.');
    }

    final manifest = BackupManifest.fromJson(
      jsonDecode(utf8.decode(manifestEntry.content)) as Map<String, dynamic>,
    );
    if (manifest.schemaVersion > kBackupSchemaVersion) {
      throw UnsupportedError(
        'Backup schema ${manifest.schemaVersion} is newer than this app supports.',
      );
    }

    final payload = BackupPayload.fromJson(
      jsonDecode(utf8.decode(dataEntry.content)) as Map<String, dynamic>,
    );
    final archiveImages = {
      for (final entry in archive.where((entry) => entry.isFile))
        _normalizeArchiveName(entry.name): entry,
    };

    var imagesRestored = 0;
    final categoryResult = await _restoreCategories(
      payload,
      archiveImages,
      onImageRestored: () => imagesRestored++,
    );
    final settingsRestored = await _restoreSettings(
      payload,
      archiveImages,
      onImageRestored: () => imagesRestored++,
    );
    final streakResult = await _restoreStreaks(payload);
    final transactionResult = await _restoreTransactions(
      payload,
      archiveImages,
      onImageRestored: () => imagesRestored++,
    );

    return RestoreSummary(
      categoriesAdded: categoryResult.added,
      categoriesSkipped: categoryResult.skipped,
      transactionsAdded: transactionResult.added,
      transactionsSkipped: transactionResult.skipped,
      streaksAdded: streakResult.added,
      streaksSkipped: streakResult.skipped,
      imagesRestored: imagesRestored,
      settingsRestored: settingsRestored,
    );
  }

  Future<_MergeResult> _restoreCategories(
    BackupPayload payload,
    Map<String, ArchiveFile> archiveImages, {
    required VoidCallback onImageRestored,
  }) async {
    final box = Hive.box<CategoryModel>(kCatBox);
    final existingIds = box.values.map((category) => category.id).toSet();
    var added = 0;
    var skipped = 0;

    for (final category in payload.categories) {
      if (category.id.isEmpty || existingIds.contains(category.id)) {
        skipped++;
        continue;
      }

      final imagePath = await _restoreCategoryImage(
        category.imagePath,
        archiveImages,
        onImageRestored: onImageRestored,
      );
      await box.add(category.toModel(restoredImagePath: imagePath));
      existingIds.add(category.id);
      added++;
    }

    return _MergeResult(added: added, skipped: skipped);
  }

  Future<_MergeResult> _restoreTransactions(
    BackupPayload payload,
    Map<String, ArchiveFile> archiveImages, {
    required VoidCallback onImageRestored,
  }) async {
    final box = Hive.box<Transaction>(kMoneyBox);
    final existingIds = box.values.map((tx) => tx.id).toSet();
    var added = 0;
    var skipped = 0;

    for (final tx in payload.transactions) {
      if (tx.id.isEmpty || existingIds.contains(tx.id)) {
        skipped++;
        continue;
      }

      final imagePath = await _restoreTransactionImage(
        tx.imagePath,
        archiveImages,
        onImageRestored: onImageRestored,
      );
      await box.add(tx.toModel(restoredImagePath: imagePath));
      existingIds.add(tx.id);
      added++;
    }

    return _MergeResult(added: added, skipped: skipped);
  }

  Future<bool> _restoreSettings(
    BackupPayload payload,
    Map<String, ArchiveFile> archiveImages, {
    required VoidCallback onImageRestored,
  }) async {
    final settings = payload.settings;
    if (settings == null) return false;

    final avatarRef = await _restoreAvatarImage(
      settings.avatarImageRef,
      archiveImages,
      onImageRestored: onImageRestored,
    );
    final settingsBox = Hive.box<AppSettings>(kSettingsBox);
    final current = settingsBox.get('current');

    if (current == null) {
      await settingsBox.put(
        'current',
        settings.toModel(restoredAvatarRef: avatarRef),
      );
    } else {
      settings.applyTo(current, restoredAvatarRef: avatarRef);
      await current.save();
    }

    return true;
  }

  Future<_MergeResult> _restoreStreaks(BackupPayload payload) async {
    final box = Hive.box(kStreakBox);
    var added = 0;
    var skipped = 0;

    for (final entry in payload.streaks.entries) {
      if (box.containsKey(entry.key)) {
        skipped++;
        continue;
      }
      await box.put(entry.key, entry.value);
      added++;
    }

    return _MergeResult(added: added, skipped: skipped);
  }

  Future<String?> _restoreTransactionImage(
    String? storedRef,
    Map<String, ArchiveFile> archiveImages, {
    required VoidCallback onImageRestored,
  }) async {
    if (storedRef == null || storedRef.isEmpty) return storedRef;

    final imageEntry =
        archiveImages[_archiveImagePath(storedRef, 'transaction_images')];
    final bytes = imageEntry?.content;
    if (bytes == null || bytes.isEmpty) return storedRef;

    final restoredRef = await TransactionImageStore.saveBytesFromBackup(
      _basenameFromStoredRef(storedRef),
      bytes,
    );
    onImageRestored();
    return restoredRef;
  }

  Future<String?> _restoreCategoryImage(
    String? storedRef,
    Map<String, ArchiveFile> archiveImages, {
    required VoidCallback onImageRestored,
  }) async {
    if (storedRef == null || storedRef.isEmpty) return storedRef;

    final imageEntry =
        archiveImages[_archiveImagePath(storedRef, CategoryImageStore.directoryName)];
    final bytes = imageEntry?.content;
    if (bytes == null || bytes.isEmpty) return storedRef;

    final restoredRef = await CategoryImageStore.saveBytesFromBackup(
      _basenameFromStoredRef(storedRef),
      bytes,
    );
    onImageRestored();
    return restoredRef;
  }

  Future<String?> _restoreAvatarImage(
    String? storedRef,
    Map<String, ArchiveFile> archiveImages, {
    required VoidCallback onImageRestored,
  }) async {
    if (storedRef == null || storedRef.isEmpty) return storedRef;

    final imageEntry =
        archiveImages[_archiveImagePath(storedRef, 'avatar_images')];
    final bytes = imageEntry?.content;
    if (bytes == null || bytes.isEmpty) return storedRef;

    final restoredRef = await AvatarImageStore.saveBytesFromBackup(
      _basenameFromStoredRef(storedRef),
      bytes,
    );
    onImageRestored();
    return restoredRef;
  }
}

class DataExportService {
  Future<File> exportCsvArchive() async {
    final payload = BackupPayload.fromCurrentData();
    final archive = Archive()
      ..add(
        ArchiveFile.string('transactions.csv', _csv(_transactionRows(payload))),
      )
      ..add(ArchiveFile.string('categories.csv', _csv(_categoryRows(payload))))
      ..add(ArchiveFile.string('settings.csv', _csv(_settingsRows(payload))))
      ..add(ArchiveFile.string('streaks.csv', _csv(_streakRows(payload))));

    final file = await _createOutputFile(
      prefix: 'sheepify_csv_export',
      extension: 'zip',
    );
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return file;
  }

  Future<File> exportExcelWorkbook() async {
    final payload = BackupPayload.fromCurrentData();
    final workbook = xlsio.Workbook(4);
    try {
      _writeSheet(
        workbook.worksheets[0],
        'Transactions',
        _transactionRows(payload),
      );
      _writeSheet(workbook.worksheets[1], 'Categories', _categoryRows(payload));
      _writeSheet(workbook.worksheets[2], 'Settings', _settingsRows(payload));
      _writeSheet(workbook.worksheets[3], 'Streaks', _streakRows(payload));

      final bytes = workbook.saveAsStream();
      final file = await _createOutputFile(
        prefix: 'sheepify_excel_export',
        extension: 'xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } finally {
      workbook.dispose();
    }
  }

  static List<List<dynamic>> transactionRowsForPayload(BackupPayload payload) {
    return _transactionRows(payload);
  }

  static List<List<dynamic>> categoryRowsForPayload(BackupPayload payload) {
    return _categoryRows(payload);
  }

  static List<List<dynamic>> settingsRowsForPayload(BackupPayload payload) {
    return _settingsRows(payload);
  }

  static String csvForRows(List<List<dynamic>> rows) {
    return _csv(rows);
  }

  static List<List<dynamic>> _transactionRows(BackupPayload payload) {
    final categoriesById = {
      for (final category in payload.categories) category.id: category,
    };
    return [
      [
        'id',
        'date',
        'type',
        'amount',
        'note',
        'category_id',
        'category_name',
        'image_ref',
      ],
      for (final tx in payload.transactions)
        [
          tx.id,
          tx.date.toIso8601String(),
          tx.isExpense ? 'expense' : 'income',
          tx.amount,
          tx.note,
          tx.categoryId,
          categoriesById[tx.categoryId]?.name ?? '',
          tx.imagePath ?? '',
        ],
    ];
  }

  static List<List<dynamic>> _categoryRows(BackupPayload payload) {
    return [
      [
        'id',
        'name',
        'type',
        'icon_code',
        'is_expense',
        'budget',
        'color_value',
        'target_amount',
        'target_date',
        'goal_type_index',
        'reminder_day',
        'target_year',
        'target_month',
        'image_path',
      ],
      for (final category in payload.categories)
        [
          category.id,
          category.name,
          _categoryTypeLabel(category.typeIndex, category.isExpense),
          category.iconCode,
          category.isExpense,
          category.budget ?? '',
          category.colorValue ?? '',
          category.targetAmount ?? '',
          category.targetDate?.toIso8601String() ?? '',
          category.goalTypeIndex ?? '',
          category.reminderDay ?? '',
          category.targetYear ?? '',
          category.targetMonth ?? '',
          category.imagePath ?? '',
        ],
    ];
  }

  static List<List<dynamic>> _settingsRows(BackupPayload payload) {
    final settings = payload.settings;
    return [
      ['key', 'value'],
      if (settings != null) ...[
        ['accumulate_balance', settings.accumulateBalance],
        ['theme_preset_name', settings.themePresetName],
        ['language_code', settings.languageCode],
        ['currency_code', settings.currencyCode],
        ['font_family', settings.fontFamily],
        ['is_dark_mode', settings.isDarkMode],
        ['hide_amounts', settings.hideAmounts],
        ['theme_mode', settings.themeMode],
        ['avatar_image_ref', settings.avatarImageRef ?? ''],
        ['financial_cycle_start_day', settings.financialCycleStartDay],
        ['week_start_day', settings.weekStartDay],
      ],
    ];
  }

  static List<List<dynamic>> _streakRows(BackupPayload payload) {
    return [
      ['key', 'value'],
      for (final entry in payload.streaks.entries) [entry.key, entry.value],
    ];
  }

  static String _csv(List<List<dynamic>> rows) {
    return const CsvEncoder(addBom: true).convert(rows);
  }

  void _writeSheet(
    xlsio.Worksheet sheet,
    String name,
    List<List<dynamic>> rows,
  ) {
    sheet.name = name;

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final cell = sheet.getRangeByIndex(rowIndex + 1, columnIndex + 1);
        final value = row[columnIndex];
        if (value is num) {
          cell.setNumber(value.toDouble());
        } else if (value is bool) {
          cell.setText(value ? 'true' : 'false');
        } else {
          cell.setText(value?.toString() ?? '');
        }
      }
    }

    if (rows.isEmpty) return;
    final header = sheet.getRangeByIndex(1, 1, 1, rows.first.length);
    header.cellStyle.bold = true;
    for (var column = 1; column <= rows.first.length; column++) {
      sheet.autoFitColumn(column);
    }
  }
}

class _MergeResult {
  final int added;
  final int skipped;

  const _MergeResult({required this.added, required this.skipped});
}

typedef VoidCallback = void Function();

Future<File> _createOutputFile({
  required String prefix,
  required String extension,
}) async {
  final directory = await getTemporaryDirectory();
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  return File(path.join(directory.path, '${prefix}_$timestamp.$extension'));
}

String _archiveImagePath(String storedRef, String fallbackDirectory) {
  return _normalizeArchiveName(
    path.posix.join('images', _portableImageRef(storedRef, fallbackDirectory)),
  );
}

String _portableImageRef(String storedRef, String fallbackDirectory) {
  final normalized = storedRef.replaceAll('\\', '/');
  final looksAbsolute =
      normalized.startsWith('/') || RegExp(r'^[a-zA-Z]:/').hasMatch(normalized);
  if (looksAbsolute) {
    return path.posix.join(
      fallbackDirectory,
      _basenameFromStoredRef(storedRef),
    );
  }

  final parts = normalized
      .split('/')
      .where((part) => part.isNotEmpty && part != '.' && part != '..')
      .toList();
  if (parts.isEmpty) {
    return path.posix.join(
      fallbackDirectory,
      _basenameFromStoredRef(storedRef),
    );
  }
  return path.posix.joinAll(parts);
}

String _basenameFromStoredRef(String storedRef) {
  final normalized = storedRef.replaceAll('\\', '/');
  final basename = path.posix.basename(normalized);
  return basename.isEmpty
      ? '${DateTime.now().microsecondsSinceEpoch}.jpg'
      : basename;
}

String _normalizeArchiveName(String name) {
  return name.replaceAll('\\', '/');
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> raw) {
  return {for (final entry in raw.entries) entry.key.toString(): entry.value};
}

String? _nullableString(Object? value) {
  final string = value?.toString();
  if (string == null || string.isEmpty) return null;
  return string;
}

DateTime? _asDate(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _asBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

String _categoryTypeLabel(int? typeIndex, bool isExpense) {
  switch (typeIndex ?? (isExpense ? 0 : 1)) {
    case 1:
      return 'income';
    case 2:
      return 'savings';
    default:
      return 'expense';
  }
}
