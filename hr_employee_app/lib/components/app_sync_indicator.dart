import 'package:flutter/material.dart';

import 'app_status_badge.dart';

enum AppSyncState { local, pending, syncing, synchronized, failed, offline }

class AppSyncIndicator extends StatelessWidget {
  final AppSyncState state;
  final String? detail;

  const AppSyncIndicator({super.key, required this.state, this.detail});

  String get _label => switch (state) {
    AppSyncState.local => 'Saved on this device',
    AppSyncState.pending => 'Waiting to sync',
    AppSyncState.syncing => 'Syncing',
    AppSyncState.synchronized => 'Server confirmed',
    AppSyncState.failed => 'Sync failed',
    AppSyncState.offline => 'Offline',
  };

  String get _statusKey => switch (state) {
    AppSyncState.local => 'offline',
    AppSyncState.pending => 'pending',
    AppSyncState.syncing => 'in_progress',
    AppSyncState.synchronized => 'synced',
    AppSyncState.failed => 'failed',
    AppSyncState.offline => 'offline',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppStatusBadge(status: _statusKey, label: _label),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(detail!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
