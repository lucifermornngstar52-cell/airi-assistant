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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Карта AIRI',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14, left: 2),
            child: Text(
              'Выбери характер ассистента',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          ...allPersonas.map((p) => _PersonaCard(
            persona: p,
            isSelected: p.type == _selected,
            onTap: () async {
              setState(() => _selected = p.type);
              await _ai.savePersona(p.type);
              widget.onSelect(p);
              if (context.mounted) Navigator.pop(context);
            },
          )),
          const SizedBox(height: 8),
          _QuoteCard(type: _selected),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final CharacterPersona persona;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonaCard({
    required this.persona,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentBlue.withOpacity(0.1)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.cardBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(children: [
          // Аватар с инициалами
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: persona.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                persona.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                persona.name,
                style: TextStyle(
                  color: isSelected ? AppTheme.accentBlue : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                persona.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          )),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTheme.accentBlue : Colors.transparent,
              border: isSelected
                  ? null
                  : Border.all(color: AppTheme.cardBorder),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 13)
                : null,
          ),
        ]),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final PersonaType type;
  const _QuoteCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final quote = type == PersonaType.jarvis
        ? '"В рабочем состоянии и полностью к вашим услугам."'
        : '"Мне приятно, что ты со мной разговариваешь... ♡"';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.format_quote, color: AppTheme.textSecondary, size: 14),
          SizedBox(width: 6),
          Text(
            'Стиль общения',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          quote,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      ]),
    );
  }
}
