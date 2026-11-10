import 'package:flutter/material.dart';
import '../core/app_widgets.dart';
import '../catalog_page.dart' show rupiah;
import '../delivery/delivery_page.dart' show slotDate, slotTime;

class ReconciliationView extends StatelessWidget {
  const ReconciliationView({
    super.key,
    required this.summary,
    required this.timezone,
  });
  final Map<String, dynamic> summary;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final record = summary['record'] as Map<String, dynamic>?;
    final rows = ((record ?? summary)['items'] as List)
        .cast<Map<String, dynamic>>();
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionTitle(
            title: record == null
                ? 'Kembali & serahkan ke admin'
                : 'Trip selesai. Terima kasih!',
            subtitle: record == null
                ? 'Barang tersisa dan setoran diperiksa bersama di depot.'
                : 'Barang dan uang sudah diterima. Kamu siap untuk trip berikutnya.',
            icon: record == null
                ? Icons.assignment_return_outlined
                : Icons.verified_outlined,
          ),
          const SizedBox(height: 18),
          AppAmountLine(
            label: 'COD tercatat',
            value: rupiah(summary['expected_cash_rp'] as int),
          ),
          if (record != null) ...[
            const SizedBox(height: 10),
            AppAmountLine(
              label: 'Setoran diterima',
              value: rupiah(record['actual_cash_rp'] as int),
            ),
            const SizedBox(height: 10),
            AppAmountLine(
              label: 'Selisih setoran',
              value: rupiah(record['cash_difference_rp'] as int),
            ),
            if (record['discrepancy_reason'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Catatan setoran: ${record['discrepancy_reason']}'),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Disetujui admin pada ${slotDate(record['approved_at'], timezone)} ${slotTime(record['approved_at'], timezone)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Siapkan setoran sesuai catatan COD. Admin mencatat jumlah uang dan kondisi barang yang benar-benar diterima.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Divider(height: 32),
          Text(
            record == null
                ? 'Barang yang perlu kembali'
                : 'Hasil pemeriksaan barang',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          ...rows
              .where(
                (row) =>
                    record != null || (row['expected_quantity'] as int) > 0,
              )
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        record == null
                            ? '${row['expected_quantity']} item · ${row['stock_state'] == 'available' ? 'Layak jual' : 'Karantina'}'
                            : '${row['actual_quantity']} item diterima · ${row['stock_state'] == 'available' ? 'Layak jual' : 'Karantina'} · Selisih ${row['difference']}',
                      ),
                      if (row['discrepancy_reason'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            row['discrepancy_reason'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          if (record == null &&
              rows.every((row) => (row['expected_quantity'] as int) == 0))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Tidak ada sisa barang yang tercatat. Tetap konfirmasikan dengan admin.',
              ),
            ),
        ],
      ),
    );
  }
}
