import 'package:flutter/material.dart';
import '../models/character_persona.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class PersonaScreen extends StatefulWidget {
  final PersonaType currentType;
  final Function(CharacterPersona) onSelect;

  const PersonaScreen({
    super.key,
    required this.currentType,
    required this.onSelect,
  });

  @override State<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  late PersonaType _selected;
  final _ai = AiService();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          ),
        ),
        title: const Text('Карта AIRI',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16, left: 4),
            child: Text('Выбери характер ассистента',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          ...allPersonas.map((p) {
            final isSelected = p.type == _selected;
            return GestureDetector(
              onTap: () async {
                setState(() => _selected = p.type);
                await _ai.savePersona(p.type);
                widget.onSelect(p);
                if (context.mounted) Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentBlue.withOpacity(0.12)
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? AppTheme.accentBlue : AppTheme.cardBorder,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: p.type == PersonaType.jarvis
                            ? [AppTheme.accentBlue, const Color(0xFF1A3A6B)]
                            : [AppTheme.accentPurple, const Color(0xFFFF6BB5)],
                      ),
                    ),
                    child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: TextStyle(
                        color: isSelected ? AppTheme.accentBlue : AppTheme.textPrimary,
                        fontSize: 17, fontWeight: FontWeight.bold,
                      )),
                      const SizedBox(height: 4),
                      Text(p.description,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  )),
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.accentBlue : Colors.transparent,
                      border: isSelected ? null : Border.all(color: AppTheme.cardBorder),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ]),
              ),
            );
          }),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 15),
                SizedBox(width: 6),
                Text('Стиль общения',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(
                _selected == PersonaType.jarvis
                    ? '"В рабочем состоянии и полностью к вашим услугам. Надеюсь, у вас дела обстоят не хуже."'
                    : '"Э-э?.. Правда?.. Мне очень приятно это слышать... ♡"',
                style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14,
                  fontStyle: FontStyle.italic, height: 1.5,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
