import 'package:flutter/material.dart';
import '../models/settings_item.dart';
import '../theme/app_theme.dart';

class SettingsCard extends StatelessWidget {
  final SettingsItem item;
  final int index;
  final VoidCallback onTap;

  const SettingsCard({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.accentBlue.withOpacity(0.08),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 5),
                  Text(item.subtitle, style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4,
                  )),
                ],
              )),
              const SizedBox(width: 12),
              Text(item.iconPath, style: TextStyle(
                fontSize: 32, color: Colors.white.withOpacity(0.08),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}
