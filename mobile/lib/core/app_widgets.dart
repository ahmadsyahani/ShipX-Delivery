import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class AppPageIntro extends StatelessWidget {
  const AppPageIntro({
    super.key,
    required this.title,
    required this.description,
  });
  final String title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.action,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    ),
  );
}

class AppAmountLine extends StatelessWidget {
  const AppAmountLine({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label, value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasis ? 15 : 13,
              color: emphasis ? AppColors.textMain : AppColors.textMuted,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasis ? 20 : 14,
              fontWeight: FontWeight.w800,
              color: emphasis ? AppColors.primaryDark : AppColors.textMain,
            ),
          ),
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.text});

  final String status;
  final String? text;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case 'pending':
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'confirmed':
        bg = AppColors.infoBg;
        fg = AppColors.info;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'assigned':
        bg = AppColors.primaryLight;
        fg = AppColors.primary;
        icon = Icons.assignment_turned_in_outlined;
        break;
      case 'out_for_delivery':
      case 'in_progress':
        bg = AppColors.purpleBg;
        fg = AppColors.purple;
        icon = Icons.local_shipping_outlined;
        break;
      case 'delivered':
        bg = AppColors.successBg;
        fg = AppColors.success;
        icon = Icons.done_all_rounded;
        break;
      case 'rejected':
      case 'cancelled':
      case 'failed':
        bg = AppColors.errorBg;
        fg = AppColors.error;
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = AppColors.borderLight;
        fg = AppColors.textMuted;
        icon = Icons.info_outline;
    }

    final displayText = text ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.primaryLight,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color.withValues(alpha: 0.95),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
