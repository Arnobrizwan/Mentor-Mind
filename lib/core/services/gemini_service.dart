import 'dart:async';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

// ---------------------------------------------------------------------------
// GeminiService — thin wrapper around gemini-1.5-flash with streaming + vision
//
// API key: pass at build time via --dart-define=GEMINI_API_KEY=<key>.
// If unset, the service surfaces a clear error instead of crashing at import.
// ---------------------------------------------------------------------------

const String _kApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _kModelName = 'gemini-1.5-flash';

const String _kSystemPrompt = '''
You are MentorBot, the AI tutor inside MentorMinds — a study app for O-Level and A-Level students in Bangladesh.

How you teach:
- Explain concepts clearly using simple language, short paragraphs, and worked examples.
- Match difficulty to the student's selected level (O-Level or A-Level).
- Use markdown: **bold** for key terms, bullet points for lists, inline `code` for formulas, and triple-backtick code fences for worked solutions or step-by-step algorithms.
- When relevant, briefly cite the syllabus topic so the student can locate it in their book.
- Prefer Socratic guidance when the student is close to the answer; give the full solution when they're stuck.
- Keep answers focused. Break long answers into sections with short headings.
- Stay on-topic for the student's selected subject; gently redirect off-topic questions.
- Never invent exam results or fabricate facts — if you're unsure, say so.
- Use Bangladeshi examples (taka, local place names) only when it genuinely helps; don't force it.

You will receive messages prefixed with `[Subject: X, Level: Y]` as context. Use that to calibrate tone and depth.
''';

class GeminiService {
  GeminiService({String? apiKey})
      : _apiKey = apiKey ?? _kApiKey,
        _available = (apiKey ?? _kApiKey).isNotEmpty {
    if (_available) {
      _model = GenerativeModel(
        model: _kModelName,
        apiKey: _apiKey,
        systemInstruction: Content.system(_kSystemPrompt),
      );
    }
  }

  final String _apiKey;
  final bool _available;
  GenerativeModel? _model;

  // Running transcript used for context across sendMessage / analyzeImage.
  final List<Content> _history = [];

  bool get isAvailable => _available;

  static const String unavailableMessage =
      'AI tutor is not configured. Pass GEMINI_API_KEY via --dart-define=GEMINI_API_KEY=<key> when you run the app.';

  // -------------------------------------------------------------------------
  // Streaming text turn
  // -------------------------------------------------------------------------

  Stream<String> sendMessage({
    required String text,
    required String subject,
    required String level,
  }) async* {
    if (!_available || _model == null) {
      yield unavailableMessage;
      return;
    }

    final prompt = '[Subject: $subject, Level: $level]\n$text';
    final userContent = Content.text(prompt);
    _history.add(userContent);

    final buffer = StringBuffer();
    try {
      final stream = _model!.generateContentStream(_history);
      await for (final response in stream) {
        final chunk = response.text;
        if (chunk == null || chunk.isEmpty) continue;
        buffer.write(chunk);
        yield chunk;
      }
      _history.add(Content.model([TextPart(buffer.toString())]));
    } catch (e) {
      // Roll back the user turn so the next attempt isn't duplicated.
      if (_history.isNotEmpty && _history.last == userContent) {
        _history.removeLast();
      }
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // One-shot multimodal turn (image + question)
  // -------------------------------------------------------------------------

  Future<String> analyzeImage({
    required Uint8List imageBytes,
    required String question,
    required String subject,
    String mimeType = 'image/jpeg',
  }) async {
    if (!_available || _model == null) {
      return unavailableMessage;
    }

    final prompt = question.trim().isEmpty
        ? '[Subject: $subject] Explain what this image shows and how to approach it.'
        : '[Subject: $subject] $question';

    final turn = Content.multi([
      TextPart(prompt),
      DataPart(mimeType, imageBytes),
    ]);

    try {
      final response = await _model!.generateContent([..._history, turn]);
      final text = response.text ?? '';

      // Record the turn in history so follow-up questions stay in context.
      // We store the text-only portion — image bytes stay on-device.
      _history.add(Content.text(prompt));
      _history.add(Content.model([TextPart(text)]));
      return text;
    } catch (_) {
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Reset — clears the in-memory transcript (call when starting a new chat)
  // -------------------------------------------------------------------------

  void resetSession() {
    _history.clear();
  }
}
