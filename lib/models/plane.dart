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
  });
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
}
