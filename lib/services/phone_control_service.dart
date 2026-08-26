import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// PhoneControlService — bridge to native AccessibilityService.
/// Allows JARVIS to fully control the phone: tap, type, scroll, navigate.
class PhoneControlService {
  static const _channel = MethodChannel('com.airi.assistant/accessibility');

  static Future<bool> tapAt(double x, double y) async {
    try {
      return await _channel.invokeMethod('tapAt', {'x': x, 'y': y}) ?? false;
    } catch (e) {
      debugPrint('[PhoneControl] tapAt error: $e');
      return false;
    }
  }

  static Future<bool> clickByText(String text) async {
    try {
      return await _channel.invokeMethod('clickByText', {'text': text}) ?? false;
    } catch (e) {
      debugPrint('[PhoneControl] clickByText error: $e');
      return false;
    }
  }

  static Future<bool> clickById(String id) async {
    try {
      return await _channel.invokeMethod('clickById', {'id': id}) ?? false;
    } catch (e) {
      debugPrint('[PhoneControl] clickById error: $e');
      return false;
    }
  }

  static Future<bool> typeText(String text, {String? hint}) async {
    try {
      return await _channel.invokeMethod('typeText', {
        'text': text,
        if (hint != null) 'hint': hint,
      }) ?? false;
    } catch (e) {
      debugPrint('[PhoneControl] typeText error: $e');
      return false;
    }
  }

  static Future<bool> scrollDown() async {
    try {
      return await _channel.invokeMethod('scrollDown') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> scrollUp() async {
    try {
      return await _channel.invokeMethod('scrollUp') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> swipe(double sx, double sy, double ex, double ey) async {
    try {
      return await _channel.invokeMethod('swipe', {
        'startX': sx, 'startY': sy, 'endX': ex, 'endY': ey,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> pressBack() async {
    try {
      return await _channel.invokeMethod('pressBack') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> pressHome() async {
    try {
      return await _channel.invokeMethod('pressHome') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> pressRecents() async {
    try {
      return await _channel.invokeMethod('pressRecents') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<String> getScreenText() async {
    try {
      return await _channel.invokeMethod('getScreenText') ?? '';
    } catch (e) {
      return '';
    }
  }

  static Future<bool> executeCommand(String command) async {
    try {
      return await _channel.invokeMethod('executeCommand', {'command': command}) ?? false;
    } catch (e) {
      debugPrint('[PhoneControl] executeCommand error: $e');
      return false;
    }
  }

  /// Parse a user voice command and try to execute it as a phone action.
  /// Returns a response string if handled, null if not a phone command.
  static Future<String?> tryPhoneCommand(String text) async {
    final lower = text.toLowerCase().trim();

    // Navigation commands
    if (lower == 'назад' || lower.contains('вернись назад') || lower.contains('кнопка назад')) {
      final ok = await pressBack();
      return ok ? 'Возврат назад.' : null;
    }
    if (lower == 'домой' || lower.contains('на главный экран') || lower.contains('иди домой')) {
      final ok = await pressHome();
      return ok ? 'Возвращаюсь на главный экран.' : null;
    }
    if (lower.contains('недавние приложения') || lower == 'недавние') {
      final ok = await pressRecents();
      return ok ? 'Открываю недавние приложения.' : null;
    }
    if (lower.contains('листай вниз') || lower.contains('прокрути вниз') || lower.contains('скролл вниз')) {
      final ok = await scrollDown();
      return ok ? 'Прокрутка вниз.' : null;
    }
    if (lower.contains('листай вверх') || lower.contains('прокрути вверх') || lower.contains('скролл вверх')) {
      final ok = await scrollUp();
      return ok ? 'Прокрутка вверх.' : null;
    }

    // Click commands
    if (lower.startsWith('нажми ') || lower.startsWith('кликни ') || lower.startsWith('тапни ')) {
      final target = text.substring(
        lower.startsWith('нажми ') ? 6 : (lower.startsWith('кликни ') ? 7 : 6)
      ).trim();
      final ok = await clickByText(target);
      return ok ? 'Нажимаю: $target' : null;
    }

    // Type commands
    if (lower.startsWith('печата ') || lower.startsWith('введи ') || lower.startsWith('напиши текст ')) {
      final target = text.substring(
        lower.startsWith('печата ') ? 6 : (lower.startsWith('введи ') ? 5 : 12)
      ).trim();
      final ok = await typeText(target);
      return ok ? 'Ввожу текст.' : null;
    }

    return null;
  }
}
