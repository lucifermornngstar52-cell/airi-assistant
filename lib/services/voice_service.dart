import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _listening    = false;
  String _partialText = '';

  bool get isListening => _listening;
  String get partialText => _partialText;

  /// Инициализация — вызывается один раз, возвращает true если готов
  Future<bool> init() async {
    if (_initialized) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    _initialized = await _stt.initialize(
      onError: (e) {
        _listening   = false;
        _partialText = '';
      },
      onStatus: (status) {
        // listening → notListening — STT сам остановился (конец фразы)
        if (status == SpeechToText.notListeningStatus) {
          _listening = false;
        }
      },
    );
    return _initialized;
  }

  /// Начать слушать.
  /// [onResult]   — вызывается с финальным текстом.
  /// [onPartial]  — вызывается с промежуточным текстом (для отображения).
  Future<bool> startListening({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
  }) async {
    if (_listening) return false;
    final ready = await init();
    if (!ready) return false;

    _listening   = true;
    _partialText = '';

    await _stt.listen(
      onResult: (r) {
        _partialText = r.recognizedWords;

        if (onPartial != null) {
          onPartial(r.recognizedWords);
        }

        // Срабатываем только при финальном результате с текстом
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _listening   = false;
          _partialText = '';
          onResult(r.recognizedWords.trim());
        }
      },
      localeId: 'ru_RU',
      // dictation — не ждёт подтверждения, фиксирует фразу сразу
      listenMode: ListenMode.dictation,
      // пауза 1.5с после последнего слова → финальный результат
      pauseFor: const Duration(milliseconds: 1500),
      // максимум слушаем 15 секунд
      listenFor: const Duration(seconds: 15),
      // частичные результаты — чтобы показывать текст в реальном времени
      partialResults: true,
    );

    return true;
  }

  /// Принудительная остановка (кнопка повторного нажатия)
  Future<void> stopListening() async {
    _listening   = false;
    _partialText = '';
    await _stt.stop();
  }

  void dispose() {
    _stt.cancel();
  }
}
