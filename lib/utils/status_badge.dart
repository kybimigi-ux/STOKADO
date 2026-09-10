import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeTone { success, warning, danger, neutral, info }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral, this.icon});

  _BadgeColors get _colors {
    switch (tone) {
      case BadgeTone.success:
        return _BadgeColors(AppColors.successSoft, AppColors.success);
      case BadgeTone.warning:
        return _BadgeColors(AppColors.warningSoft, AppColors.warning);
      case BadgeTone.danger:
        return _BadgeColors(AppColors.dangerSoft, AppColors.danger);
      case BadgeTone.info:
        return _BadgeColors(AppColors.primarySoft, AppColors.primary);
      case BadgeTone.neutral:
        return _BadgeColors(AppColors.neutralSoft, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Align(
      alignment: Alignment.centerLeft, // or centerRight if you want it right-aligned
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: c.fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(color: c.fg, fontWeight: FontWeight.w600, height: 1.0),
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeColors {
  final Color bg;
  final Color fg;
  _BadgeColors(this.bg, this.fg);
}
