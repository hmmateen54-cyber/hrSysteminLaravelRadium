import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lines = title
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final heading = lines.isEmpty ? title : lines.first;
    final value = lines.length > 1 && int.tryParse(lines[1]) != null
        ? lines[1]
        : null;
    final supporting = lines.skip(value == null ? 1 : 2).join('  ·  ');

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 124),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.infoSurface,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(icon, color: AppColors.info, size: 19),
                    ),
                    const Spacer(),
                    if (onTap != null)
                      const Icon(
                        Icons.arrow_outward_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'Roboto',
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (supporting.isNotEmpty) ...[
                  if (value == null) const SizedBox(height: AppSpacing.xxs),
                  Text(
                    supporting,
                    maxLines: value == null ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
