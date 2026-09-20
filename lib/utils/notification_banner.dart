import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';

enum NotificationTone { success, error, warning, info }

/// A global, top-right overlay notification banner.
///
/// Usage: `NotificationBanner.show(context, 'Message here', tone: NotificationTone.success);`
///
/// - Appears at top-right, max ~360px wide
/// - Auto-dismisses after 2 seconds
/// - Each new call overwrites (removes) the previous notification immediately
class NotificationBanner {
  static OverlayEntry? _currentEntry;
  static AnimationController? _currentController;

  NotificationBanner._();

  /// Show a notification banner. If one is already visible, it is removed instantly.
  static void show(
    BuildContext context,
    String message, {
    NotificationTone tone = NotificationTone.info,
    IconData? icon,
  }) {
    // If notifications are disabled in settings, do nothing
    if (!SettingsService.instance.notificationBannerEnabled) return;

    // Remove any existing notification immediately
    dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);

    late final AnimationController controller;
    late final OverlayEntry entry;

    controller = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 250),
    );

    entry = OverlayEntry(
      builder: (ctx) => _BannerWidget(
        message: message,
        tone: tone,
        icon: icon,
        animation: controller,
        onDismiss: () => dismiss(),
      ),
    );

    _currentEntry = entry;
    _currentController = controller;

    overlay.insert(entry);
    controller.forward();

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentEntry == entry) {
        _animateOut(controller, entry);
      }
    });
  }

  static void dismiss() {
    _currentController?.dispose();
    _currentController = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void _animateOut(AnimationController controller, OverlayEntry entry) {
    controller.reverse().then((_) {
      if (_currentEntry == entry) {
        entry.remove();
        controller.dispose();
        _currentEntry = null;
        _currentController = null;
      }
    });
  }
}

class _BannerWidget extends StatelessWidget {
  final String message;
  final NotificationTone tone;
  final IconData? icon;
  final AnimationController animation;
  final VoidCallback onDismiss;

  const _BannerWidget({
    required this.message,
    required this.tone,
    this.icon,
    required this.animation,
    required this.onDismiss,
  });

  Color get _bgColor {
    switch (tone) {
      case NotificationTone.success:
        return AppColors.success;
      case NotificationTone.error:
        return AppColors.danger;
      case NotificationTone.warning:
        return AppColors.warning;
      case NotificationTone.info:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    if (icon != null) return icon!;
    switch (tone) {
      case NotificationTone.success:
        return Icons.check_circle_rounded;
      case NotificationTone.error:
        return Icons.error_rounded;
      case NotificationTone.warning:
        return Icons.warning_rounded;
      case NotificationTone.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final screenWidth = MediaQuery.of(context).size.width;
        final isCompact = screenWidth < 420;
        return Positioned(
          top: 16 + MediaQuery.of(context).padding.top,
          right: 16,
          left: isCompact ? 16 : null,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.2, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: (MediaQuery.of(context).size.width - 32).clamp(200, 360), minWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _bgColor.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}