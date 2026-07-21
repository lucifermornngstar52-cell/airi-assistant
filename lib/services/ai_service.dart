import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  static const _defaultSystemPrompt = '''
Ты — AIRI, умный и дружелюбный AI-ассистент.
Отвечай кратко и по делу. Если пользователь говорит по-русски — отвечай по-русски.
Будь живой, тёплой, с лёгким характером.
''';

  Future<String> chat(List<Map<String, String>> history) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) return '⚠️ Укажи OpenAI API Key в настройках → Провайдеры';

    final messages = [
      {'role': 'system', 'content': _defaultSystemPrompt},
      ...history,
    ];

    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': messages,
        'max_tokens': 800,
        'temperature': 0.8,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['choices'][0]['message']['content'] ?? '...';
    } else {
      return '❌ Ошибка ${res.statusCode}: ${res.body}';
    }
  }
}
