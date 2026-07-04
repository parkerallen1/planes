import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/plane.dart';
import '../models/scan_category.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  // Load API key from .env.local file
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    throw 'GEMINI_API_KEY not found in .env.local file.';
  }
  return GeminiService(apiKey: apiKey);
});

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
    _model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: apiKey);
  }

  // Default tags for planes (kept for backward compatibility)
  static const List<String> validTags = [
    'Fighter',
    'Bomber',
    'Transport/Cargo',
    'Attack Helicopter',
    'Utility Helicopter',
    'Surveillance/AWACS',
    'Tanker',
    'Trainer',
    'Drone/UAV',
    'Stealth',
    'Experimental',
    'Vintage Warbird',
    'Commercial/Civilian',
  ];

  Future<Plane> identifyPlane(
    String imagePath,
    double? lat,
    double? long,
    String? locationDescription, {
    ScanCategory? category,
  }) async {
    if (apiKey == 'YOUR_API_KEY') {
      throw 'Please set your Gemini API key in lib/services/gemini_service.dart';
    }

    final activeCategory = category ??
        const ScanCategory(
          id: 'planes',
          name: 'Planes',
          emoji: '✈️',
          geminiContext: 'aircraft or airplane',
          validTags: [
            'Fighter', 'Bomber', 'Transport/Cargo', 'Attack Helicopter',
            'Utility Helicopter', 'Surveillance/AWACS', 'Tanker', 'Trainer',
            'Drone/UAV', 'Stealth', 'Experimental', 'Vintage Warbird',
            'Commercial/Civilian',
          ],
        );

    final image = await File(imagePath).readAsBytes();
    final locStr =
        locationDescription ?? '${lat ?? 'Unknown'}, ${long ?? 'Unknown'}';
    final categoryName = activeCategory.name.toLowerCase();
    final validCategoryTags = activeCategory.validTags;

    final prompt = TextPart('''
Identify this ${activeCategory.geminiContext}.
Location: $locStr.
Based on the location, what might it be doing there?

Please provide:
1. Top 3-4 guesses for what ${categoryName} this is. For each guess, provide a name, a brief description, and a confidence score (0.0 to 1.0).
2. Identification tips: What specific visual features should I look for to confirm which ${categoryName} it is? Provide this as a bulleted list.
3. A general description and activity/context guess.
4. The maker/origin of the ${categoryName} (e.g. manufacturer, brand, species family, etc.).
5. 3-5 classification tags. IMPORTANT: You must ONLY select tags from this exact list: ${validCategoryTags.join(', ')}. Do not use any other tags.

Return the response in JSON format:
{
  "guesses": [
    {
      "name": "${activeCategory.name} Name 1",
      "description": "Description of this specific type",
      "confidence": 0.9
    },
    ...
  ],
  "identificationTips": "Look for...",
  "description": "General description",
  "activity": "What it might be doing / context",
  "manufacturer": "Maker/Brand/Family Name",
  "tags": ["tag1", "tag2", "tag3"]
}
''');

    final content = [
      Content.multi([prompt, DataPart('image/jpeg', image)]),
    ];

    // Use gemini-3.5-flash as requested
    final model = GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: apiKey,
    );
    final response = await model.generateContent(content);
    final text = response.text;

    String jsonString = text ?? '{}';
    if (jsonString.contains('```json')) {
      jsonString = jsonString.split('```json')[1].split('```')[0];
    } else if (jsonString.contains('```')) {
      jsonString = jsonString.split('```')[1].split('```')[0];
    }

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(jsonString);
    } catch (e) {
      print('Error parsing JSON: $e');
    }

    final guesses =
        (data['guesses'] as List<dynamic>?)
            ?.map(
              (g) => PlaneGuess(
                name: g['name'] ?? 'Unknown',
                description: g['description'] ?? '',
                confidence: (g['confidence'] as num?)?.toDouble() ?? 0.0,
              ),
            )
            .toList() ??
        [];

    final tags = List<String>.from(data['tags'] ?? ['Plane']);
    if (data['manufacturer'] != null &&
        data['manufacturer'].toString().isNotEmpty) {
      tags.insert(0, data['manufacturer']);
    }

    // Handle identificationTips as either String or List<String>
    String tips = '';
    final rawTips = data['identificationTips'];
    if (rawTips is String) {
      tips = rawTips;
    } else if (rawTips is List) {
      tips = rawTips.map((t) => '• $t').join('\n');
    }

    return Plane(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imagePath: imagePath,
      timestamp: DateTime.now(),
      latitude: lat,
      longitude: long,
      identification: guesses.isNotEmpty
          ? guesses.first.name
          : 'Unknown ${activeCategory.name}',
      description: data['description'] ?? (text ?? 'No description available'),
      activity: data['activity'] ?? 'Unknown activity',
      tags: tags,
      status: PlaneStatus.identifying,
      guesses: guesses,
      identificationTips: tips,
      categoryId: activeCategory.id,
    );
  }

  Future<List<String>> regenerateTags(
    String imagePath, {
    ScanCategory? category,
  }) async {
    final activeCategory = category;
    final allowedTags = activeCategory?.validTags ?? validTags;
    final context = activeCategory?.geminiContext ?? 'aircraft or airplane';

    final image = await File(imagePath).readAsBytes();
    final prompt = TextPart('''
Identify this $context and provide classification tags.
Please select 3-5 tags from this EXACT list: ${allowedTags.join(', ')}.

Also identify the maker/brand/manufacturer/species-family.

Return the response in JSON format:
{
  "tags": ["tag1", "tag2"],
  "manufacturer": "Maker/Brand Name"
}
''');

    final content = [
      Content.multi([prompt, DataPart('image/jpeg', image)]),
    ];

    final response = await _model.generateContent(content);
    final text = response.text;

    String jsonString = text ?? '{}';
    if (jsonString.contains('```json')) {
      jsonString = jsonString.split('```json')[1].split('```')[0];
    } else if (jsonString.contains('```')) {
      jsonString = jsonString.split('```')[1].split('```')[0];
    }

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(jsonString);
    } catch (e) {
      print('Error parsing JSON: $e');
      return [];
    }

    final tags = List<String>.from(data['tags'] ?? []);
    if (data['manufacturer'] != null &&
        data['manufacturer'].toString().isNotEmpty) {
      tags.insert(0, data['manufacturer']);
    }

    return tags;
  }

  Future<String> chat(
    List<ChatMessage> history,
    String message,
    String imagePath, {
    String? planeContext,
  }) async {
    // Note: For multi-turn chat with images, we'd ideally use a model that supports it in chat history.
    // For this prototype, we'll start a new chat or append to history text-only.
    // A better approach for "chatting about a plane" is to send the image in the first turn (which we did in identifyPlane)
    // and then continue the conversation. However, the `identifyPlane` call was a single generation, not a chat session.
    // So we will start a new chat session here, providing the image in the first user message if the history is empty,
    // or just text if we are continuing.

    // Since we don't persist the `ChatSession` object, we have to reconstruct it or just use `generateContent` with history included manually.
    // Using `startChat` is easier.

    // Failed sends can leave unanswered user turns persisted at the end of
    // the saved history; the API rejects histories that don't alternate
    // user/model roles, so drop them before starting the chat.
    final pastHistory = List<ChatMessage>.from(history);
    while (pastHistory.isNotEmpty && pastHistory.last.isUser) {
      pastHistory.removeLast();
    }

    final chat = _model.startChat(
      history: pastHistory
          .map((m) => Content(m.isUser ? 'user' : 'model', [TextPart(m.text)]))
          .toList(),
    );

    // If this is the first message in this specific chat interaction (not the whole history), we might want to attach the image context again.
    // But `history` passed here is the *past* history.
    // If history is empty, it means we are starting the chat. We should probably include the image context.

    String finalMessage = message;
    if (planeContext != null && planeContext.isNotEmpty) {
      finalMessage =
          "Context: The user is asking about the plane identified as '$planeContext'. $message";
    }

    Content content;
    if (pastHistory.isEmpty) {
      final image = await File(imagePath).readAsBytes();
      content = Content.multi([
        TextPart("Here is the image of the plane we are discussing."),
        DataPart('image/jpeg', image),
        TextPart(finalMessage),
      ]);
    } else {
      content = Content.text(finalMessage);
    }

    final response = await chat.sendMessage(content);
    return response.text ?? 'I could not generate a response.';
  }
}
