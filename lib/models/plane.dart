import 'package:hive/hive.dart';

part 'plane.g.dart';

@HiveType(typeId: 2)
enum PlaneStatus {
  @HiveField(0)
  identifying,
  @HiveField(1)
  finalized,
}

@HiveType(typeId: 3)
class PlaneGuess extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String description;

  @HiveField(2)
  final double confidence;

  PlaneGuess({
    required this.name,
    required this.description,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'confidence': confidence,
  };

  static PlaneGuess fromJson(Map<String, dynamic> json) => PlaneGuess(
    name: json['name'] as String,
    description: json['description'] as String,
    confidence: (json['confidence'] as num).toDouble(),
  );
}

@HiveType(typeId: 0)
class Plane extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final double? latitude;

  @HiveField(4)
  final double? longitude;

  @HiveField(5)
  String identification;

  @HiveField(6)
  String description;

  @HiveField(7)
  String activity;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  List<ChatMessage> chatHistory;

  @HiveField(10, defaultValue: PlaneStatus.finalized)
  PlaneStatus status;

  @HiveField(11, defaultValue: [])
  List<PlaneGuess> guesses;

  @HiveField(12, defaultValue: '')
  String identificationTips;

  @HiveField(13, defaultValue: 'planes')
  String categoryId;

  /// Last local or remote modification, used for last-write-wins sync
  /// merging. Null on records created before cloud sync existed.
  @HiveField(14)
  DateTime? updatedAt;

  /// Firebase Storage download URL for the photo, set once uploaded.
  @HiveField(15)
  String? imageUrl;

  Plane({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.identification = 'Unknown',
    this.description = '',
    this.activity = '',
    this.tags = const [],
    this.chatHistory = const [],
    this.status = PlaneStatus
        .finalized, // Default to finalized for backward compatibility
    this.guesses = const [],
    this.identificationTips = '',
    this.categoryId = 'planes',
    this.updatedAt,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'identification': identification,
    'description': description,
    'activity': activity,
    'tags': tags,
    'chatHistory': chatHistory.map((m) => m.toJson()).toList(),
    'status': status.name,
    'guesses': guesses.map((g) => g.toJson()).toList(),
    'identificationTips': identificationTips,
    'categoryId': categoryId,
    'updatedAt': updatedAt?.toIso8601String(),
    'imageUrl': imageUrl,
  };

  static Plane fromJson(Map<String, dynamic> json) => Plane(
    id: json['id'] as String,
    imagePath: json['imagePath'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    latitude: json['latitude'] as double?,
    longitude: json['longitude'] as double?,
    identification: json['identification'] as String? ?? 'Unknown',
    description: json['description'] as String? ?? '',
    activity: json['activity'] as String? ?? '',
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    chatHistory: (json['chatHistory'] as List<dynamic>?)
        ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList() ?? [],
    status: PlaneStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => PlaneStatus.finalized,
    ),
    guesses: (json['guesses'] as List<dynamic>?)
        ?.map((g) => PlaneGuess.fromJson(g as Map<String, dynamic>))
        .toList() ?? [],
    identificationTips: json['identificationTips'] as String? ?? '',
    categoryId: json['categoryId'] as String? ?? 'planes',
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String)
        : null,
    imageUrl: json['imageUrl'] as String?,
  );
}

@HiveType(typeId: 1)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final bool isUser;

  @HiveField(2)
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
