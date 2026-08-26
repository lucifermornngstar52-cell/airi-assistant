import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// VoiceService — non-intrusive speech recognition.
/// Does NOT interfere with calls, recordings, or other audio apps.
/// No aggressive watchdog — uses long listen periods and gentle restart.
class VoiceService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _listening = false;
  String _partialText = '';
  int _errorCount = 0;
  Timer? _retryTimer;

  // Audio state — pause STT during calls or when other apps need audio
  bool _audioPaused = false;
  static const _audioChannel = MethodChannel('com.airi.assistant/audio');

  // Callbacks for normal listening
  void Function(String)? _lastOnResult;
  void Function(String)? _lastOnPartial;

  // ── Wake word detection ──
  bool _wakeWordMode = false;
  Timer? _wakeRestartTimer;
  static const _wakeWords = ['джарвис', 'jarvis', 'айка', 'aika', 'аири', 'airi', 'джарвес', 'жарвис', 'айри', 'ари'];
  void Function()? onWakeWordDetected;

  bool get isListening => _listening;
  bool get isWakeWordMode => _wakeWordMode;
  String get partialText => _partialText;
  bool get audioPaused => _audioPaused;

  Future<bool> init() async {
    if (_initialized) return true;
    if (Platform.isWindows) {
      _initialized = false;
      return false;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    // Listen for audio focus changes from native side (call detection, etc.)
    _audioChannel.setMethodCallHandler((call) async {
      if (call.method == 'audioFocusLost') {
        _audioPaused = true;
        _pauseListening();
        debugPrint('[Voice] Audio focus lost — pausing STT');
      } else if (call.method == 'audioFocusGained') {
        _audioPaused = false;
        debugPrint('[Voice] Audio focus regained — resuming STT');
        if (_wakeWordMode) {
          _wakeRestartTimer?.cancel();
          _wakeRestartTimer = Timer(const Duration(seconds: 1), _startWakeWordLoop);
        }
      }
    });

    _initialized = await _stt.initialize(
      onError: (e) {
        debugPrint('[Voice] onError: ${e.permanent}');
        _listening = false;
        _errorCount++;
        if (e.permanent) return; // Don't retry permanent errors
        if (_audioPaused) return; // Don't retry if audio is paused
        if (_wakeWordMode) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 3), _startWakeWordLoop);
        } else if (_errorCount < 5 && _lastOnResult != null) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 2), _retryRelisten);
        }
      },
      onStatus: (status) {
        debugPrint('[Voice] status: $status');
        if (status == SpeechToText.notListeningStatus) {
          Future.delayed(const Duration(seconds: 1), () {
            if (_listening && !_stt.isListening && !_audioPaused) {
              _listening = false;
              if (_wakeWordMode) {
                _wakeRestartTimer?.cancel();
                _wakeRestartTimer = Timer(const Duration(seconds: 1), _startWakeWordLoop);
              }
            }
          });
        }
      },
    );

    return _initialized;
  }

  void _pauseListening() {
    if (_stt.isListening) {
      _stt.stop();
    }
    _listening = false;
  }

  void _retryRelisten() {
    if (_lastOnResult == null || _audioPaused) return;
    _stt.listen(
      onResult: _onResult,
      localeId: 'ru_RU',
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
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
        // Not a wake word — restart after a short delay
        _wakeRestartTimer?.cancel();
        _wakeRestartTimer = Timer(const Duration(seconds: 1), _startWakeWordLoop);
      } else {
        _lastOnResult?.call(r.recognizedWords.trim());
      }
    }
  }

  // ── Wake Word Mode — gentle, non-intrusive ──
  Future<bool> startWakeWordMode() async {
    final ready = await init();
    if (!ready) return false;
    _wakeWordMode = true;
    _errorCount = 0;
    _startWakeWordLoop();
    debugPrint('[Voice] wake word mode started — gentle monitoring');
    return true;
  }

  void _startWakeWordLoop() {
    if (!_wakeWordMode || !_initialized || _audioPaused) return;
    if (_stt.isListening) return;
    _listening = true;
    _partialText = '';
    // Long listen duration — don't cycle rapidly
    _stt.listen(
      onResult: _onResult,
      localeId: 'ru_RU',
      listenMode: ListenMode.search,
      pauseFor: const Duration(seconds: 5),
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
    if (_audioPaused) return false;

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
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
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
      _wakeRestartTimer = Timer(const Duration(seconds: 2), _startWakeWordLoop);
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _wakeRestartTimer?.cancel();
    _wakeWordMode = false;
    _stt.cancel();
  }
}
