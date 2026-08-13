import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class VisionService {
  static final VisionService _instance = VisionService._();
  factory VisionService() => _instance;
  VisionService._();

  final _picker = ImagePicker();

  /// Сделать фото с камеры (задняя камера)
  Future<File?> capturePhoto() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xfile == null) return null;
      return File(xfile.path);
    } catch (e) {
      debugPrint('[Vision] camera error: $e');
      return null;
    }
  }

  /// Сделать фото с фронтальной камеры
  Future<File?> captureFrontPhoto() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 30,
      );
      if (xfile == null) return null;
      return File(xfile.path);
    } catch (e) {
      debugPrint('[Vision] front camera error: $e');
      return null;
    }
  }

  /// Выбрать из галереи
  Future<File?> pickFromGallery() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xfile == null) return null;
      return File(xfile.path);
    } catch (e) {
      debugPrint('[Vision] gallery error: $e');
      return null;
    }
  }

  /// Конвертировать файл в base64
  Future<String> _toBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// Определить MIME тип
  String _mimeType(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Отправить фото + текст в GPT-4o-mini Vision
  /// [prompt] — что спросить про фото
  /// Возвращает текстовый ответ
  Future<String> analyzeImage(File image, String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) {
      return '⚠️ Укажи OpenAI API Key в Настройках → Провайдеры';
    }

    final base64Image = await _toBase64(image);
    final mime = _mimeType(image);

    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt,
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mime;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'max_tokens': 800,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['choices'][0]['message']['content']?.trim() ?? '...';
      } else {
        return '❌ Ошибка ${res.statusCode}';
      }
    } catch (e) {
      return '❌ Нет соединения: $e';
    }
  }

  /// Анализ эмоций с фронтальной камеры
  /// Возвращает короткий текст описания эмоции, или null если лицо не найдено
  Future<String?> analyzeEmotion(File image) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_key') ?? '';
    if (apiKey.isEmpty) return null;

    final base64Image = await _toBase64(image);
    final mime = _mimeType(image);

    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': 'Ты — анализатор эмоций. Опиши эмоцию человека на фото одним-двумя словами на русском. Только эмоцию, без лишних слов. Например: улыбается, задумчив, устал, радостный, раздражён, спокоен, удивлён. Если лица нет — ответь: нет лица.',
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Какая эмоция у человека на этом фото?',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mime;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'max_completion_tokens': 50,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final result = data['choices'][0]['message']['content']?.trim() ?? '';
        if (result.toLowerCase().contains('нет лица') || result.toLowerCase().contains('нет человека')) {
          return null;
        }
        return result;
      }
      // Логируем тело ответа при ошибке
      final errBody = utf8.decode(res.bodyBytes);
      debugPrint('[Vision] emotion API ${res.statusCode}: $errBody');
      return null;
    } catch (e) {
      debugPrint('[Vision] emotion error: $e');
      return null;
    }
  }
}
