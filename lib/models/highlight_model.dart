import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'highlight_model.g.dart';

@HiveType(typeId: 2)
class Highlight {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String bookId;
  
  @HiveField(2)
  final String text;
  
  @HiveField(3)
  final String? note;
  
  @HiveField(4)
  final int chapterIndex;
  
  @HiveField(5)
  final int positionStart;
  
  @HiveField(6)
  final int positionEnd;
  
  @HiveField(7)
  final DateTime createdAt;
  
  Highlight({
    String? id,
    required this.bookId,
    required this.text,
    this.note,
    required this.chapterIndex,
    required this.positionStart,
    required this.positionEnd,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'text': text,
      'note': note,
      'chapterIndex': chapterIndex,
      'positionStart': positionStart,
      'positionEnd': positionEnd,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id: map['id'],
      bookId: map['bookId'],
      text: map['text'],
      note: map['note'],
      chapterIndex: map['chapterIndex'],
      positionStart: map['positionStart'],
      positionEnd: map['positionEnd'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Highlight copyWith({
    String? note,
  }) {
    return Highlight(
      id: id,
      bookId: bookId,
      text: text,
      note: note ?? this.note,
      chapterIndex: chapterIndex,
      positionStart: positionStart,
      positionEnd: positionEnd,
      createdAt: createdAt,
    );
  }
}
