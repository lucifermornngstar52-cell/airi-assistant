import 'package:flutter/material.dart';
import '../services/model_manager_service.dart';
import '../theme/app_theme.dart';

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  final _models = ModelManagerService();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _models.init();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _importModel() async {
    setState(() => _error = null);
    final result = await _models.importCustomModel();
    if (result == null) {
      // Отменено
      return;
    }
    if (result.startsWith('Ошибка')) {
      setState(() => _error = result);
      _showSnack(result, isError: true);
    } else {
      // Успешно — переключаемся на новую модель
      await _models.selectModel(result);
      _showSnack('Модель загружена!', isError: false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        appBar: AppBar(
          title: Text('Выбор модели'),
          backgroundColor: AppTheme.cardColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Text('Выбор модели'),
        backgroundColor: AppTheme.cardColor,
        actions: [
          IconButton(
            icon: Icon(Icons.file_download),
            tooltip: 'Загрузить свою модель',
            onPressed: _importModel,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // ─── Встроенные модели ─────────────────────────
          Text(
            'Встроенные модели',
            style: TextStyle(
              color: AppTheme.accentBlue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ..._models.builtinModels.map((m) => _ModelCard(
            model: m,
            isSelected: _models.currentPath == m.assetPath,
            onTap: () async {
              await _models.selectModel(m.assetPath);
              setState(() {});
              _showSnack('Модель: ${m.name}', isError: false);
            },
          )),

          SizedBox(height: 24),

          // ─── Кастомные модели ──────────────────────────
          Row(
            children: [
              Text(
                'Мои модели',
                style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _importModel,
                icon: Icon(Icons.add),
                label: Text('Загрузить'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.accentBlue),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (_models.customModels.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey.shade600),
                  SizedBox(height: 12),
                  Text(
                    'Нет кастомных моделей',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Нажми «Загрузить» и выбери .model3.json файл',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ..._models.customModels.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value;
              return _ModelCard(
                model: m,
                isSelected: _models.currentPath == m.assetPath,
                onTap: () async {
                  await _models.selectModel(m.assetPath);
                  setState(() {});
                  _showSnack('Модель: ${m.name}', isError: false);
                },
                onDelete: () async {
                  await _models.removeCustomModel(idx);
                  setState(() {});
                  _showSnack('Удалено: ${m.name}', isError: false);
                },
              );
            }),

          if (_error != null) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade700),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],

          SizedBox(height: 24),
          // ─── Подсказка ─────────────────────────────────
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Поддерживаются Live2D .model3.json файлы. Все текстуры и .moc3 файлы копируются автоматически.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final Live2DModel model;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected
          ? AppTheme.accentBlue.withOpacity(0.15)
          : AppTheme.cardColor,
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.accentBlue : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentBlue.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            model.isBuiltin ? Icons.face : Icons.person_add,
            color: isSelected ? AppTheme.accentBlue : Colors.grey.shade400,
          ),
        ),
        title: Text(
          model.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          model.isBuiltin ? 'Встроенная' : 'Кастомная',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.accentBlue, size: 22),
            if (!model.isBuiltin && onDelete != null) ...[
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                onPressed: onDelete,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
