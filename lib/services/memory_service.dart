import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// MemoryService — локальная SQLite память AIRI.
/// Хранит историю диалогов и факты о пользователе.
class MemoryService {
  static final MemoryService _instance = MemoryService._();
  factory MemoryService() => _instance;
  MemoryService._();

  Database? _db;
  bool get isReady => _db != null;

  Future<void> init() async {
    if (_db != null) return;
    try {
      final dbPath = await getDatabasesPath();
      _db = await openDatabase(
        p.join(dbPath, 'airi_memory.db'),
        version: 1,
        onCreate: (db, v) async {
          await db.execute(
            "CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, role TEXT NOT NULL, content TEXT NOT NULL, persona TEXT, created_at INTEGER NOT NULL)"
          );
          await db.execute(
            "CREATE TABLE facts (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT NOT NULL, value TEXT NOT NULL, created_at INTEGER NOT NULL, UNIQUE(key))"
          );
          await db.execute(
            "CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, started_at INTEGER NOT NULL, ended_at INTEGER)"
          );
        },
      );
      debugPrint('[Memory] SQLite ready');
    } catch (e) {
      debugPrint('[Memory] init error: $e');
    }
  }

  // ── Сообщения ──────────────────────────────────────────────────

  Future<void> addMessage(String role, String content, {String? persona}) async {
    if (_db == null) return;
    try {
      await _db!.insert('messages', {
        'role': role,
        'content': content,
        'persona': persona,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[Memory] save message error: $e');
    }
  }

  Future<List<Map<String, String>>> getRecentMessages({int limit = 20}) async {
    if (_db == null) return [];
    try {
      final rows = await _db!.query('messages', columns: ['role', 'content'], orderBy: 'id DESC', limit: limit);
      return rows.reversed.map((r) => {'role': r['role'] as String, 'content': r['content'] as String}).toList();
    } catch (e) {
      debugPrint('[Memory] load messages error: $e');
      return [];
    }
  }

  Future<void> clearMessages() async {
    if (_db == null) return;
    await _db!.delete('messages');
  }

  // ── Факты ──────────────────────────────────────────────────────

  Future<void> setFact(String key, String value) async {
    if (_db == null) return;
    try {
      await _db!.insert('facts', {'key': key, 'value': value, 'created_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('[Memory] fact saved: $key = $value');
    } catch (e) {
      debugPrint('[Memory] save fact error: $e');
    }
  }

  Future<Map<String, String>> getAllFacts() async {
    if (_db == null) return {};
    try {
      final rows = await _db!.query('facts', columns: ['key', 'value']);
      return {for (var r in rows) r['key'] as String: r['value'] as String};
    } catch (e) {
      return {};
    }
  }

  Future<void> removeFact(String key) async {
    if (_db == null) return;
    await _db!.delete('facts', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> clearFacts() async {
    if (_db == null) return;
    await _db!.delete('facts');
  }

  // ── Сводка для AI ──────────────────────────────────────────────

  Future<String> getMemorySummary() async {
    final facts = await getAllFacts();
    if (facts.isEmpty) return '';
    final factLines = facts.entries.map((e) => '- ' + e.key + ': ' + e.value).join('\n');
    return '\n\nЧто ты знаёшь о пользователе:\n' + factLines;
  }

  Future<void> clearAll() async {
    await clearMessages();
    await clearFacts();
  }

  Future<Map<String, int>> getStats() async {
    if (_db == null) return {'messages': 0, 'facts': 0};
    try {
      final msgCount = Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM messages')) ?? 0;
      final factCount = Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM facts')) ?? 0;
      return {'messages': msgCount, 'facts': factCount};
    } catch (_) {
      return {'messages': 0, 'facts': 0};
    }
  }

  void dispose() {
    _db?.close();
    _db = null;
  }
}
