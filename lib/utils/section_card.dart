import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A plain white surface with a hairline border, used as the base
/// container for cards, tables, and panels throughout the app.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Standard heading row used at the top of most screens:
/// a title + optional subtitle on the left, actions on the right.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const ScreenHeader(
      {super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;

        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h1),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(spacing: AppSpacing.sm, children: actions),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleColumn),
            if (actions.isNotEmpty)
              Wrap(spacing: AppSpacing.sm, children: actions),
          ],
        );
      },
    );
  }
}
