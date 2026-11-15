import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactButton extends StatelessWidget {
  const ContactButton({super.key, required this.phone, required this.label});
  final String? phone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final number = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (!RegExp(r'^\+?[0-9]{3,30}$').hasMatch(number)) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: () async {
        var opened = false;
        try {
          opened = await launchUrl(
            Uri(scheme: 'tel', path: number),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          opened = false;
        }
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aplikasi telepon belum dapat dibuka.'),
            ),
          );
        }
      },
      icon: const Icon(Icons.phone_outlined, size: 18),
      label: Text(label),
    );
  }
}
