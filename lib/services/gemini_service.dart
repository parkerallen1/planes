import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/plane.dart';
import '../models/scan_category.dart';
import 'firebase_bootstrap.dart';
import 'genai_backend.dart';
import 'image_store.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  // Production path: Gemini via Firebase AI Logic — no API key in the
  // binary, requests App Check-attested.
  if (FirebaseBootstrap.firebaseAvailable) {
    return GeminiService(FirebaseAiBackend(model: GeminiService.modelName));
  }
  // Local-dev fallback: direct Gemini API with the .env.local key.
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    throw 'No AI backend available: configure Firebase (flutterfire '
        'configure) or put GEMINI_API_KEY in .env.local.';
  }
  return GeminiService(
    GoogleAiBackend(apiKey: apiKey, model: GeminiService.modelName),
  );
});

/// AI-generated starter profile for a newly created category.
class GeneratedCategoryProfile {
  final String emoji;
  final String geminiContext;
  final List<String> tags;

  GeneratedCategoryProfile({
    required this.emoji,
    required this.geminiContext,
    required this.tags,
  });
}

class GeminiService {
  static const modelName = 'gemini-3.5-flash';

  final GenAiBackend _backend;

  GeminiService(this._backend);

  static String _extractJson(String? text) {
    String jsonString = text ?? '{}';
    if (jsonString.contains('```json')) {
      jsonString = jsonString.split('```json')[1].split('```')[0];
    } else if (jsonString.contains('```')) {
      jsonString = jsonString.split('```')[1].split('```')[0];
    }
    return jsonString;
  }

  /// Generates an emoji, prompt context, and a starter tag set for a new
  /// category, so the user only has to type its name.
  Future<GeneratedCategoryProfile> generateCategoryProfile(String name) async {
    final prompt = '''
I'm building a collection app where users photograph items and catalog them.
A user just created a new category named "$name".

Provide:
1. A single emoji that best represents this category.
2. A short noun phrase describing the subject of a photo in this category, usable in prompts like "Identify this X" (e.g. "aircraft or airplane" for Planes).
3. 10-14 classification tags for items in this category. Tags must be short (1-2 words each) and generic — types, classes, or broad attributes rather than specific models, brands, or species (e.g. for Planes: "Fighter", "Trainer", "Stealth" — not "F-16"). They should still be specific enough to be useful for filtering within "$name". Capitalize each tag.

Return the response in JSON format:
{
  "emoji": "✈️",
  "geminiContext": "aircraft or airplane",
  "tags": ["Tag One", "Tag Two"]
}
''';

    final text = await _backend.generate(prompt);

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(_extractJson(text));
    } catch (e) {
      print('Error parsing JSON: $e');
    }

    final tags = List<String>.from(data['tags'] ?? [])
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tags.isEmpty) {
      throw 'Could not generate tags for "$name". Please try again.';
    }

    return GeneratedCategoryProfile(
      emoji: (data['emoji'] as String?)?.trim() ?? '',
      geminiContext: (data['geminiContext'] as String?)?.trim() ?? '',
      tags: tags,
    );
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
    void Function(List<String> newTags)? onNewTags,
  }) async {
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

    final image = await File(ImageStore.resolve(imagePath)).readAsBytes();
    final locStr =
        locationDescription ?? '${lat ?? 'Unknown'}, ${long ?? 'Unknown'}';
    final categoryName = activeCategory.name.toLowerCase();
    final validCategoryTags = activeCategory.validTags;

    final prompt = '''
Identify this ${activeCategory.geminiContext}.
Location: $locStr.
Based on the location, what might it be doing there?

Please provide:
1. Top 3-4 guesses for what ${categoryName} this is. For each guess, provide a name, a brief description, and a confidence score (0.0 to 1.0).
2. Identification tips: What specific visual features should I look for to confirm which ${categoryName} it is? Provide this as a bulleted list.
3. A general description and activity/context guess.
4. The maker/origin of the ${categoryName} (e.g. manufacturer, brand, species family, etc.).
5. 3-5 classification tags. Prefer tags from this list: ${validCategoryTags.join(', ')}. If the ${categoryName} genuinely doesn't fit those, you may invent up to 2 new tags — keep them short (1-2 words), generic types or classes (not specific models or brands), and consistent in style with the list.

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
''';

    final text = await _backend.generate(prompt, imageJpeg: image);
    final jsonString = _extractJson(text);

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

    // Report any tags the model invented (before the maker is mixed in) so
    // the caller can add them to the category's tag list.
    _reportNewTags(tags, validCategoryTags, onNewTags);

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
    void Function(List<String> newTags)? onNewTags,
  }) async {
    final activeCategory = category;
    final allowedTags = activeCategory?.validTags ?? validTags;
    final context = activeCategory?.geminiContext ?? 'aircraft or airplane';

    final image = await File(ImageStore.resolve(imagePath)).readAsBytes();
    final prompt = '''
Identify this $context and provide classification tags.
Select 3-5 tags, preferring tags from this list: ${allowedTags.join(', ')}.
If the subject genuinely doesn't fit those, you may invent up to 2 new tags — keep them short (1-2 words), generic types or classes (not specific models or brands), and consistent in style with the list.

Also identify the maker/brand/manufacturer/species-family.

Return the response in JSON format:
{
  "tags": ["tag1", "tag2"],
  "manufacturer": "Maker/Brand Name"
}
''';

    final text = await _backend.generate(prompt, imageJpeg: image);

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(_extractJson(text));
    } catch (e) {
      print('Error parsing JSON: $e');
      return [];
    }

    final tags = List<String>.from(data['tags'] ?? []);
    _reportNewTags(tags, allowedTags, onNewTags);

    if (data['manufacturer'] != null &&
        data['manufacturer'].toString().isNotEmpty) {
      tags.insert(0, data['manufacturer']);
    }

    return tags;
  }

  /// Invokes [onNewTags] with the tags the model returned that aren't in the
  /// category's known tag list (case-insensitive).
  static void _reportNewTags(
    List<String> returnedTags,
    List<String> knownTags,
    void Function(List<String>)? onNewTags,
  ) {
    if (onNewTags == null) return;
    final known = knownTags.map((t) => t.toLowerCase()).toSet();
    final invented = returnedTags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !known.contains(t.toLowerCase()))
        .toList();
    if (invented.isNotEmpty) {
      onNewTags(invented);
    }
  }

  Future<String> chat(
    List<ChatMessage> history,
    String message,
    String imagePath, {
    String? planeContext,
    String subject = 'item',
  }) async {
    // Failed sends can leave unanswered user turns persisted at the end of
    // the saved history; the API rejects histories that don't alternate
    // user/model roles, so drop them before starting the chat.
    final pastHistory = List<ChatMessage>.from(history);
    while (pastHistory.isNotEmpty && pastHistory.last.isUser) {
      pastHistory.removeLast();
    }

    String finalMessage = message;
    if (planeContext != null && planeContext.isNotEmpty) {
      finalMessage =
          "Context: The user is asking about the $subject identified as '$planeContext'. $message";
    }

    // On the first turn, attach the item's photo so the whole conversation
    // is grounded in it; later turns are text-only on top of the history.
    final image = pastHistory.isEmpty
        ? await File(ImageStore.resolve(imagePath)).readAsBytes()
        : null;

    final response = await _backend.chat(
      history: pastHistory
          .map((m) => (isUser: m.isUser, text: m.text))
          .toList(),
      message: finalMessage,
      imageJpeg: image,
      imageIntro: "Here is the image of the $subject we are discussing.",
    );
    return response ?? 'I could not generate a response.';
  }
}
