// GENERATED FILE - DO NOT EDIT
// Run: flutter pub run build_runner build

import 'package:hive/hive.dart';

part 'book_model.g.dart';

@HiveType(typeId: 0)
class Book {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String? author;
  
  @HiveField(3)
  final String? filePath;

  @HiveField(4)
  final String? coverPath;

  @HiveField(5)
  final String fileType;

  @HiveField(6)
  final DateTime createdAt;
  
  @HiveField(7)
  final DateTime? lastRead;

  @HiveField(8)
  final List<int>? fileBytes;

  @HiveField(9)
  final int? chapterIndex;

  @HiveField(10)
  final int? position;
  
  Book({
    String? id,
    required this.title,
    this.author,
    this.filePath,
    this.coverPath,
    this.fileBytes,
    required this.fileType,
    DateTime? createdAt,
    this.lastRead,
    this.chapterIndex,
    this.position,
  }) : id = id ?? '',
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'coverPath': coverPath,
      'fileBytes': fileBytes,
      'fileType': fileType,
      'createdAt': createdAt.toIso8601String(),
      'lastRead': lastRead?.toIso8601String(),
      'chapterIndex': chapterIndex,
      'position': position,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      filePath: map['filePath'],
      coverPath: map['coverPath'],
      fileBytes: map['fileBytes'],
      fileType: map['fileType'],
      createdAt: DateTime.parse(map['createdAt']),
      lastRead: map['lastRead'] != null ? DateTime.parse(map['lastRead']) : null,
      chapterIndex: map['chapterIndex'],
      position: map['position'],
    );
  }
  
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? coverPath,
    List<int>? fileBytes,
    String? fileType,
    DateTime? createdAt,
    DateTime? lastRead,
    int? chapterIndex,
    int? position,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      fileBytes: fileBytes ?? this.fileBytes,
      fileType: fileType ?? this.fileType,
      createdAt: createdAt ?? this.createdAt,
      lastRead: lastRead ?? this.lastRead,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      position: position ?? this.position,
    );
  }
}

@HiveType(typeId: 1)
class ReadingState {
  @HiveField(0)
  final String bookId;
  
  @HiveField(1)
  final int chapterIndex;
  
  @HiveField(2)
  final int position;
  
  @HiveField(3)
  final DateTime timestamp;

  ReadingState({
    required this.bookId,
    required this.chapterIndex,
    required this.position,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'position': position,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ReadingState.fromMap(Map<String, dynamic> map) {
    return ReadingState(
      bookId: map['bookId'],
      chapterIndex: map['chapterIndex'],
      position: map['position'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
