import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../services/tts_service.dart';
import '../services/memory_service.dart';
import '../services/vision_service.dart';
import '../services/emotion_service.dart';
import 'persona_screen.dart';
import '../models/character_persona.dart';

// ═══════════════════════════════════════════════════════
// NEWS SCREEN — fetches real news via API
// ═══════════════════════════════════════════════════════
class NewsScreen extends StatefulWidget {
  const NewsScreen();
  @override State<NewsScreen> createState() => NewsScreenState();
}

class NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _news = [];
  bool _loading = true;
  String? _error;
  String _category = 'technology';

  final _categories = [
    ('Технологии', 'technology'),
    ('Мир', 'world'),
    ('Спорт', 'sports'),
    ('Экономика', 'business'),
    ('Наука', 'science'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Use Google News RSS → parse via free API
      final url = 'https://newsdata.io/api/1/news?category=$_category&language=ru&apikey=pub_0dummy';
      // Fallback: use a simple RSS feed
      final rssUrl = 'https://news.google.com/rss/search?q=$_category+when:1d&hl=ru&gl=KZ&ceid=KZ:ru';
      final response = await http.get(Uri.parse(rssUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        // Parse XML RSS items
        final body = response.body;
        final items = <Map<String, dynamic>>[];
        final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
        final titleRegex = RegExp(r'<title>(.*?)</title>');
        final linkRegex = RegExp(r'<link>(.*?)</link>');
        final dateRegex = RegExp(r'<pubDate>(.*?)</pubDate>');
        for (final match in itemRegex.allMatches(body)) {
          final item = match.group(1)!;
          final title = titleRegex.firstMatch(item)?.group(1) ?? '';
          final link = linkRegex.firstMatch(item)?.group(1) ?? '';
          final date = dateRegex.firstMatch(item)?.group(1) ?? '';
          if (title.isNotEmpty) {
            items.add({'title': title, 'link': link, 'date': date});
          }
          if (items.length >= 10) break;
        }
        setState(() { _news = items; _loading = false; });
      } else {
        // Fallback — AI generated news summary
        setState(() { _loading = false; _error = 'Не удалось загрузить ленту'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Ошибка: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Новости', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: AppTheme.textPrimary), onPressed: _fetchNews)],
      ),
      body: Column(children: [
        SizedBox(height: 44, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: _categories.map((c) {
            final selected = c.$2 == _category;
            return Padding(padding: const EdgeInsets.all(4),
              child: FilterChip(label: Text(c.$1), selected: selected,
                onSelected: (_) { setState(() => _category = c.$2); _fetchNews(); },
                backgroundColor: AppTheme.cardColor,
                selectedColor: AppTheme.accentBlue,
                labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary),
              ),
            );
          }).toList(),
        )),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accentBlue)))
        else if (_error != null)
          Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(20),
            child: Text(_error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)))))
        else
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _news.length,
            itemBuilder: (ctx, i) {
              final n = _news[i];
              return Card(color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(n['title'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(n['date'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  onTap: () {
                    final link = n['link'] as String?;
                    if (link != null && link.isNotEmpty) {
                      // Copy to clipboard
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ссылка скопирована')));
                    }
                  },
                ),
              );
            },
          )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// REMINDERS SCREEN — local reminders with SharedPreferences
// ═══════════════════════════════════════════════════════
class RemindersScreen extends StatefulWidget {
  const RemindersScreen();
  @override State<RemindersScreen> createState() => RemindersScreenState();
}

class RemindersScreenState extends State<RemindersScreen> {
  List<String> _reminders = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _reminders = prefs.getStringList('reminders') ?? []; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('reminders', _reminders);
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() { _reminders.insert(0, text); _controller.clear(); });
    _save();
  }

  void _remove(int i) {
    setState(() { _reminders.removeAt(i); });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Напоминания', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: TextField(controller: _controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Новое напоминание...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true, fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _add(),
            )),
            const SizedBox(width: 10),
            IconButton(onPressed: _add, icon: const Icon(Icons.add_circle, color: AppTheme.accentBlue, size: 32)),
          ]),
        ),
        Expanded(child: _reminders.isEmpty
          ? const Center(child: Text('Нет напоминаний', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reminders.length,
              itemBuilder: (ctx, i) => Card(
                color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined, color: AppTheme.accentBlue),
                  title: Text(_reminders[i], style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  trailing: IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => _remove(i)),
                ),
              ),
            ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SHOPPING LIST SCREEN — local shopping list
// ═══════════════════════════════════════════════════════
class ShopListScreen extends StatefulWidget {
  const ShopListScreen();
  @override State<ShopListScreen> createState() => ShopListScreenState();
}

class ShopListScreenState extends State<ShopListScreen> {
  List<Map<String, dynamic>> _items = [];
  final _controller = TextEditingController();
  String _category = 'Продукты';
  final _categories = ['Продукты', 'Быт', 'Прочее'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('shoplist') ?? '[]';
    setState(() { _items = List<Map<String, dynamic>>.from(jsonDecode(raw)); });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shoplist', jsonEncode(_items));
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add({'name': text, 'cat': _category, 'done': false});
      _controller.clear();
    });
    _save();
  }

  void _toggle(int i) {
    setState(() { _items[i]['done'] = !(_items[i]['done'] as bool); });
    _save();
  }

  void _remove(int i) {
    setState(() { _items.removeAt(i); });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Список покупок', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: _controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Добавить товар...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true, fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _add(),
              )),
              const SizedBox(width: 10),
              IconButton(onPressed: _add, icon: const Icon(Icons.add_circle, color: AppTheme.accentBlue, size: 32)),
            ]),
            const SizedBox(height: 8),
            Row(children: _categories.map((c) {
              final selected = c == _category;
              return Padding(padding: const EdgeInsets.only(right: 6),
                child: FilterChip(label: Text(c), selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  backgroundColor: AppTheme.cardColor, selectedColor: AppTheme.accentBlue,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary),
                ),
              );
            }).toList()),
          ]),
        ),
        Expanded(child: _items.isEmpty
          ? const Center(child: Text('Список пуст', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return Card(
                  color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Checkbox(value: item['done'] as bool, onChanged: (_) => _toggle(i),
                      activeColor: AppTheme.accentBlue),
                    title: Text(item['name'] as String,
                      style: TextStyle(color: (item['done'] as bool) ? AppTheme.textSecondary : AppTheme.textPrimary,
                        fontSize: 14, decoration: (item['done'] as bool) ? TextDecoration.lineThrough : null)),
                    subtitle: Text(item['cat'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    trailing: IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                      onPressed: () => _remove(i)),
                  ),
                );
              },
            ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// CLIPBOARD SCREEN — read/write clipboard
// ═══════════════════════════════════════════════════════
class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen();
  @override State<ClipboardScreen> createState() => ClipboardScreenState();
}

class ClipboardScreenState extends State<ClipboardScreen> {
  String _currentClip = '';
  List<String> _history = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _readClipboard();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _history = prefs.getStringList('clip_history') ?? []; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('clip_history', _history);
  }

  Future<void> _readClipboard() async {
    final data = await Clipboard.getData('text/plain');
    setState(() { _currentClip = data?.text ?? ''; _controller.text = _currentClip; });
  }

  Future<void> _copy() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    setState(() {
      _currentClip = text;
      _history.insert(0, text);
      if (_history.length > 50) _history = _history.sublist(0, 50);
    });
    _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скопировано в буфер')));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    setState(() { _currentClip = data?.text ?? ''; _controller.text = _currentClip; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Буфер обмена', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(controller: _controller, maxLines: 4,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Введите текст для копирования...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true, fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _copy, icon: const Icon(Icons.copy, size: 18), label: const Text('Копировать'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: _paste, icon: const Icon(Icons.paste, size: 18), label: const Text('Вставить'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardColor, foregroundColor: AppTheme.textPrimary),
              )),
            ]),
          ]),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('История', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)))),
        Expanded(child: _history.isEmpty
          ? const Center(child: Text('История пуста', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (ctx, i) => Card(
                color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(_history[i], style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () { setState(() { _controller.text = _history[i]; }); },
                  trailing: IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                    onPressed: () { setState(() { _history.removeAt(i); }); _save(); }),
                ),
              ),
            ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PERSONALITY SCREEN — shows AI personality state
// ═══════════════════════════════════════════════════════
class PersonalityScreen extends StatefulWidget {
  const PersonalityScreen();
  @override State<PersonalityScreen> createState() => PersonalityScreenState();
}

class PersonalityScreenState extends State<PersonalityScreen> {
  String _personaName = 'JARVIS';
  int _interactions = 0;
  String _mood = 'Нейтральный';
  String _lastActive = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _interactions = prefs.getInt('persona_interactions') ?? 0;
      _mood = prefs.getString('persona_mood') ?? 'Нейтральный';
      _lastActive = prefs.getString('persona_last_active') ?? '';
    });
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('persona_interactions', 0);
    await prefs.setString('persona_mood', 'Нейтральный');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 6 ? 'Ночь' : hour < 12 ? 'Утро' : hour < 18 ? 'День' : 'Вечер';
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Личность AI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.all(20),
        children: [
          _statCard('Персонаж', _personaName, Icons.person),
          _statCard('Взаимодействий', '$_interactions', Icons.chat_bubble),
          _statCard('Настроение', _mood, Icons.mood),
          _statCard('Время суток', timeOfDay, Icons.access_time),
          if (_lastActive.isNotEmpty) _statCard('Последняя активность', _lastActive, Icons.history),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('Сбросить состояние'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardColor, foregroundColor: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(leading: Icon(icon, color: AppTheme.accentBlue),
        title: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        subtitle: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// VOICE TEST SCREEN — test speech to text
// ═══════════════════════════════════════════════════════
class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen();
  @override State<VoiceTestScreen> createState() => VoiceTestScreenState();
}

class VoiceTestScreenState extends State<VoiceTestScreen> {
  final _voice = VoiceService();
  String _text = '';
  bool _listening = false;
  String _status = 'Готов';

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _voice.stopListening();
      setState(() { _listening = false; _status = 'Остановлен'; });
    } else {
      final ok = await _voice.startListening(
        onResult: (text) { setState(() { _text = text; _listening = false; _status = 'Готов'; }); },
        onPartial: (text) { setState(() { _text = text; }); },
      );
      setState(() { _listening = ok; _status = ok ? 'Слушаю...' : 'Ошибка инициализации'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Голосовой ввод', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Padding(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 40),
          Icon(_listening ? Icons.mic : Icons.mic_none, size: 80,
            color: _listening ? AppTheme.accentBlue : AppTheme.textSecondary),
          const SizedBox(height: 20),
          Text(_status, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
            child: Text(_text.isEmpty ? 'Нажмите кнопку и говорите' : _text,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
              textAlign: TextAlign.center),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _toggle,
            icon: Icon(_listening ? Icons.stop : Icons.mic),
            label: Text(_listening ? 'Стоп' : 'Начать'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _listening ? Colors.red : AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
          const SizedBox(height: 40),
          _infoCard(),
        ]),
      ),
    );
  }

  Widget _infoCard() {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Информация', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('• Движок: SpeechToText (speech_to_text)\n• Язык: ru-RU\n• Режим: Dictation\n• Пауза: 3 сек\n• Таймаут: 30 сек\n• Частичные результаты: включены',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TTS TEST SCREEN — test text-to-speech
// ═══════════════════════════════════════════════════════
class TtsTestScreen extends StatefulWidget {
  const TtsTestScreen();
  @override State<TtsTestScreen> createState() => TtsTestScreenState();
}

class TtsTestScreenState extends State<TtsTestScreen> {
  final _tts = TtsService();
  final _controller = TextEditingController(text: 'Сэр, все системы функционируют в штатном режиме.');
  bool _speaking = false;

  @override
  void dispose() {
    _tts.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    setState(() => _speaking = true);
    await _tts.speak(_controller.text, PersonaType.jarvis);
    setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Синтез речи', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Padding(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 30),
          Icon(_speaking ? Icons.record_voice_over : Icons.volume_up, size: 70,
            color: _speaking ? AppTheme.accentBlue : AppTheme.textSecondary),
          const SizedBox(height: 20),
          TextField(controller: _controller, maxLines: 4,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              filled: true, fillColor: AppTheme.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _speaking ? null : _speak,
            icon: Icon(_speaking ? Icons.hourglass_empty : Icons.play_arrow),
            label: Text(_speaking ? 'Воспроизведение...' : 'Озвучить (JARVIS)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
          const SizedBox(height: 30),
          _infoCard(),
        ]),
      ),
    );
  }

  Widget _infoCard() {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Параметры', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('• Движок: FlutterTTS\n• Язык: ru-RU\n• JARVIS: Speed 0.48, Pitch 0.85\n• Airi: Speed 0.44, Pitch 1.1\n• Oчистка: Markdown stripping',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// CHAT INFO SCREEN
// ═══════════════════════════════════════════════════════
class ChatInfoScreen extends StatelessWidget {
  const ChatInfoScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Чат с AI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.all(20),
        children: [
          _card('Провайдер', 'OpenAI API'),
          _card('Модель', 'gpt-5'),
          _card('Max tokens', '1000'),
          _card('Temperature', '0.85'),
          _card('Персонажи', 'JARVIS / Airi'),
          _card('Память', 'Последние 20 сообщений в контексте'),
          _card('Ключ', 'SharedPreferences (локально)'),
          const SizedBox(height: 20),
          const Card(
            color: AppTheme.cardColor,
            child: Padding(padding: EdgeInsets.all(16),
              child: Text('Чат доступен на главном экране. Просто напишите или скажите что-нибудь JARVIS.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
  Widget _card(String label, String value) => Card(
    color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      title: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      subtitle: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}

// ═══════════════════════════════════════════════════════
// VISION TEST SCREEN — take photo and analyze
// ═══════════════════════════════════════════════════════
class VisionTestScreen extends StatefulWidget {
  const VisionTestScreen();
  @override State<VisionTestScreen> createState() => VisionTestScreenState();
}

class VisionTestScreenState extends State<VisionTestScreen> {
  final _vision = VisionService();
  String _result = '';
  bool _loading = false;

  Future<void> _capture() async {
    setState(() { _loading = true; _result = ''; });
    try {
      final photo = await _vision.capturePhoto();
      if (photo == null) { setState(() { _result = 'Фото не сделано'; _loading = false; }); return; }
      final result = await _vision.analyzeImage(photo, 'Опиши что на фото');
      setState(() { _result = result; _loading = false; });
    } catch (e) {
      setState(() { _result = 'Ошибка: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Зрение (Vision)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Padding(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 30),
          Icon(Icons.visibility, size: 70, color: _loading ? AppTheme.accentBlue : AppTheme.textSecondary),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loading ? null : _capture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Сделать фото и 分析'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) const CircularProgressIndicator(color: AppTheme.accentBlue),
          if (_result.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
              child: Text(_result, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            ),
          const SizedBox(height: 30),
          _infoCard(),
        ]),
      ),
    );
  }

  Widget _infoCard() {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Информация', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('• Камера: image_picker\n• Движок: GPT Vision API\n• Размер: 1024x1024\n• Формат: JPEG → base64',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// EMOTION TEST SCREEN
// ═══════════════════════════════════════════════════════
class EmotionTestScreen extends StatefulWidget {
  const EmotionTestScreen();
  @override State<EmotionTestScreen> createState() => EmotionTestScreenState();
}

class EmotionTestScreenState extends State<EmotionTestScreen> {
  final emotionSvc = EmotionService();
  String currentEmotion = '';
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    emotionSvc.onEmotionDetected = (e) {
      if (mounted) setState(() => currentEmotion = e);
    };
  }

  @override
  void dispose() {
    emotionSvc.stop();
    super.dispose();
  }

  void _toggle() {
    if (_watching) {
      emotionSvc.stop();
      setState(() { _watching = false; });
    } else {
      emotionSvc.start();
      setState(() { _watching = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Анализ эмоций', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Padding(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 40),
          Icon(_watching ? Icons.face : Icons.face_retouching_off, size: 80,
            color: _watching ? AppTheme.accentBlue : AppTheme.textSecondary),
          const SizedBox(height: 20),
          if (currentEmotion.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text(currentEmotion, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 20, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _toggle,
            icon: Icon(_watching ? Icons.stop : Icons.play_arrow),
            label: Text(_watching ? 'Стоп' : 'Начать анализ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _watching ? Colors.red : AppTheme.accentBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
          const SizedBox(height: 30),
          _infoCard(),
        ]),
      ),
    );
  }

  Widget _infoCard() {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Информация', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('• Камера: Фронтальная\n• Интервал: 20 сек\n• Движок: GPT Vision\n• Интеграция: влияет на тон ответа',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// MEMORY VIEW SCREEN — view and clear memory
// ═══════════════════════════════════════════════════════
class MemoryViewScreen extends StatefulWidget {
  const MemoryViewScreen();
  @override State<MemoryViewScreen> createState() => MemoryViewScreenState();
}

class MemoryViewScreenState extends State<MemoryViewScreen> {
  List<Map<String, String>> _messages = [];
  List<Map<String, String>> _facts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mem = MemoryService();
    await mem.init();
    final msgs = await mem.getRecentMessages(limit: 50);
    final factsMap = await mem.getAllFacts();
    final facts = factsMap.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
    setState(() { _messages = msgs; _facts = facts; _loading = false; });
  }

  Future<void> _clear() async {
    final mem = MemoryService();
    await mem.init();
    await mem.clearAll();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Память', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.red), onPressed: _clear)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
        : ListView(padding: const EdgeInsets.all(16),
            children: [
              if (_facts.isNotEmpty) ...[
                const Text('Факты', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._facts.map((f) => Card(
                  color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(f['key'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    subtitle: Text(f['value'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                  ),
                )),
                const SizedBox(height: 20),
              ],
              Text('История (${_messages.length})', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._messages.map((m) => Card(
                color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(m['role'] == 'user' ? Icons.person : Icons.smart_toy, color: AppTheme.accentBlue, size: 20),
                  title: Text(m['content'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              )),
            ],
          ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// WEB SEARCH INFO SCREEN
// ═══════════════════════════════════════════════════════
class WebSearchInfoScreen extends StatelessWidget {
  const WebSearchInfoScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Веб-поиск', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Padding(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(color: AppTheme.cardColor,
            child: Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Веб-поиск активен', style: TextStyle(color: AppTheme.accentBlue, fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 10),
                Text('Просто спросите в чате:\n• "найди в интернете..."\n• "что нового в..."\n• "поищи ..."\n\nJARVIS автоматически определит поисковый запрос и выдаст краткую выжимку с источниками.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// VOICE CONTROL SCREEN — full voice command reference + test
// ═══════════════════════════════════════════════════════
class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen();
  @override State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen> {
  final _voice = VoiceService();
  bool _wakeActive = false;
  String _heard = '';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _wakeActive = _voice.isWakeWordMode;
    _voice.onWakeWordDetected = () {
      if (mounted) setState(() => _wakeActive = true);
    };
  }

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  Future<void> _toggleWakeWord() async {
    if (_wakeActive) {
      _voice.stopWakeWordMode();
      setState(() => _wakeActive = false);
    } else {
      final ok = await _voice.startWakeWordMode();
      if (mounted) setState(() => _wakeActive = ok);
    }
  }

  Future<void> _testVoice() async {
    if (_listening) {
      await _voice.stopListening();
      setState(() => _listening = false);
      return;
    }
    setState(() { _listening = true; _heard = ''; });
    final ok = await _voice.startListening(
      onResult: (text) {
        if (mounted) setState(() { _heard = text; _listening = false; });
      },
      onPartial: (text) {
        if (mounted) setState(() => _heard = text);
      },
    );
    if (!ok && mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Голосовое управление', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.all(20),
        children: [
          // Wake word status
          Card(
            color: AppTheme.cardColor,
            child: SwitchListTile(
              title: const Text('Wake word (Джарвис)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text(_wakeActive ? 'Активен — скажите "Джарвис" для активации' : 'Выключен',
                style: TextStyle(color: _wakeActive ? Colors.green : AppTheme.textSecondary, fontSize: 13)),
              value: _wakeActive, onChanged: (_) => _toggleWakeWord(),
              activeColor: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(height: 16),

          // Test voice input
          Card(
            color: AppTheme.cardColor,
            child: Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Icon(_listening ? Icons.mic : Icons.mic_none, size: 50,
                  color: _listening ? AppTheme.accentBlue : AppTheme.textSecondary),
                const SizedBox(height: 12),
                Text(_listening ? 'Слушаю...' : 'Нажмите и говорите',
                  style: TextStyle(color: _listening ? AppTheme.accentBlue : AppTheme.textSecondary, fontSize: 15)),
                const SizedBox(height: 8),
                if (_heard.isNotEmpty)
                  Text('Услышал: "$heard"', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _testVoice,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(_listening ? 'Стоп' : 'Тест голоса'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _listening ? Colors.red : AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Command categories
          const Text('Команды открытия приложений', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _cmdCard('открой телеграм', 'Открывает Telegram'),
          _cmdCard('запусти whatsapp', 'Открывает WhatsApp'),
          _cmdCard('включи youtube', 'Открывает YouTube'),
          _cmdCard('открой браузер', 'Открывает браузер'),
          _cmdCard('запусти музыку', 'Открывает музыкальный плеер'),

          const SizedBox(height: 20),
          const Text('Команды управления телефоном', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _cmdCard('назад', 'Кнопка назад'),
          _cmdCard('домой', 'Кнопка домой'),
          _cmdCard('недавние', 'Недавние приложения'),
          _cmdCard('листай вниз', 'Прокрутка вниз'),
          _cmdCard('листай вверх', 'Прокрутка вверх'),
          _cmdCard('нажми Отправить', 'Нажать кнопку по тексту'),
          _cmdCard('введи привет', 'Ввести текст в поле ввода'),

          const SizedBox(height: 20),
          const Text('Поиск и информация', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _cmdCard('найди в интернете ...', 'Веб-поиск через AI'),
          _cmdCard('какая погода', 'Текущая погода'),
          _cmdCard('курс валют', 'Курсы валют'),
          _cmdCard('что нового', 'Новости'),

          const SizedBox(height: 20),
          const Text('Общение с JARVIS', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _cmdCard('Джарвис, ...', 'Активация wake word → вопрос'),
          _cmdCard('расскажи о ...', 'AI отвечает в стиле JARVIS'),
          _cmdCard('опиши что на фото', 'Анализ изображения'),

          const SizedBox(height: 30),
          Card(
            color: AppTheme.cardColor,
            child: Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Требования', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('• Accessibility Service — для управления телефоном\n• Разрешение на микрофон\n• Разрешение на наложение поверх окон\n• Google App установлен (для STT)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cmdCard(String command, String desc) {
    return Card(
      color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: const Icon(Icons.keyboard_voice, color: AppTheme.accentBlue, size: 20),
        title: Text(command, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(desc, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        dense: true,
      ),
    );
  }
}
