import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../delivery/delivery_page.dart' show slotDate, slotTime;

class DeliverySummary extends StatelessWidget {
  const DeliverySummary({
    super.key,
    this.address,
    this.slot,
    this.onTap,
    this.compact = false,
  });
  final Map<String, dynamic>? address, slot;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(compact ? 0 : 20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(compact ? 0 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  'Diantar ke',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                if (!compact)
                  const Text(
                    'Pengiriman',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    address == null
                        ? 'Pilih alamat pengiriman'
                        : address!['label'] as String,
                    style: TextStyle(
                      fontSize: compact ? 16 : 19,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: onTap == null ? AppColors.border : AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
            if (!compact || address != null) ...[
              const SizedBox(height: 6),
              Text(
                address?['address_text'] as String? ??
                    'Tentukan tujuan dan waktu antarnya.',
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (slot != null) ...[
              SizedBox(height: compact ? 6 : 16),
              if (!compact)
                const Divider(height: 1, color: AppColors.borderLight),
              if (!compact) const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  Text(
                    '${slotDate(slot!['window_start_at'], slot!['timezone'])} · ${slotTime(slot!['window_start_at'], slot!['timezone'])}–${slotTime(slot!['window_end_at'], slot!['timezone'])}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ] else if (!compact)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  'Pilih jadwal pengantaran',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class ShopDock extends StatelessWidget {
  const ShopDock({
    super.key,
    required this.caption,
    required this.amount,
    required this.action,
    required this.onPressed,
    this.buttonKey,
    this.icon,
    this.busy = false,
    this.tinted = false,
  });
  final String caption, amount, action;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final IconData? icon;
  final bool busy, tinted;

  @override
  Widget build(BuildContext context) => Material(
    color: tinted ? const Color(0xFFF0F8F7) : Colors.white,
    child: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 15),
      child: LayoutBuilder(
        builder: (context, box) {
          final stacked =
              box.maxWidth < 310 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.25;
          final price = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          );
          final button = FilledButton(
            key: buttonKey,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            onPressed: busy ? null : onPressed,
            child: Wrap(
              spacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (icon != null)
                  Icon(icon, size: 18),
                Text(action, textAlign: TextAlign.center),
              ],
            ),
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [price, const SizedBox(height: 10), button],
                )
              : Row(
                  children: [
                    Expanded(child: price),
                    const SizedBox(width: 16),
                    Flexible(child: button),
                  ],
                );
        },
      ),
    ),
  );
}

class ShopHeading extends StatelessWidget {
  const ShopHeading(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}
