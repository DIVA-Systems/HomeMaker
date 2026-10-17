import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/hm_colors.dart';

class HmPrimaryButton extends StatelessWidget {
  const HmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: onPressed == null
              ? HmColors.spruce.withValues(alpha: 0.35)
              : HmColors.spruce,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: HmColors.inkOnAccent),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: HmColors.inkOnAccent,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class HmGhostButton extends StatelessWidget {
  const HmGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onPressed,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: HmColors.spruceSoft,
            ),
      ),
    );
  }
}

class HmIconChip extends StatelessWidget {
  const HmIconChip({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? HmColors.spruce : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 22,
            color: !enabled
                ? HmColors.inkTertiary.withValues(alpha: 0.45)
                : selected
                    ? HmColors.inkOnAccent
                    : HmColors.inkSecondary,
          ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
