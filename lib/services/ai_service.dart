import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_persona.dart';

class AiService {
  Future<String> chat(
    List<Map<String, String>> history, {
    CharacterPersona? persona,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) {
      return '⚠️ Укажи OpenAI API Key в Настройках → Провайдеры';
    }

    final systemPrompt = persona?.systemPrompt ??
        'Ты — AIRI, умный и дружелюбный AI-ассистент. Отвечай по-русски.';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
    ];

    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'max_tokens': 1000,
          'temperature': 0.85,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['choices'][0]['message']['content']?.trim() ?? '...';
      } else {
        return '❌ Ошибка ${res.statusCode}';
      }
    } catch (e) {
      return '❌ Нет соединения: $e';
    }
  }

  Future<void> savePersona(PersonaType type) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('persona', type.name);
  }

  Future<PersonaType> loadPersona() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('persona') ?? 'jarvis';
    return PersonaType.values.firstWhere((e) => e.name == saved,
        orElse: () => PersonaType.jarvis);
  }
}
