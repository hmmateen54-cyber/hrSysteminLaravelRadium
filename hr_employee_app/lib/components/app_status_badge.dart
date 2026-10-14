import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class AppStatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  final bool compact;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.label,
    this.compact = false,
  });

  String get _normalized => status.trim().toLowerCase().replaceAll('-', '_');

  String get _label => label ?? _normalized.replaceAll('_', ' ');

  Color get _foreground => switch (_normalized) {
    'approved' ||
    'completed' ||
    'synced' ||
    'present' ||
    'resolved' => AppColors.success,
    'pending' ||
    'overdue' ||
    'late' ||
    'waiting_to_sync' ||
    'offline' => AppColors.warning,
    'rejected' || 'failed' || 'absent' || 'error' => AppColors.error,
    'assigned' ||
    'in_progress' ||
    'on_hold' ||
    'reviewing' ||
    'leave' => AppColors.info,
    _ => AppColors.textSecondary,
  };

  Color get _background => switch (_normalized) {
    'approved' ||
    'completed' ||
    'synced' ||
    'present' ||
    'resolved' => AppColors.successSurface,
    'pending' ||
    'overdue' ||
    'late' ||
    'waiting_to_sync' ||
    'offline' => AppColors.warningSurface,
    'rejected' || 'failed' || 'absent' || 'error' => AppColors.errorSurface,
    'assigned' ||
    'in_progress' ||
    'on_hold' ||
    'reviewing' ||
    'leave' => AppColors.infoSurface,
    _ => AppColors.background,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $_label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: _foreground.withValues(alpha: 0.13)),
        ),
        child: Text(
          _label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _foreground,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
