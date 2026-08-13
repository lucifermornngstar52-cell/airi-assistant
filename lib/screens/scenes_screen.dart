import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Экран сцен — пользователь может выбрать фото или видео как фон для Live2D модели.
class ScenesScreen extends StatefulWidget {
  const ScenesScreen({super.key});
  @override
  State<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  String? _bgPath;
  String _bgType = 'none'; // 'photo' | 'video' | 'none'
  final _picker = ImagePicker();

  // Предустановленные градиенты
  final _gradients = [
    {'name': 'Тёмный', 'colors': [Color(0xFF0D1120), Color(0xFF080B14)]},
    {'name': 'Закат', 'colors': [Color(0xFFFF6B6B), Color(0xFF4ECDC4)]},
    {'name': 'Неон', 'colors': [Color(0xFF00D4FF), Color(0xFF9D4EDD)]},
    {'name': 'Розовый', 'colors': [Color(0xFFFF006E), Color(0xFF8338EC)]},
    {'name': 'Лес', 'colors': [Color(0xFF2D6A4F), Color(0xFF1B4332)]},
    {'name': 'Океан', 'colors': [Color(0xFF0077B6), Color(0xFF03045E)]},
  ];
  int _selectedGradient = -1;

  @override
  void initState() {
    super.initState();
    _loadBg();
  }

  Future<void> _loadBg() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bgPath = prefs.getString('scene_bg_path');
      _bgType = prefs.getString('scene_bg_type') ?? 'none';
      _selectedGradient = prefs.getInt('scene_gradient') ?? -1;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (xfile == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scene_bg_path', xfile.path);
      await prefs.setString('scene_bg_type', 'photo');
      await prefs.setInt('scene_gradient', -1);
      setState(() {
        _bgPath = xfile.path;
        _bgType = 'photo';
        _selectedGradient = -1;
      });
    } catch (e) {
      _showError('Не удалось выбрать фото: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final xfile = await _picker.pickVideo(source: ImageSource.gallery);
      if (xfile == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scene_bg_path', xfile.path);
      await prefs.setString('scene_bg_type', 'video');
      await prefs.setInt('scene_gradient', -1);
      setState(() {
        _bgPath = xfile.path;
        _bgType = 'video';
        _selectedGradient = -1;
      });
    } catch (e) {
      _showError('Не удалось выбрать видео: $e');
    }
  }

  Future<void> _selectGradient(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scene_gradient', idx);
    await prefs.setString('scene_bg_type', 'gradient');
    await prefs.remove('scene_bg_path');
    setState(() {
      _selectedGradient = idx;
      _bgType = 'gradient';
      _bgPath = null;
    });
  }

  Future<void> _clearBg() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scene_bg_path');
    await prefs.setString('scene_bg_type', 'none');
    await prefs.setInt('scene_gradient', -1);
    setState(() {
      _bgPath = null;
      _bgType = 'none';
      _selectedGradient = -1;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.neonPink),
    );
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
        title: const Text('Сцены', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Текущий фон
          Text('ТЕКУЩИЙ ФОН',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: _buildPreview(),
          ),
          const SizedBox(height: 24),

          // Кнопки выбора
          Text('ДОБАВИТЬ ФОН',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildButton(
              icon: Icons.photo_library,
              label: 'Фото из галереи',
              onTap: _pickPhoto,
              active: _bgType == 'photo',
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildButton(
              icon: Icons.video_library,
              label: 'Видео из галереи',
              onTap: _pickVideo,
              active: _bgType == 'video',
            )),
          ]),
          const SizedBox(height: 24),

          // Градиенты
          Text('ПРЕДУСТАНОВКИ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 1.2, crossAxisSpacing: 10, mainAxisSpacing: 10,
            ),
            itemCount: _gradients.length,
            itemBuilder: (ctx, i) {
              final g = _gradients[i];
              final selected = _selectedGradient == i;
              return GestureDetector(
                onTap: () => _selectGradient(i),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: g['colors'] as List<Color>,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppTheme.neonBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (selected) const Icon(Icons.check, color: Colors.white, size: 20),
                    Text(g['name'] as String, style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    )),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Очистить
          if (_bgType != 'none')
            TextButton.icon(
              onPressed: _clearBg,
              icon: const Icon(Icons.delete_outline, color: AppTheme.neonPink, size: 18),
              label: const Text('Убрать фон', style: TextStyle(color: AppTheme.neonPink, fontSize: 14)),
            ),

          const SizedBox(height: 16),
          // Инфо
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.info_outline, color: AppTheme.neonBlue, size: 18),
                const SizedBox(width: 8),
                const Text('Как это работает', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(
                '1. Выбери фото или видео как фон\n'
                '2. Live2D модель будет поверх фона\n'
                '3. Фото — статичный фон\n'
                '4. Видео — анимированный фон (зацикленный)\n'
                '5. Градиенты — предустановленные цветовые сцены\n'
                '6. Фон виден и в приложении, и в оверлее',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_bgType == 'photo' && _bgPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(_bgPath!), fit: BoxFit.cover, width: double.infinity, height: 200),
      );
    }
    if (_bgType == 'video' && _bgPath != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.videocam, color: AppTheme.neonBlue, size: 48),
        const SizedBox(height: 8),
        Text('Видео: ${_bgPath!.split('/').last}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        const Text('(превью недоступно)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ]));
    }
    if (_bgType == 'gradient' && _selectedGradient >= 0) {
      final g = _gradients[_selectedGradient];
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: g['colors'] as List<Color>,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text(g['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
      );
    }
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.image_outlined, color: AppTheme.textSecondary, size: 48),
      SizedBox(height: 8),
      Text('Фон не выбран', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    ]));
  }

  Widget _buildButton({required IconData icon, required String label, required VoidCallback onTap, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? AppTheme.neonBlue.withOpacity(0.1) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppTheme.neonBlue : AppTheme.cardBorder,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: Column(children: [
          Icon(icon, color: active ? AppTheme.neonBlue : AppTheme.textSecondary, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            color: active ? AppTheme.neonBlue : AppTheme.textPrimary,
            fontSize: 12, fontWeight: FontWeight.w600,
          )),
        ]),
      ),
    );
  }
}
