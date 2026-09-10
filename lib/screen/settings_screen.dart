import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/section_card.dart';
import '../utils/status_badge.dart';
import '../models/app_user.dart';
import '../utils/buttons.dart';

List<AppUser> _sampleTeam() {
  return [];
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;

  late TextEditingController _appNameController;
  bool _notificationBanner = true;
  bool _lowStockAlerts = true;
  bool _inboundNotices = false;
  bool _emailSummaries = false;

  late List<AppUser> _team;

  static const _tabs = ['General', 'Notifications', 'User Management'];

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController(text: 'Hardware Stock Manager');
    _team = _sampleTeam();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    super.dispose();
  }

  void _saveGeneralSettings() {
    final name = _appNameController.text.trim();
    if (name.isEmpty) {
      _showSnack('App name cannot be empty.');
      return;
    }
    _showSnack('Workspace preferences saved.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showEditRoleDialog(AppUser member) async {
    String selectedRole = member.role ?? 'Staff';
    final roles = ['Admin', 'Manager', 'Staff'];

    final updatedRole = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Role for ${member.fullName}', style: AppTextStyles.h3),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select assigned role:', style: AppTextStyles.caption),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: roles.contains(selectedRole) ? selectedRole : 'Staff',
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(selectedRole),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Save Role'),
          ),
        ],
      ),
    );

    if (updatedRole != null && updatedRole != member.role) {
      setState(() {
        final idx = _team.indexWhere((m) => m.id == member.id);
        if (idx >= 0) {
          _team[idx] = AppUser(
            id: member.id,
            fullName: member.fullName,
            email: member.email,
            role: updatedRole,
          );
        }
      });
      _showSnack('Role updated for ${member.fullName} to $updatedRole');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 600;
    final horizontalPadding = compact ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 28, horizontalPadding, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(
              title: 'Settings',
              subtitle: 'Manage your workspace preferences and team.'),
          const SizedBox(height: AppSpacing.lg),
          _buildTabBar(_tabs),
          const SizedBox(height: AppSpacing.lg),
          if (_tab == 0) _buildGeneral(),
          if (_tab == 1) _buildNotifications(),
          if (_tab == 2) _buildUserManagement(),
        ],
      ),
    );
  }

  Widget _buildTabBar(List<String> tabs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < tabs.length; i++)
              GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == i ? AppColors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    tabs[i],
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: _tab == i ? AppColors.primary : AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneral() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('General', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text('Basic information about your workspace.', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'App Name',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appNameController,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Enter app name',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryButton(
              label: 'Save Changes',
              icon: Icons.save_rounded,
              onPressed: _saveGeneralSettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifications() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text('Choose what you want to be notified about.', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.lg),
          _toggleRow(
            title: 'Notification Banners (Top-Right Popups)',
            subtitle: 'Show top-right 2-second overlay banners for actions & alerts.',
            value: _notificationBanner,
            onChanged: (v) {
              setState(() => _notificationBanner = v);
              _showSnack(v ? 'Notification banners enabled' : 'Notification banners disabled');
            },
          ),
          const Divider(height: AppSpacing.xl),
          _toggleRow(
            title: 'Low Stock Alerts',
            subtitle: 'Get notified when a product falls below its reorder point (10 units).',
            value: _lowStockAlerts,
            onChanged: (v) {
              setState(() => _lowStockAlerts = v);
              _showSnack('Low stock alert preference updated.');
            },
          ),
          const Divider(height: AppSpacing.xl),
          _toggleRow(
            title: 'Inbound Arrival Notices',
            subtitle: 'Get notified when an inbound stock transaction is completed.',
            value: _inboundNotices,
            onChanged: (v) {
              setState(() => _inboundNotices = v);
              _showSnack('Inbound notices preference updated.');
            },
          ),
          const Divider(height: AppSpacing.xl),
          _toggleRow(
            title: 'Email Summaries',
            subtitle: 'Receive a daily digest of warehouse activity by email.',
            value: _emailSummaries,
            onChanged: (v) {
              setState(() => _emailSummaries = v);
              _showSnack('Email summaries preference updated.');
            },
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.primary,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: AppColors.border,
        ),
      ],
    );
  }

  Widget _buildUserManagement() {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User Management', style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text('${_team.length} team member(s) registered.',
                      style: AppTextStyles.caption),
                ],
              ),
              PrimaryButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: () => setState(() => _team = _sampleTeam()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_team.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No team members registered yet.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._team.map((m) => _TeamMemberRow(
                  member: m,
                  onEditRole: () => _showEditRoleDialog(m),
                )),
        ],
      ),
    );
  }
}

class _TeamMemberRow extends StatelessWidget {
  final AppUser member;
  final VoidCallback onEditRole;

  const _TeamMemberRow({
    required this.member,
    required this.onEditRole,
  });

  BadgeTone get _tone {
    switch (member.role?.toLowerCase()) {
      case 'admin':
        return BadgeTone.info;
      case 'manager':
        return BadgeTone.success;
      default:
        return BadgeTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 500;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    member.initials.isNotEmpty ? member.initials : 'U',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(member.fullName,
                      style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
                ),
                StatusBadge(label: member.role ?? 'None', tone: _tone),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(member.email,
                      style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: onEditRole,
                  icon: const Icon(Icons.manage_accounts_rounded,
                      size: 20, color: AppColors.primary),
                  tooltip: 'Alter Role',
                  splashRadius: 18,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(
              member.initials.isNotEmpty ? member.initials : 'U',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName, style: AppTextStyles.bodyMedium),
                Text(member.email, style: AppTextStyles.caption),
              ],
            ),
          ),
          StatusBadge(label: member.role ?? 'None', tone: _tone),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onEditRole,
            icon: const Icon(Icons.manage_accounts_rounded, size: 20, color: AppColors.primary),
            tooltip: 'Alter Role',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
