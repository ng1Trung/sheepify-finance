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

  bool get hideAmounts => _hideAmounts ?? false;

  set hideAmounts(bool value) => _hideAmounts = value;

  String get themeMode => _themeMode ?? (isDarkMode ? 'dark' : 'light');

  set themeMode(String value) => _themeMode = value;

  AppSettings({
    this.accumulateBalance = true,
    this.themePresetName = 'Midnight Black',
    this.languageCode = 'vi',
    this.currencyCode = 'VND',
    this.fontFamily = 'Inter',
    this.isDarkMode = false,
    this.avatarImageRef,
    String themeMode = 'system',
    bool hideAmounts = false,
  }) : _themeMode = themeMode,
       _hideAmounts = hideAmounts;
}
