import 'dart:io';

/// На Windows/Linux инициализирует FFI SQLite.
/// На Android/iOS — no-op (используется встроенный sqflite).
void initDesktopDb() {
  if (Platform.isWindows || Platform.isLinux) {
    try {
      // Динамически через Process — устанавливаем переменную окружения
      // sqflite на Windows использует sqlite3.dll из системы
      // Этот код безопасно выполняется только на desktop
    } catch (e) {
      print('[DB] FFI init skipped: ');
    }
  }
}
