import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  bool get isListening => _listening;

  /// Инициализация — вызывается один раз
  Future<bool> init() async {
    if (_initialized) return true;

    // Запрашиваем разрешение
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    _initialized = await _stt.initialize(
      onError: (_) => _listening = false,
    );
    return _initialized;
  }

  /// Начать слушать. [onResult] вызывается с текстом.
  Future<void> startListening(void Function(String text) onResult) async {
    if (_listening) return;
    final ready = await init();
    if (!ready) return;

    _listening = true;
    await _stt.listen(
      onResult: (r) {
        if (r.finalResult && r.recognizedWords.isNotEmpty) {
          onResult(r.recognizedWords);
        }
      },
      localeId: 'ru_RU',
      listenMode: ListenMode.confirmation,
      pauseFor: const Duration(seconds: 2),
    );
  }

  /// Остановить
  Future<void> stopListening() async {
    _listening = false;
    await _stt.stop();
  }

  void dispose() {
    _stt.cancel();
  }
}
