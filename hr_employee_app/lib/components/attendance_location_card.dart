import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_status_badge.dart';

class AttendanceLocationCard extends StatelessWidget {
  const AttendanceLocationCard({
    super.key,
    required this.syncStatus,
    required this.addressStatus,
    required this.message,
    this.address,
    this.accuracyLabel,
    this.onRetrySync,
    this.onRetryAddress,
  });

  final String syncStatus;
  final String addressStatus;
  final String message;
  final String? address;
  final String? accuracyLabel;
  final VoidCallback? onRetrySync;
  final VoidCallback? onRetryAddress;

  String get _syncLabel => switch (syncStatus) {
    'synced' => 'Server confirmed',
    'waiting' => 'Synchronization pending',
    'loading' => 'Getting location',
    'failed' => 'Needs attention',
    _ => 'Not recorded',
  };

  String get _syncBadgeStatus => switch (syncStatus) {
    'synced' => 'synced',
    'waiting' => 'pending',
    'loading' => 'in_progress',
    'failed' => 'failed',
    _ => 'neutral',
  };

  String get _addressLabel {
    if (address != null && address!.trim().isNotEmpty) return address!.trim();
    return switch (addressStatus) {
      'permission_denied' => 'Location permission denied',
      'unavailable' => 'Address unavailable',
      'none' when syncStatus == 'loading' => 'Getting current location…',
      'pending' when syncStatus == 'loading' => 'Resolving address…',
      'pending' when syncStatus != 'synced' =>
        'Saved offline — address pending',
      'pending' => 'Address pending — will retry when online',
      _ => 'Location has not been requested.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null && address!.trim().isNotEmpty;
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current Location',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                AppStatusBadge(status: _syncBadgeStatus, label: _syncLabel),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _addressLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: hasAddress ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            if (hasAddress) ...[
              const SizedBox(height: 3),
              Text(
                'Address data © OpenStreetMap contributors',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            if (message.trim().isNotEmpty &&
                message.trim() != _addressLabel) ...[
              const SizedBox(height: 5),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (accuracyLabel != null) ...[
              const SizedBox(height: 3),
              Text(
                accuracyLabel!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            if (onRetryAddress != null || onRetrySync != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetryAddress ?? onRetrySync,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    onRetryAddress != null
                        ? 'Retry address lookup'
                        : 'Retry attendance sync',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
