import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});
  @override State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _saved   = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _keyCtrl.text = p.getString('openai_key') ?? '');
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('openai_key', _keyCtrl.text.trim());
    if (!mounted) return;
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Провайдеры',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Активный провайдер
          const Text(
            'АКТИВНЫЙ ПРОВАЙДЕР',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentBlue.withOpacity(0.35), width: 1),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_outlined, color: AppTheme.accentBlue, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OpenAI GPT-5',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Основной провайдер',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A2A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Активен',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 28),

          // API Key
          const Text(
            'OPENAI API KEY',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: TextField(
              controller: _keyCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'sk-...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ключ хранится локально на устройстве и никуда не передаётся.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
          ),

          const SizedBox(height: 24),

          // Кнопка сохранить
          GestureDetector(
            onTap: _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _saved
                      ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                      : [AppTheme.accentBlue, AppTheme.accentPurple],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  _saved ? Icons.check_circle_outline : Icons.save_outlined,
                  color: Colors.white, size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _saved ? 'Сохранено' : 'Сохранить',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 32),

          // Fallback
          const Text(
            'РЕЗЕРВНЫЙ ПРОВАЙДЕР',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_outlined, color: AppTheme.accentPurple, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Gemini',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Резервный провайдер',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: const Text(
                  'Скоро',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
