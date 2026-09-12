import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'playlist_model.g.dart';

@HiveType(typeId: 3)
class Playlist {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final List<String> bookIds;
  
  @HiveField(3)
  final DateTime createdAt;
  
  Playlist({
    String? id,
    required this.name,
    required this.bookIds,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bookIds': bookIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'],
      name: map['name'],
      bookIds: List<String>.from(map['bookIds']),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
  
  Playlist copyWith({
    String? id,
    String? name,
    List<String>? bookIds,
    DateTime? createdAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      bookIds: bookIds ?? this.bookIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
