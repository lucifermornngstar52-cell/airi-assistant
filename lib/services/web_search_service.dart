import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WebSearchService — поиск в интернете.
/// 
/// Два режима:
/// 1. "найди X" / "погугли X" — открывает браузер с Google-поиском
/// 2. "найди информацию о X" / "что такое X" — ищет через DuckDuckGo
///    и возвращает результат в чат для AI-обработки
class WebSearchService {
  static const _channel = MethodChannel('com.airi.assistant/launcher');

  /// Триггеры для открытия браузера
  static const List<String> browserTriggers = [
    'найди', 'погугли', 'поищи', 'загугли', 'искать',
    'поиск по запросу', 'google it', 'search for',
  ];

  /// Триггеры для умного поиска (в чате)
  static const List<String> smartTriggers = [
    'найди информацию', 'найди инфу', 'что такое', 'кто такой',
    'что значит', 'расскажи о', 'что такое поисковая',
    'search info', 'look up',
  ];

  /// Триггеры для открытия сайта
  static const List<String> siteTriggers = [
    'открой сайт', 'перейди на сайт', 'зайди на сайт',
    'открой ссылку', 'перейди по ссылке',
  ];

  /// Проверяет есть ли поисковый запрос
  static bool isSearchCommand(String text) {
    final t = text.toLowerCase().trim();
    for (final trigger in browserTriggers) {
      if (t.startsWith(trigger + ' ') || t.contains(' ' + trigger + ' ')) return true;
    }
    for (final trigger in smartTriggers) {
      if (t.startsWith(trigger + ' ') || t.contains(' ' + trigger + ' ')) return true;
    }
    for (final trigger in siteTriggers) {
      if (t.startsWith(trigger + ' ') || t.contains(' ' + trigger + ' ')) return true;
    }
    return false;
  }

  /// Главная точка входа. Возвращает результат или null если это не поисковый запрос.
  static Future<String?> trySearch(String text) async {
    final t = text.toLowerCase().trim();

    // ── Открытие сайта ──
    for (final trigger in siteTriggers) {
      if (t.startsWith(trigger + ' ')) {
        final site = text.substring(t.indexOf(trigger) + trigger.length).trim();
        if (site.isNotEmpty) return await _openWebsite(site);
      }
    }

    // ── Умный поиск (DuckDuckGo API) ──
    for (final trigger in smartTriggers) {
      if (t.startsWith(trigger + ' ')) {
        final query = text.substring(t.indexOf(trigger) + trigger.length).trim();
        if (query.isNotEmpty) return await _smartSearch(query);
      }
    }

    // ── Поиск в браузере ──
    for (final trigger in browserTriggers) {
      if (t.startsWith(trigger + ' ')) {
        final query = text.substring(t.indexOf(trigger) + trigger.length).trim();
        if (query.isNotEmpty) return await _searchInBrowser(query);
      }
    }

    return null;
  }

  /// Открывает Google-поиск в браузере
  static Future<String> _searchInBrowser(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final url = 'https://www.google.com/search?q=$encoded';
      // На Windows — через url_launcher
      if (Platform.isWindows) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return 'Ищу "$query" в браузере 🔍';
      }
      // На Android — через MethodChannel
      await _channel.invokeMethod('launchUrl', {'url': url});
      return 'Ищу "$query" в браузере 🔍';
    } catch (e) {
      // Фолбэк — пробуем через findAndLaunch открыть браузер
      try {
        await _channel.invokeMethod('findAndLaunch', {'name': 'chrome'});
        return 'Открываю браузер для поиска 🔍';
      } catch (_) {
        return 'Не удалось открыть браузер 😕';
      }
    }
  }

  /// Умный поиск через DuckDuckGo — возвращает результат текстом
  static Future<String> _smartSearch(String query) async {
    try {
      // DuckDuckGo Instant Answer API
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse('https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1&skip_disambig=1&ru=1');

      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final abstractText = data['AbstractText'] as String? ?? '';
        final abstractSource = data['AbstractSource'] as String? ?? '';
        final abstractUrl = data['AbstractURL'] as String? ?? '';

        // Собираем результаты
        final results = <String>[];

        if (abstractText.isNotEmpty) {
          results.add(abstractText);
          if (abstractSource.isNotEmpty) {
            results.add('\n\nИсточник: $abstractSource');
          }
        }

        // Related topics (топ 3)
        final related = data['RelatedTopics'] as List? ?? [];
        for (var i = 0; i < related.length && i < 3; i++) {
          final topic = related[i] as Map<String, dynamic>?;
          if (topic != null) {
            final text = topic['Text'] as String? ?? '';
            if (text.isNotEmpty && text.length > 20) {
              results.add('\n\n• $text');
            }
          }
        }

        if (results.isNotEmpty) {
          // Открываем также браузер для полноты
          await _searchInBrowser(query);
          return 'Вот что нашла по запросу "$query":\n\n${results.join()}\n\nПодробности в браузере 🔍';
        }

        // Если DuckDuckGo ничего не дал — открываем браузер
        await _searchInBrowser(query);
        return 'Открываю браузер для поиска "$query" 🔍';
      }

      await _searchInBrowser(query);
      return 'Ищу "$query" в браузере 🔍';
    } catch (e) {
      // Фолбэк — открываем браузер
      try {
        await _searchInBrowser(query);
        return 'Ищу "$query" в браузере 🔍';
      } catch (_) {
        return 'Не удалось найти информацию 😕';
      }
    }
  }

  /// Открывает сайт
  static Future<String> _openWebsite(String site) async {
    try {
      var url = site.trim();
      if (!url.startsWith('http')) url = 'https://$url';
      if (Platform.isWindows) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return 'Открываю $site 🌐';
      }
      await _channel.invokeMethod('launchUrl', {'url': url});
      return 'Открываю $site 🌐';
    } catch (_) {
      try {
        await _channel.invokeMethod('findAndLaunch', {'name': 'chrome'});
        return 'Открываю браузер 🌐';
      } catch (_) {
        return 'Не удалось открыть сайт 😕';
      }
    }
  }
}
