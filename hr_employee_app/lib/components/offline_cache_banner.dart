import 'package:flutter/material.dart';

class OfflineCacheBanner extends StatelessWidget {
  final String? fetchedAt;
  final VoidCallback onRetry;

  const OfflineCacheBanner({
    super.key,
    required this.fetchedAt,
    required this.onRetry,
  });

  String _formatTime() {
    final value = DateTime.tryParse(fetchedAt ?? '');
    if (value == null) return 'Last successful refresh time unavailable';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return 'Saved ${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        'at $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text('Offline — showing saved data. ${_formatTime()}'),
      leading: const Icon(Icons.cloud_off_outlined),
      actions: [TextButton(onPressed: onRetry, child: const Text('Retry'))],
    );
  }
}
