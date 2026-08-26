import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OpenAiTtsService — TTS через OpenAI Audio API.
/// Голос "onyx" — JARVIS-стиль (мужской, спокойный).
class OpenAiTtsService {
  static OpenAiTtsService? _instance;
  factory OpenAiTtsService() => _instance ??= OpenAiTtsService._internal();
  OpenAiTtsService._internal();

  static const _keyOpenAi = 'openai_key';
  static const _keyVoice = 'openai_tts_voice';
  static const _keyModel = 'openai_tts_model';
  static const _keySpeed = 'openai_tts_speed';

  static const _defaultVoice = 'onyx';
  static const _defaultModel = 'tts-1-hd';
  static const _defaultSpeed = 1.0;

  String _apiKey = '';
  String _voice = _defaultVoice;
  String _model = _defaultModel;
  double _speed = _defaultSpeed;
  bool _initialized = false;

  final AudioPlayer _player = AudioPlayer();
  bool _speaking = false;
  bool get isSpeaking => _speaking;

  /// Колбэк изменения состояния речи
  void Function(bool speaking)? onSpeakingChanged;

  void _setSpeaking(bool v) {
    _speaking = v;
    onSpeakingChanged?.call(v);
  }

  static const voices = [
    {'id': 'onyx',    'label': 'Onyx (JARVIS)'},
    {'id': 'echo',    'label': 'Echo'},
    {'id': 'fable',   'label': 'Fable'},
    {'id': 'alloy',   'label': 'Alloy'},
    {'id': 'nova',    'label': 'Nova'},
    {'id': 'shimmer', 'label': 'Shimmer'},
  ];

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_keyOpenAi) ?? '';
    _voice = prefs.getString(_keyVoice) ?? _defaultVoice;
    _model = prefs.getString(_keyModel) ?? _defaultModel;
    _speed = prefs.getDouble(_keySpeed) ?? _defaultSpeed;
    _player.onPlayerComplete.listen((_) => _setSpeaking(false));
    _initialized = true;
  }

  void setApiKey(String k) => _apiKey = k;
  void setVoice(String v) => _voice = v;
  void setModel(String m) => _model = m;
  void setSpeed(double s) => _speed = s;

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenAi, _apiKey);
    await prefs.setString(_keyVoice, _voice);
    await prefs.setString(_keyModel, _model);
    await prefs.setDouble(_keySpeed, _speed);
  }

  Future<void> speak(String text) async {
    if (_apiKey.isEmpty) {
      _setSpeaking(false);
      return;
    }
    if (text.trim().isEmpty) return;
    await init();
    _setSpeaking(true);
    try {
      final resp = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'input': text,
          'voice': _voice,
          'response_format': 'mp3',
          'speed': _speed,
        }),
      );
      if (resp.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/jarvis_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(resp.bodyBytes);
        await _player.play(DeviceFileSource(file.path));
      } else {
        _setSpeaking(false);
      }
    } catch (_) {
      _setSpeaking(false);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _setSpeaking(false);
  }
}
