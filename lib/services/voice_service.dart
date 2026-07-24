import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _listening    = false;
  String _partialText = '';
  int _errorCount     = 0;
  Timer? _retryTimer;

  bool get isListening => _listening;
  String get partialText => _partialText;

  /// Инициализация — вызывается один раз, возвращает true если готов
  Future<bool> init() async {
    if (_initialized) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    _initialized = await _stt.initialize(
      onError: (e) {
        debugPrint('[Voice] onError: \${e.errorMsgPermanent}');
        _listening   = false;
        _partialText = '';
        _errorCount++;
        // На persistent errors — не пытаемся retry
        if (e.errorMsgPermanent) return;
        // На временных ошибках — retry через 800ms
        if (_errorCount < 3) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(milliseconds: 800), () {
            _retryRelisten();
          });
        }
      },
      onStatus: (status) {
        debugPrint('[Voice] status: $status');
        // listening -> notListening = STT закончил фразу
        if (status == SpeechToText.notListeningStatus) {
          // Не сбрасываем сразу — даём onResult шанс прийти
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_listening && !_stt.isListening) {
              _listening = false;
            }
          });
        }
      },
    );
    return _initialized;
  }

  // Retry после временной ошибки
  void Function(String)? _lastOnResult;
  void Function(String)? _lastOnPartial;

  void _retryRelisten() {
    if (_lastOnResult == null) return;
    debugPrint('[Voice] retry listen...');
    _stt.listen(
      onResult: _onResult,
      localeId: 'ru_RU',
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(milliseconds: 2000),
      listenFor: const Duration(seconds: 20),
      partialResults: true,
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    _partialText = r.recognizedWords;
    _lastOnPartial?.call(r.recognizedWords);

    if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
      _listening   = false;
      _partialText = '';
      _errorCount  = 0;
      _lastOnResult?.call(r.recognizedWords.trim());
    }
  }

  /// Начать слушать.
  /// [onResult]   — вызывается с финальным текстом.
  /// [onPartial]  — вызывается с промежуточным текстом.
  Future<bool> startListening({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
  }) async {
    if (_listening) return false;
    final ready = await init();
    if (!ready) return false;

    _listening   = true;
    _partialText = '';
    _errorCount  = 0;
    _lastOnResult   = onResult;
    _lastOnPartial  = onPartial;

    await _stt.listen(
      onResult: _onResult,
      localeId: 'ru_RU',
      listenMode: ListenMode.dictation,
      // пауза 2с после последнего слова — больше времени на подумать
      pauseFor: const Duration(milliseconds: 2000),
      // максимум 20 секунд
      listenFor: const Duration(seconds: 20),
      partialResults: true,
    );

    return true;
  }

  /// Принудительная остановка
  Future<void> stopListening() async {
    _listening   = false;
    _partialText = '';
    _retryTimer?.cancel();
    await _stt.stop();
  }

  void dispose() {
    _retryTimer?.cancel();
    _stt.cancel();
  }
}

