import 'dart:convert';

import 'package:http/http.dart' as http;

/// Who produced a chat message in the Fan Helper conversation.
enum ChatRole { user, model }

/// A single turn in the Fan Helper conversation.
class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  final ChatRole role;
  final String text;

  bool get isUser => role == ChatRole.user;
}

/// Fan Helper — an AI chat bot powered by Google Gemini.
///
/// The API key is a placeholder for now. Replace [apiKey] below with your own
/// key, or pass it at build time (preferred, keeps it out of source control):
/// `flutter run --dart-define=GEMINI_API_KEY=your_key`
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  static final GeminiService instance = GeminiService();

  /// ⚠️ PLACEHOLDER — replace with your real Gemini API key.
  /// Get one free at https://aistudio.google.com/app/apikey
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6Ic9SOVk-kzMoRwP3LLsEfbD95K3Qw5G8osDVC9mvWosg',
  );

  static const String _model = 'gemini-3.8-flash';
  static const String _host = 'generativelanguage.googleapis.com';

  static const String _systemInstruction =
      'You are "Fan Helper", the friendly AI assistant inside FandomVerse — '
      'a social app for fans of anime, gaming, movies, comics, K-pop, sci-fi '
      'and more. Help fans discover content, explain fandom lore, recommend '
      'shows and merch, and keep a warm, upbeat tone. Keep replies concise '
      '(usually under 120 words), use a friendly casual voice, and stay on '
      'topic. Never invent links or prices.';

  final http.Client _client;

  /// True once a real key (not the placeholder) has been provided.
  static bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.startsWith('PASTE_YOUR_GEMINI');

  /// Sends the full conversation [history] to Gemini and returns the reply.
  Future<String> sendMessage(List<ChatMessage> history) async {
    if (!isConfigured) {
      throw StateError(
        'Gemini API key is not configured. Add your key to GeminiService.apiKey '
        'or run with --dart-define=GEMINI_API_KEY=AQ.Ab8RN6Ic9SOVk-kzMoRwP3LLsEfbD95K3Qw5G8osDVC9mvWosg',
      );
    }

    final uri = Uri.https(
      _host,
      '/v1beta/models/$_model:generateContent',
      {'key': apiKey},
    );

    final payload = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction},
        ],
      },
      'contents': [
        for (final message in history)
          {
            'role': message.isUser ? 'user' : 'model',
            'parts': [
              {'text': message.text},
            ],
          },
      ],
      'generationConfig': {
        'temperature': 0.85,
        'maxOutputTokens': 1024,
      },
    });

    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decode(res.body);

    if (res.statusCode != 200) {
      final apiMessage = decoded?['error'] is Map
          ? (decoded!['error']['message']?.toString() ?? '')
          : '';
      throw StateError(
        apiMessage.isNotEmpty
            ? apiMessage
            : 'Fan Helper is unavailable right now (${res.statusCode}).',
      );
    }

    return _extractText(decoded);
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _extractText(Map<String, dynamic>? decoded) {
    final candidates = decoded?['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('Fan Helper returned an empty response.');
    }
    final content = (candidates.first as Map)['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) {
      throw StateError('Fan Helper returned an empty response.');
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] != null) {
        buffer.write(part['text'].toString());
      }
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw StateError('Fan Helper returned an empty response.');
    }
    return text;
  }
}
