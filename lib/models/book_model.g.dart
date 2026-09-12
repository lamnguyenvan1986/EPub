// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 0;

  @override
  Book read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Book(
      id: fields[0] as String?,
      title: fields[1] as String,
      author: fields[2] as String?,
      filePath: fields[3] as String?,
      coverPath: fields[4] as String?,
      fileBytes: (fields[8] as List?)?.cast<int>(),
      fileType: fields[5] as String,
      createdAt: fields[6] as DateTime?,
      lastRead: fields[7] as DateTime?,
      chapterIndex: fields[9] as int?,
      position: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.filePath)
      ..writeByte(4)
      ..write(obj.coverPath)
      ..writeByte(5)
      ..write(obj.fileType)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastRead)
      ..writeByte(8)
      ..write(obj.fileBytes)
      ..writeByte(9)
      ..write(obj.chapterIndex)
      ..writeByte(10)
      ..write(obj.position);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadingStateAdapter extends TypeAdapter<ReadingState> {
  @override
  final int typeId = 1;

  @override
  ReadingState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingState(
      bookId: fields[0] as String,
      chapterIndex: fields[1] as int,
      position: fields[2] as int,
      timestamp: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingState obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.bookId)
      ..writeByte(1)
      ..write(obj.chapterIndex)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
