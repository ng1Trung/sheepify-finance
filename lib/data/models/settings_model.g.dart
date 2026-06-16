// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 3;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      accumulateBalance: fields[0] as bool,
      themePresetName: fields[1] as String,
      languageCode: fields[2] as String,
      currencyCode: fields[3] as String,
      fontFamily: fields[4] as String,
      isDarkMode: fields[5] as bool,
      avatarImageRef: fields[8] as String?,
      lastBackupAt: fields[11] as DateTime?,
    )
      .._hideAmounts = fields[6] as bool?
      .._themeMode = fields[7] as String?
      .._financialCycleStartDay = fields[9] as int?
      .._weekStartDay = fields[10] as int?;
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.accumulateBalance)
      ..writeByte(1)
      ..write(obj.themePresetName)
      ..writeByte(2)
      ..write(obj.languageCode)
      ..writeByte(3)
      ..write(obj.currencyCode)
      ..writeByte(4)
      ..write(obj.fontFamily)
      ..writeByte(5)
      ..write(obj.isDarkMode)
      ..writeByte(6)
      ..write(obj._hideAmounts)
      ..writeByte(7)
      ..write(obj._themeMode)
      ..writeByte(8)
      ..write(obj.avatarImageRef)
      ..writeByte(9)
      ..write(obj._financialCycleStartDay)
      ..writeByte(10)
      ..write(obj._weekStartDay)
      ..writeByte(11)
      ..write(obj.lastBackupAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
