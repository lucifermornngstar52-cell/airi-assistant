import 'package:flutter_tts/flutter_tts.dart';
import '../models/character_persona.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking    = false;

  bool get isSpeaking => _speaking;

  Future<void> _init(PersonaType persona) async {
    if (!_initialized) {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(persona == PersonaType.jarvis ? 0.48 : 0.44);
      await _tts.setVolume(1.0);
      await _tts.setPitch(persona == PersonaType.jarvis ? 0.85 : 1.1);

      _tts.setStartHandler(() => _speaking = true);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setErrorHandler((_) => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);

      _initialized = true;
    } else {
      // При смене персонажа обновляем параметры голоса
      await _tts.setSpeechRate(persona == PersonaType.jarvis ? 0.48 : 0.44);
      await _tts.setPitch(persona == PersonaType.jarvis ? 0.85 : 1.1);
    }
  }

  /// Произнести текст
  Future<void> speak(String text, PersonaType persona) async {
    if (text.trim().isEmpty) return;
    await _init(persona);

    // Если уже говорит — останавливаем и начинаем новый текст
    if (_speaking) await stop();

    // Убираем markdown-символы которые не нужно читать вслух
    final clean = _clean(text);
    if (clean.isEmpty) return;

    _speaking = true;
    await _tts.speak(clean);
  }

  /// Остановить
  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }

  /// Очистка текста от markdown и лишних символов
  String _clean(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1') // **bold**
        .replaceAll(RegExp(r'\*(.+?)\*'), r'\1')      // *italic*
        .replaceAll(RegExp(r'`(.+?)`'), r'\1')         // `code`
        .replaceAll(RegExp(r'#+\s'), '')                // # headers
        .replaceAll(RegExp(r'[-•]\s'), '')              // list bullets
        .replaceAll(RegExp(r'\n{2,}'), '. ')            // double newlines
        .replaceAll('\n', ', ')
        .trim();
  }

  void dispose() {
    _tts.stop();
  }
}
