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
            if (slot?['delivery_type'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  slot!['delivery_type'] == 'express' ? 'Express' : 'Reguler',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
    this.compact = false,
  });
  final String caption, amount, action;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final IconData? icon;
  final bool busy, tinted, compact;

  @override
  Widget build(BuildContext context) => Material(
    color: tinted ? const Color(0xFFF0F8F7) : Colors.white,
    child: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: EdgeInsets.fromLTRB(20, compact ? 8 : 13, 20, compact ? 8 : 15),
      child: LayoutBuilder(
        builder: (context, box) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stacked =
              box.maxWidth < (compact ? 240 : 350) * textScale ||
              textScale > 1.25;
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
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
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
              minimumSize: compact ? const Size(48, 40) : null,
              textStyle: compact
                  ? const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 22,
                vertical: compact ? 8 : 14,
              ),
            ),
            onPressed: busy ? null : onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (icon != null)
                  Icon(icon, size: 18),
                if (busy || icon != null) const SizedBox(width: 7),
                Flexible(child: Text(action, textAlign: TextAlign.center)),
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
                    if (compact) button else Expanded(child: button),
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

class CodTotal extends StatelessWidget {
  const CodTotal({super.key, required this.amount, this.amountKey});
  final String amount;
  final Key? amountKey;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        const label = Text(
          'Total COD',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        );
        final value = Text(
          amount,
          key: amountKey,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 19,
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        );
        if (box.maxWidth < 240 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [label, const SizedBox(height: 6), value],
          );
        }
        return Row(
          children: [
            label,
            const SizedBox(width: 12),
            Expanded(child: value),
          ],
        );
      },
    ),
  );
}
