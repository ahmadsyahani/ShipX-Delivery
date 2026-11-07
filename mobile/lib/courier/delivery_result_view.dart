import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/auth_session.dart';
import '../core/app_widgets.dart';
import '../core/app_theme.dart';
import '../catalog_page.dart' show rupiah;

class DeliveryResultView extends StatelessWidget {
  const DeliveryResultView({
    super.key,
    required this.session,
    required this.result,
  });
  final AuthSession session;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: result['outcome'] == 'delivered'
              ? 'Kiriman berhasil diserahkan'
              : 'Kiriman gagal',
          icon: result['outcome'] == 'delivered'
              ? Icons.task_alt_rounded
              : Icons.error_outline_rounded,
        ),
        Text(
          'COD diterima ${rupiah(result['cash_received_rp'])}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        if (result['failure_reason'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InfoBanner(
              message: result['failure_reason'],
              color: AppColors.error,
              backgroundColor: AppColors.errorBg,
            ),
          ),
        if (result['notes'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              result['notes'],
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        if (result['proof_id'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeliveryProofPage(
                    session: session,
                    id: result['proof_id'].toString(),
                  ),
                ),
              ),
              icon: const Icon(Icons.photo_outlined),
              label: const Text('Lihat foto bukti'),
            ),
          ),
      ],
    ),
  );
}

class DeliveryProofPage extends StatefulWidget {
  const DeliveryProofPage({super.key, required this.session, required this.id});
  final AuthSession session;
  final String id;
  @override
  State<DeliveryProofPage> createState() => _DeliveryProofPageState();
}

class _DeliveryProofPageState extends State<DeliveryProofPage> {
  late Future<Uint8List> _photo;
  @override
  void initState() {
    super.initState();
    _photo = widget.session.proofPhoto(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Foto bukti')),
    body: FutureBuilder<Uint8List>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Center(
            child: InteractiveViewer(child: Image.memory(snapshot.data!)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Foto belum dapat dimuat.'),
                TextButton(
                  onPressed: () => setState(
                    () => _photo = widget.session.proofPhoto(widget.id),
                  ),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    ),
  );
}
