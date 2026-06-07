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
      accumulateBalance: fields[0] as bool? ?? true,
      themePresetName: fields[1] as String? ?? 'Sheep Green',
      languageCode: fields[2] as String? ?? 'vi',
      currencyCode: fields[3] as String? ?? 'VND',
      fontFamily: fields[4] as String? ?? 'Quicksand',
      isDarkMode: fields[5] as bool? ?? false,
      hideAmounts: fields[6] as bool? ?? false,
      themeMode:
          fields[7] as String? ??
          ((fields[5] as bool? ?? false) ? 'dark' : 'light'),
      avatarImageRef: fields[8] as String?,
      financialCycleStartDay: fields[9] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.financialCycleStartDay);
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
