// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryModelAdapter extends TypeAdapter<CategoryModel> {
  @override
  final int typeId = 2;

  @override
  CategoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      iconCode: fields[2] as int,
      isExpense: fields[3] as bool,
      budget: fields[4] as double?,
      colorValue: fields[5] as int?,
      typeIndex: fields[6] as int?,
      targetAmount: fields[7] as double?,
      targetDate: fields[8] as DateTime?,
      goalTypeIndex: fields[10] as int?,
      reminderDay: fields[11] as int?,
      targetYear: fields[12] as int?,
      targetMonth: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconCode)
      ..writeByte(3)
      ..write(obj.isExpense)
      ..writeByte(4)
      ..write(obj.budget)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.typeIndex)
      ..writeByte(7)
      ..write(obj.targetAmount)
      ..writeByte(8)
      ..write(obj.targetDate)
      ..writeByte(10)
      ..write(obj.goalTypeIndex)
      ..writeByte(11)
      ..write(obj.reminderDay)
      ..writeByte(12)
      ..write(obj.targetYear)
      ..writeByte(13)
      ..write(obj.targetMonth);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
