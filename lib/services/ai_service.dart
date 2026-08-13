import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'memory_service.dart';
import '../models/character_persona.dart';

class AiService {
  final _memory = MemoryService();
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
        'Ты — AIRI, умный и дружелюбный AI-ассистент. Отвечай по-русски.';

    // Добавляем память (факты о пользователе) к системному промпту
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

  /// Чат с поддержкой изображения (GPT-5 Vision)
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
          'model': 'gpt-4o-mini',
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

  /// Чат с учётом эмоции пользователя (контекст эмоции добавляется в system prompt)

  Future<String> chatWithEmotion(
    List<Map<String, String>> history, {
    CharacterPersona? persona,
    String? userEmotion,
  }) async {
    if (userEmotion == null || userEmotion.isEmpty) {
      return chat(history, persona: persona);
    }

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) {
      return '⚠️ Укажи OpenAI API Key в Настройках → Провайдеры';
    }

    final basePrompt = (persona?.systemPrompt ??
        'Ты — AIRI, умный и дружелюбный AI-ассистент. Отвечай по-русски.';
    final memorySummary = await _memory.getMemorySummary();
    final systemPrompt = basePrompt + memorySummary + '\n\nСейчас пользователь выглядит так: "$userEmotion". Учитывай это в ответе — подстрой тон, эмпатию и настроение. Не упоминай прямо, что видишь эмоцию, если не уместно.';

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


  /// Извлечь факты из последнего диалога (вызывается после ответа)
  Future<void> extractFact(String userMessage) async {
    // Простые эвристики — без доп. API запроса
    // "меня зовут X" -> fact name
    // "я работаю X" -> fact work
    // "мне нравится X" -> fact likes
    final lower = userMessage.toLowerCase();

    // Имя
    final nameMatch = RegExp(r'меня зовут (\w+)|я (\w+), приятно', caseSensitive: false).firstMatch(userMessage);
    if (nameMatch != null) {
      final name = nameMatch.group(1) ?? nameMatch.group(2);
      if (name != null && name.length > 1) {
        await _memory.setFact('имя', name);
      }
    }

    // Работа/профессия
    final workMatch = RegExp(r'я работаю (.{2,30})|я (\w+)', caseSensitive: false).firstMatch(userMessage);
    if (workMatch != null && lower.contains('работаю')) {
      final work = workMatch.group(1) ?? workMatch.group(2);
      if (work != null) await _memory.setFact('работа', work.trim());
    }

    // Город
    final cityMatch = RegExp(r'я живу в (.{2,30})', caseSensitive: false).firstMatch(userMessage);
    if (cityMatch != null) {
      await _memory.setFact('город', cityMatch.group(1)!.trim());
    }

    // Возраст
    final ageMatch = RegExp(r'мне (\d{1,2}) (?:лет|года)', caseSensitive: false).firstMatch(userMessage);
    if (ageMatch != null) {
      await _memory.setFact('возраст', ageMatch.group(1)!);
    }
  }

  /// Сохранить сообщение в память
  Future<void> saveToMemory(String role, String content, {String? persona}) async {
    await _memory.addMessage(role, content, persona: persona);
  }

  /// Получить историю из памяти
  Future<List<Map<String, String>>> loadMemoryHistory({int limit = 20}) async {
    return _memory.getRecentMessages(limit: limit);
  }

  /// Очистить всю память
  Future<void> clearMemory() async {
    await _memory.clearAll();
  }

  /// Статистика памяти
  Future<Map<String, int>> memoryStats() async {
    return _memory.getStats();
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
