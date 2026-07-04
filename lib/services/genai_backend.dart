import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:google_generative_ai/google_generative_ai.dart' as gai;

/// The two ways this app can reach Gemini.
///
/// [FirebaseAiBackend] goes through Firebase AI Logic: no API key ships in
/// the binary and requests carry App Check attestation — this is the
/// production path once Firebase is configured. [GoogleAiBackend] calls the
/// Gemini API directly with the `.env.local` key and remains as the
/// local-dev fallback when Firebase isn't set up.
abstract class GenAiBackend {
  /// One-shot generation: text prompt, optionally with an attached JPEG.
  Future<String?> generate(String prompt, {Uint8List? imageJpeg});

  /// Multi-turn chat. [history] alternates user/model turns. When
  /// [imageJpeg] is set (first turn of an item chat), [imageIntro] and the
  /// image are sent ahead of [message] in the same turn.
  Future<String?> chat({
    required List<({bool isUser, String text})> history,
    required String message,
    Uint8List? imageJpeg,
    String imageIntro = '',
  });
}

class FirebaseAiBackend implements GenAiBackend {
  FirebaseAiBackend({required String model})
      : _model = fai.FirebaseAI.googleAI().generativeModel(model: model);

  final fai.GenerativeModel _model;

  @override
  Future<String?> generate(String prompt, {Uint8List? imageJpeg}) async {
    final content = imageJpeg == null
        ? [fai.Content.text(prompt)]
        : [
            fai.Content.multi([
              fai.TextPart(prompt),
              fai.InlineDataPart('image/jpeg', imageJpeg),
            ]),
          ];
    return (await _model.generateContent(content)).text;
  }

  @override
  Future<String?> chat({
    required List<({bool isUser, String text})> history,
    required String message,
    Uint8List? imageJpeg,
    String imageIntro = '',
  }) async {
    final chat = _model.startChat(
      history: history
          .map(
            (m) => fai.Content(m.isUser ? 'user' : 'model', [
              fai.TextPart(m.text),
            ]),
          )
          .toList(),
    );
    final content = imageJpeg == null
        ? fai.Content.text(message)
        : fai.Content.multi([
            fai.TextPart(imageIntro),
            fai.InlineDataPart('image/jpeg', imageJpeg),
            fai.TextPart(message),
          ]);
    return (await chat.sendMessage(content)).text;
  }
}

class GoogleAiBackend implements GenAiBackend {
  GoogleAiBackend({required String apiKey, required String model})
      : _model = gai.GenerativeModel(model: model, apiKey: apiKey);

  final gai.GenerativeModel _model;

  @override
  Future<String?> generate(String prompt, {Uint8List? imageJpeg}) async {
    final content = imageJpeg == null
        ? [gai.Content.text(prompt)]
        : [
            gai.Content.multi([
              gai.TextPart(prompt),
              gai.DataPart('image/jpeg', imageJpeg),
            ]),
          ];
    return (await _model.generateContent(content)).text;
  }

  @override
  Future<String?> chat({
    required List<({bool isUser, String text})> history,
    required String message,
    Uint8List? imageJpeg,
    String imageIntro = '',
  }) async {
    final chat = _model.startChat(
      history: history
          .map(
            (m) => gai.Content(m.isUser ? 'user' : 'model', [
              gai.TextPart(m.text),
            ]),
          )
          .toList(),
    );
    final content = imageJpeg == null
        ? gai.Content.text(message)
        : gai.Content.multi([
            gai.TextPart(imageIntro),
            gai.DataPart('image/jpeg', imageJpeg),
            gai.TextPart(message),
          ]);
    return (await chat.sendMessage(content)).text;
  }
}
