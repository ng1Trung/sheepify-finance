import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 3)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool accumulateBalance;

  @HiveField(1)
  String themePresetName; // Will be used for activePaletteName

  @HiveField(2)
  String languageCode;

  @HiveField(3)
  String currencyCode;

  @HiveField(4)
  String fontFamily;

  @HiveField(5)
  bool isDarkMode;

  @HiveField(6)
  bool? _hideAmounts;

  @HiveField(7)
  String? _themeMode;

  @HiveField(8)
  String? avatarImageRef;

  @HiveField(9)
  int financialCycleStartDay;

  @HiveField(10)
  int? _weekStartDay;

  bool get hideAmounts => _hideAmounts ?? false;

  set hideAmounts(bool value) => _hideAmounts = value;

  String get themeMode => _themeMode ?? (isDarkMode ? 'dark' : 'light');

  set themeMode(String value) => _themeMode = value;

  int get weekStartDay => _weekStartDay ?? DateTime.monday;

  set weekStartDay(int value) => _weekStartDay = value;

  AppSettings({
    this.accumulateBalance = true,
    this.themePresetName = 'Midnight Black',
    this.languageCode = 'vi',
    this.currencyCode = 'VND',
    this.fontFamily = 'Inter',
    this.isDarkMode = false,
    this.avatarImageRef,
    this.financialCycleStartDay = 1,
    String themeMode = 'system',
    bool hideAmounts = false,
    int weekStartDay = DateTime.monday,
  }) : _themeMode = themeMode,
       _hideAmounts = hideAmounts,
       _weekStartDay = weekStartDay;
}
