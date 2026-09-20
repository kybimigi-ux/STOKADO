import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';
import 'status_badge.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String? badgeText;
  final BadgeTone badgeTone;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.badgeText,
    this.badgeTone = BadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              if (badgeText != null) StatusBadge(label: badgeText!, tone: badgeTone),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTextStyles.statValue),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}