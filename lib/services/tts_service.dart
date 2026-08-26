import 'dart:convert';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_persona.dart';
import 'openai_tts_service.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final OpenAiTtsService _openaiTts = OpenAiTtsService();
  bool _initialized = false;
  bool _speaking = false;
  bool _usingOpenAi = false;

  bool get isSpeaking => _speaking;

  /// Инициализация локального TTS (для не-JARVIS персон)
  Future<void> _initLocal(PersonaType persona) async {
    if (!_initialized) {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(persona == PersonaType.jarvis ? 0.42 : 0.44);
      await _tts.setVolume(1.0);
      await _tts.setPitch(persona == PersonaType.jarvis ? 0.7 : 1.1);

      // Для Jarvis ищем самый мужской голос в системе (фолбэк если нет OpenAI ключа)
      if (persona == PersonaType.jarvis) {
        try {
          final voices = await _tts.getVoices;
          if (voices != null) {
            String? bestVoice;
            for (final v in voices) {
              final name = v.toString().toLowerCase();
              if (name.contains('ru')) {
                if (name.contains('male') || name.contains('муж')) {
                  bestVoice = v.toString();
                  break;
                }
                if (bestVoice == null && (name.contains('male') || name.contains('-m') || name.contains('mru'))) {
                  bestVoice = v.toString();
                }
              }
            }
            if (bestVoice != null) {
              await _tts.setVoice({'name': bestVoice, 'locale': 'ru-RU'});
            }
          }
        } catch (_) {}
      }

      _tts.setStartHandler(() => _speaking = true);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setErrorHandler((_) => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);
      _initialized = true;
    } else {
      await _tts.setSpeechRate(persona == PersonaType.jarvis ? 0.42 : 0.44);
      await _tts.setPitch(persona == PersonaType.jarvis ? 0.7 : 1.1);
    }
  }

  /// Проверка — есть ли OpenAI ключ (для JARVIS TTS)
  Future<bool> _hasOpenAiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('openai_key') ?? '').isNotEmpty;
  }

  /// Произнести текст
  /// JARVIS → OpenAI TTS (Onyx), остальные → FlutterTts (локальный)
  Future<void> speak(String text, PersonaType persona) async {
    if (text.trim().isEmpty) return;

    // Очищаем текст
    final clean = _clean(text);
    if (clean.isEmpty) return;

    // Если уже говорит — останавливаем
    if (_speaking) await stop();

    _speaking = true;

    // ── JARVIS → OpenAI TTS с голосом Onyx ──────────────────────
    if (persona == PersonaType.jarvis) {
      final hasKey = await _hasOpenAiKey();
      if (hasKey) {
        _usingOpenAi = true;
        try {
          await _openaiTts.init();
          _openaiTts.onSpeakingChanged = (speaking) {
            _speaking = speaking;
          };
          await _openaiTts.speak(clean);
          return;
        } catch (_) {
          // Если OpenAI TTS упал — фолбэк на локальный
          _usingOpenAi = false;
        }
      }
    }

    // ── Фолбэк / не-JARVIS → локальный FlutterTts ───────────────
    _usingOpenAi = false;
    await _initLocal(persona);
    await _tts.speak(clean);
  }

  /// Остановить
  Future<void> stop() async {
    _speaking = false;
    if (_usingOpenAi) {
      await _openaiTts.stop();
    } else {
      await _tts.stop();
    }
  }

  /// Очистка текста от markdown и лишних символов
  String _clean(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'\1')
        .replaceAll(RegExp(r'`(.+?)`'), r'\1')
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'[-•]\s'), '')
        .replaceAll(RegExp(r'\n{2,}'), '. ')
        .replaceAll('\n', ', ')
        .trim();
  }

  void dispose() {
    _tts.stop();
    _openaiTts.stop();
  }
}
