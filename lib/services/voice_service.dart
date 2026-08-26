import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _listening = false;
  String _partialText = '';
  int _errorCount = 0;
  Timer? _retryTimer;

  // ── Wake word detection ──
  bool _wakeWordMode = false;
  Timer? _wakeRestartTimer;
  static const _wakeWords = ['джарвис', 'jarvis', 'айка', 'aika', 'аири', 'airi', 'джарвес', 'жарвис'];
  void Function()? onWakeWordDetected;

  bool get isListening => _listening;
  bool get isWakeWordMode => _wakeWordMode;
  String get partialText => _partialText;

  Future<bool> init() async {
    if (_initialized) return true;
    if (Platform.isWindows) {
      _initialized = false;
      debugPrint('[Voice] STT not available on Windows');
      return false;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
    _initialized = await _stt.initialize(
      onError: (e) {
        debugPrint('[Voice] onError: ${e.permanent}');
        _listening = false;
        _partialText = '';
        _errorCount++;
        if (e.permanent) return;
        if (_errorCount < 5) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(milliseconds: 800), () {
            if (_wakeWordMode) {
              _startWakeWordLoop();
            } else {
              _retryRelisten();
            }
          });
        } else {
          // Reset and try again after longer delay
          _errorCount = 0;
          _retryTimer = Timer(const Duration(seconds: 3), () {
            if (_wakeWordMode) _startWakeWordLoop();
          });
        }
      },
      onStatus: (status) {
        debugPrint('[Voice] status: $status');
        if (status == SpeechToText.notListeningStatus) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_listening && !_stt.isListening) {
              _listening = false;
              // In wake word mode, restart listening immediately
              if (_wakeWordMode) {
                _wakeRestartTimer?.cancel();
                _wakeRestartTimer = Timer(const Duration(milliseconds: 200), _startWakeWordLoop);
              }
            }
          });
        }
      },
    );
    return _initialized;
  }

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

  void _onResult(r) {
    _partialText = r.recognizedWords;
    _lastOnPartial?.call(r.recognizedWords);

    if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
      _listening = false;
      _partialText = '';
      _errorCount = 0;

      if (_wakeWordMode) {
        // Check for wake word
        final text = r.recognizedWords.trim().toLowerCase();
        debugPrint('[Voice] wake word check: "$text"');
        for (final word in _wakeWords) {
          if (text.contains(word)) {
            debugPrint('[Voice] WAKE WORD DETECTED: $word');
            onWakeWordDetected?.call();
            return;
          }
        }
        // Not a wake word — restart loop
        _wakeRestartTimer?.cancel();
        _wakeRestartTimer = Timer(const Duration(milliseconds: 200), _startWakeWordLoop);
      } else {
        _lastOnResult?.call(r.recognizedWords.trim());
      }
    }
  }

  // ── Wake Word Mode ──
  Future<bool> startWakeWordMode() async {
    final ready = await init();
    if (!ready) return false;
    _wakeWordMode = true;
    _startWakeWordLoop();
    debugPrint('[Voice] wake word mode started');
    return true;
  }

  void _startWakeWordLoop() {
    if (!_wakeWordMode || !_initialized) return;
    if (_stt.isListening) return;
    _listening = true;
    _partialText = '';
    _stt.listen(
      onResult: _onResult,
      localeId: 'ru_RU',
      listenMode: ListenMode.search,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      partialResults: true,
    );
  }

  void stopWakeWordMode() {
    _wakeWordMode = false;
    _wakeRestartTimer?.cancel();
    _wakeRestartTimer = null;
    _listening = false;
    _stt.stop();
    debugPrint('[Voice] wake word mode stopped');
  }

  Future<bool> startListening({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
  }) async {
    if (_listening) return false;
    final ready = await init();
    if (!ready) return false;

    // Stop wake word mode while in conversation
    if (_wakeWordMode) {
      _stt.stop();
    }

    _listening = true;
    _partialText = '';
    _errorCount = 0;
    _lastOnResult = onResult;
    _lastOnPartial = onPartial;

    await _stt.listen(
      onResult: _onResult,
      localeId: 'ru_RU',
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(milliseconds: 2000),
      listenFor: const Duration(seconds: 20),
      partialResults: true,
    );

    return true;
  }

  Future<void> stopListening() async {
    _listening = false;
    _partialText = '';
    _retryTimer?.cancel();
    await _stt.stop();

    // Resume wake word mode if it was active
    if (_wakeWordMode) {
      _wakeRestartTimer?.cancel();
      _wakeRestartTimer = Timer(const Duration(milliseconds: 500), _startWakeWordLoop);
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _wakeRestartTimer?.cancel();
    _wakeWordMode = false;
    _stt.cancel();
  }
}
