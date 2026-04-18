import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 3)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool accumulateBalance;

  @HiveField(1)
  String themePresetName;

  @HiveField(2)
  String languageCode;

  @HiveField(3)
  String currencyCode;

  @HiveField(4)
  String fontFamily;

  AppSettings({
    this.accumulateBalance = true,
    this.themePresetName = 'Sheep Light',
    this.languageCode = 'vi',
    this.currencyCode = 'VND',
    this.fontFamily = 'Quicksand',
  });
}
