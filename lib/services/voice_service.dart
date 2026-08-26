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

  // Callbacks for normal listening
  void Function(String)? _lastOnResult;
  void Function(String)? _lastOnPartial;

  // ── Wake word detection ──
  bool _wakeWordMode = false;
  Timer? _wakeRestartTimer;
  Timer? _watchdogTimer;
  static const _wakeWords = ['джарвис', 'jarvis', 'айка', 'aika', 'аири', 'airi', 'джарвес', 'жарвис', 'айри', 'ари'];
  void Function()? onWakeWordDetected;

  bool get isListening => _listening;
  bool get isWakeWordMode => _wakeWordMode;
  String get partialText => _partialText;

  Future<bool> init() async {
    if (_initialized) return true;
    if (Platform.isWindows) {
      _initialized = false;
      return false;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    _initialized = await _stt.initialize(
      onError: (e) {
        debugPrint('[Voice] onError: ${e.permanent}');
        _listening = false;
        _errorCount++;
        // ALWAYS retry — never give up on wake word mode
        if (_wakeWordMode) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(milliseconds: 500), () {
            _startWakeWordLoop();
          });
        } else if (!e.permanent && _errorCount < 10) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(milliseconds: 800), _retryRelisten);
        }
      },
      onStatus: (status) {
        debugPrint('[Voice] status: $status');
        if (status == SpeechToText.notListeningStatus) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_listening && !_stt.isListening) {
              _listening = false;
              if (_wakeWordMode) {
                _wakeRestartTimer?.cancel();
                _wakeRestartTimer = Timer(const Duration(milliseconds: 100), _startWakeWordLoop);
              }
            }
          });
        }
      },
    );

    // Start watchdog — checks every 2 seconds if STT is alive
    if (_initialized && _watchdogTimer == null) {
      _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_wakeWordMode && !_listening && !_stt.isListening) {
          debugPrint('[Voice] watchdog: STT dead, restarting...');
          _startWakeWordLoop();
        }
      });
    }

    return _initialized;
  }

  void _retryRelisten() {
    if (_lastOnResult == null) return;
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
        final text = r.recognizedWords.trim().toLowerCase();
        debugPrint('[Voice] wake word check: "$text"');
        for (final word in _wakeWords) {
          if (text.contains(word)) {
            debugPrint('[Voice] WAKE WORD DETECTED: $word');
            onWakeWordDetected?.call();
            return;
          }
        }
        // Not a wake word — restart immediately
        _wakeRestartTimer?.cancel();
        _wakeRestartTimer = Timer(const Duration(milliseconds: 50), _startWakeWordLoop);
      } else {
        _lastOnResult?.call(r.recognizedWords.trim());
      }
    }
  }

  // ── Wake Word Mode — aggressive continuous listening ──
  Future<bool> startWakeWordMode() async {
    final ready = await init();
    if (!ready) return false;
    _wakeWordMode = true;
    _errorCount = 0;
    _startWakeWordLoop();
    debugPrint('[Voice] wake word mode started — watchdog active');
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
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(seconds: 15),
      partialResults: true,
    );
  }

  void stopWakeWordMode() {
    _wakeWordMode = false;
    _wakeRestartTimer?.cancel();
    _wakeRestartTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
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

    if (_wakeWordMode) {
      _wakeRestartTimer?.cancel();
      _wakeRestartTimer = Timer(const Duration(milliseconds: 300), _startWakeWordLoop);
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _wakeRestartTimer?.cancel();
    _watchdogTimer?.cancel();
    _wakeWordMode = false;
    _stt.cancel();
  }
}
