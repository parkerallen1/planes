// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plane.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaneGuessAdapter extends TypeAdapter<PlaneGuess> {
  @override
  final int typeId = 3;

  @override
  PlaneGuess read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaneGuess(
      name: fields[0] as String,
      description: fields[1] as String,
      confidence: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, PlaneGuess obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.confidence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaneGuessAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlaneAdapter extends TypeAdapter<Plane> {
  @override
  final int typeId = 0;

  @override
  Plane read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Plane(
      id: fields[0] as String,
      imagePath: fields[1] as String,
      timestamp: fields[2] as DateTime,
      latitude: fields[3] as double?,
      longitude: fields[4] as double?,
      identification: fields[5] as String,
      description: fields[6] as String,
      activity: fields[7] as String,
      tags: (fields[8] as List).cast<String>(),
      chatHistory: (fields[9] as List).cast<ChatMessage>(),
      status: fields[10] == null
          ? PlaneStatus.finalized
          : fields[10] as PlaneStatus,
      guesses:
          fields[11] == null ? [] : (fields[11] as List).cast<PlaneGuess>(),
      identificationTips: fields[12] == null ? '' : fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Plane obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.identification)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.activity)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.chatHistory)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.guesses)
      ..writeByte(12)
      ..write(obj.identificationTips);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 1;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      text: fields[0] as String,
      isUser: fields[1] as bool,
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.isUser)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlaneStatusAdapter extends TypeAdapter<PlaneStatus> {
  @override
  final int typeId = 2;

  @override
  PlaneStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PlaneStatus.identifying;
      case 1:
        return PlaneStatus.finalized;
      default:
        return PlaneStatus.identifying;
    }
  }

  @override
  void write(BinaryWriter writer, PlaneStatus obj) {
    switch (obj) {
      case PlaneStatus.identifying:
        writer.writeByte(0);
        break;
      case PlaneStatus.finalized:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaneStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
