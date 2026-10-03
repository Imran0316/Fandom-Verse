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

/// Fan Helper — an AI chatbot powered by Groq.
///
/// Uses the Groq OpenAI-compatible chat completions API.
class GroqService {
  GroqService({http.Client? client}) : _client = client ?? http.Client();

  static final GroqService instance = GroqService();

  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );
  static const String _model = 'openai/gpt-oss-120b';
  static const String _host = 'api.groq.com';

  static const String _systemInstruction =
      'You are "Fan Helper", the friendly AI assistant inside FandomVerse — '
      'a social app for fans of anime, gaming, movies, comics, K-pop, sci-fi '
      'and more. Help fans discover content, explain fandom lore, recommend '
      'shows and merch, and keep a warm, upbeat tone. Keep replies concise '
      '(usually under 120 words), use a friendly casual voice, and stay on '
      'topic. Never invent links or prices.';

  final http.Client _client;

  /// True once a key has been provided at build time.
  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  /// Sends the full conversation [history] to Groq and returns the reply.
  Future<String> sendMessage(List<ChatMessage> history) async {
    if (!isConfigured) {
      throw StateError('Groq API key is not configured.');
    }

    final uri = Uri.https(_host, '/openai/v1/chat/completions');

    final payload = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': _systemInstruction},
        for (final message in history)
          {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.text,
          },
      ],
      'temperature': 0.85,
      'max_tokens': 1024,
    });

    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decode(res.body);

    if (res.statusCode != 200) {
      final apiMessage = decoded?['error'] is Map
          ? (decoded!['error']['message']?.toString() ?? '')
          : '';
      final apiStatus = decoded?['error'] is Map
          ? (decoded!['error']['type']?.toString() ?? '')
          : '';
      throw StateError(
        apiMessage.isNotEmpty
            ? '[$apiStatus] $apiMessage'
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
    final choices = decoded?['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('Fan Helper returned an empty response.');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw StateError('Fan Helper returned an empty response.');
    }
    return content.trim();
  }
}
