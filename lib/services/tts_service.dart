import 'package:flutter_tts/flutter_tts.dart';
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

  Future<void> _initLocal(PersonaType persona) async {
    if (!_initialized) {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(persona == PersonaType.jarvis ? 0.42 : 0.44);
      await _tts.setVolume(1.0);
      await _tts.setPitch(persona == PersonaType.jarvis ? 0.7 : 1.1);

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

  Future<bool> _hasOpenAiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('openai_key') ?? '').isNotEmpty;
  }

  /// Произнести текст.
  /// JARVIS → OpenAI TTS (Onyx) с фолбэком на локальный TTS.
  /// Остальные → локальный FlutterTts.
  Future<void> speak(String text, PersonaType persona) async {
    if (text.trim().isEmpty) return;

    final clean = _clean(text);
    if (clean.isEmpty) return;

    if (_speaking) await stop();

    // ── JARVIS → пытаемся OpenAI TTS ─────────────────────────
    if (persona == PersonaType.jarvis) {
      final hasKey = await _hasOpenAiKey();
      if (hasKey) {
        _usingOpenAi = true;
        _speaking = true;
        try {
          await _openaiTts.init();
          _openaiTts.onSpeakingChanged = (speaking) {
            _speaking = speaking;
          };
          await _openaiTts.speak(clean);
          // Если OpenAI TTS начал говорить — выходим
          if (_openaiTts.isSpeaking) return;
          // Иначе — фолбэк на локальный
        } catch (_) {
          // OpenAI TTS упал — фолбэк на локальный
        }
        _usingOpenAi = false;
        _speaking = false;
      }
    }

    // ── Локальный FlutterTts (фолбэк или не-JARVIS) ──────────
    _usingOpenAi = false;
    await _initLocal(persona);
    await _tts.speak(clean);
  }

  Future<void> stop() async {
    _speaking = false;
    if (_usingOpenAi) {
      await _openaiTts.stop();
    } else {
      await _tts.stop();
    }
  }

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
