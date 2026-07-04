import 'package:flutter_test/flutter_test.dart';
import 'package:dexicon/models/plane.dart';

void main() {
  test('Plane JSON round-trip preserves sync fields', () {
    final plane = Plane(
      id: '123',
      imagePath: 'scans/abc.jpg',
      timestamp: DateTime.utc(2026, 7, 4, 12),
      identification: 'F-35 Lightning II',
      description: 'desc',
      activity: 'flying',
      tags: ['Fighter', 'Stealth'],
      chatHistory: [
        ChatMessage(text: 'hi', isUser: true, timestamp: DateTime.utc(2026)),
      ],
      status: PlaneStatus.finalized,
      guesses: [PlaneGuess(name: 'F-35', description: 'd', confidence: 0.9)],
      identificationTips: 'tips',
      categoryId: 'birds',
      updatedAt: DateTime.utc(2026, 7, 4, 13),
      imageUrl: 'https://example.com/x.jpg',
    );

    final restored = Plane.fromJson(plane.toJson());

    expect(restored.id, plane.id);
    expect(restored.imagePath, plane.imagePath);
    expect(restored.categoryId, 'birds');
    expect(restored.updatedAt, DateTime.utc(2026, 7, 4, 13));
    expect(restored.imageUrl, 'https://example.com/x.jpg');
    expect(restored.tags, plane.tags);
    expect(restored.chatHistory.single.text, 'hi');
    expect(restored.guesses.single.confidence, 0.9);
    expect(restored.status, PlaneStatus.finalized);
  });

  test('Plane fromJson tolerates missing optional fields', () {
    final restored = Plane.fromJson({
      'id': '1',
      'imagePath': '/old/absolute/path.jpg',
      'timestamp': '2025-01-01T00:00:00.000Z',
    });

    expect(restored.categoryId, 'planes');
    expect(restored.updatedAt, isNull);
    expect(restored.imageUrl, isNull);
  });
}
