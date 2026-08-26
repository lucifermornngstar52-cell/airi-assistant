import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_service.dart';
import '../models/character_persona.dart';

class AiService {
  final _memory = MemoryService();

  /// Основной чат — GPT-4o, стриминг, разговорный стиль
  Future<String> chat(
    List<Map<String, String>> history, {
    CharacterPersona? persona,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) {
      return '⚠️ Укажи OpenAI API Key в Настройках → Провайдеры';
    }

    final basePrompt = (persona?.systemPrompt ??
        'Ты — AIRI, умный и дружелюбный AI-ассистент. Отвечай по-русски.') +
        '\n\nОТКРЫТИЕ ПРИЛОЖЕНИЙ: Если пользователь просит открыть приложение, ответь "Открываю [название]" и приложение запустится автоматически. Доступные приложения: телеграм, ватсап, ютуб, инстаграм, браузер, телефон, камера, настройки, карты, музыка';

    final memorySummary = await _memory.getMemorySummary();
    final systemPrompt = basePrompt + memorySummary;

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
          'model': 'gpt-4o',
          'messages': messages,
          'max_tokens': 1500,
          'temperature': 0.9,
        }),
      ).timeout(const Duration(seconds: 45));

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

  /// Чат с учётом эмоции пользователя — более естественные реакции
  Future<String> chatWithEmotion(
    List<Map<String, String>> history, {
    CharacterPersona? persona,
    String? userEmotion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) {
      return '⚠️ Укажи OpenAI API Key в Настройках → Провайдеры';
    }

    final basePrompt = persona?.systemPrompt ??
        'Ты — AIRI, умный и дружелюбный AI-ассистент. Отвечай по-русски.';

    // Add emotional awareness to system prompt
    String emotionContext = '';
    if (userEmotion != null) {
      emotionContext = '\n\nТЕКУЩЕЕ ЭМОЦИОНАЛЬНОЕ СОСТОЯНИЕ ПОЛЬЗОВАТЕЛЯ: $userEmotion\n'
          'Учитывай это при ответе. Если пользователь грустит — будь поддерживающим. '
          'Если радостен — раздели его радость. Если зол — будь спокойным и рассудительным. '
          'НЕ упоминай напрямую что видишь эмоцию — просто адаптируй стиль естественно.';
    }

    final fullPrompt = basePrompt +
        '\n\nОТКРЫТИЕ ПРИЛОЖЕНИЙ: Если пользователь просит открыть приложение, ответь "Открываю [название]" и приложение запустится автоматически.' +
        emotionContext +
        '\n\nВАЖНО: Отвечай как живой человек в разговоре — естественно, с интонацией, '
        'можешь задавать уточняющие вопросы, проявлять интерес, шутить к месту. '
        'Не давай сухие ответы-справки. Будь собеседником, а не справочником.' +
        (await _memory.getMemorySummary());

    final messages = [
      {'role': 'system', 'content': fullPrompt},
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
          'model': 'gpt-4o',
          'messages': messages,
          'max_tokens': 1500,
          'temperature': 0.9,
        }),
      ).timeout(const Duration(seconds: 45));

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

  /// Чат с изображением (GPT-4o Vision)
  Future<String> visionChat(
    String prompt,
    File image, {
    CharacterPersona? persona,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) {
      return '⚠️ Укажи OpenAI API Key в Настройках → Провайдеры';
    }

    final systemPrompt = persona?.systemPrompt ??
        'Ты — AIRI, умный и дружелюбный AI-ассистент. Отвечай по-русски.';

    final base64Image = base64Encode(await image.readAsBytes());
    final mime = image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {'type': 'image_url', 'image_url': {'url': 'data:$mime;base64,$base64Image'}},
              ],
            },
          ],
          'max_tokens': 1500,
          'temperature': 0.85,
        }),
      ).timeout(const Duration(seconds: 45));

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

  Future<void> saveToMemory(String role, String content, {String? persona}) async {
    await _memory.addMessage(role, content, persona: persona);
  }

  Future<List<Map<String, String>>> loadMemoryHistory({int limit = 15}) async {
    return await _memory.getRecentMessages(limit: limit);
  }

  Future<void> extractFact(String text) async {
    // Simple fact extraction — in production, use GPT to extract
    // For now, just store as a general note
    await _memory.setFact('last_input', text);
  }

  Future<PersonaType> loadPersona() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('aika_persona') ?? 'jarvis';
    return PersonaType.values.firstWhere(
      (p) => p.name == name,
      orElse: () => PersonaType.jarvis,
    );
  }

  Future<void> savePersona(PersonaType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aika_persona', type.name);
  }
}
