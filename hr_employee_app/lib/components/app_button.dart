import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, outlined, destructive }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool expand;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor =
        variant == AppButtonVariant.outlined ||
            variant == AppButtonVariant.secondary
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: progressColor,
            ),
          )
        else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18),
          const SizedBox(width: 9),
        ],
        Flexible(child: Text(text, textAlign: TextAlign.center)),
        if (!loading && trailingIcon != null) ...[
          const SizedBox(width: 9),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
    final enabled = loading ? null : onPressed;
    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: enabled,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.green.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.white,
        ),
        child: content,
      ),
      AppButtonVariant.secondary => ElevatedButton(
        onPressed: enabled,
        child: content,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: enabled,
        child: content,
      ),
      AppButtonVariant.destructive => FilledButton(
        onPressed: enabled,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        child: content,
      ),
    };
    return SizedBox(width: expand ? double.infinity : null, child: button);
  }
}
