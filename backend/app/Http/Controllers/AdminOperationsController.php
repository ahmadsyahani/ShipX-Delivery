<?php

namespace App\Http\Controllers;

use App\Models\Depot;
use App\Services\OperationsReport;
use App\Services\TripTracking;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class AdminOperationsController extends Controller
{
    public function monitor()
    {
        return Inertia::render('Admin/Monitor', ['depot' => Depot::findOrFail(1)->only(['name', 'latitude', 'longitude'])]);
    }

    public function positions(TripTracking $tracking)
    {
        return response()->json(['data' => $tracking->monitor(), 'server_time' => now()->toISOString()]);
    }

    public function reports(Request $request, OperationsReport $report)
    {
        $period = $report->period($request);

        $data = DB::transaction(fn () => [
            'filters' => array_intersect_key($period, array_flip(['from', 'to', 'timezone'])),
            'stats' => $report->stats($period),
            'orders' => $report->rows($period)->orderByDesc('orders.id')->paginate(25)->withQueryString(),
        ]);

        return Inertia::render('Admin/Reports', $data);
    }

    public function export(Request $request, OperationsReport $report)
    {
        $period = $report->period($request);

        return response()->streamDownload(function () use ($report, $period) {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            fputcsv($output, ['Pesanan', 'Penerima', 'Tanggal pengantaran', 'Status', 'Layanan', 'Subtotal', 'Ongkir', 'Total COD', 'COD diterima', 'Trip'], ',', '"', '');
            foreach ($report->rows($period)->orderBy('orders.id')->cursor() as $row) {
                $values = [$row->order_number, $row->recipient_name, CarbonImmutable::parse($row->window_start_at, 'UTC')->setTimezone($period['timezone'])->format('Y-m-d H:i'), $row->status, $row->delivery_type, $row->subtotal_rp, $row->delivery_fee_rp, $row->total_rp, $row->cash_received_rp, $row->trip_number ?? ''];
                $values = array_map(fn ($value) => is_string($value) && preg_match('/^[\s\x{FEFF}]*[=+\-@\t\r\n]/u', $value) ? "'".$value : $value, $values);
                fputcsv($output, $values, ',', '"', '');
            }
            fclose($output);
        }, 'shipx-pengiriman-'.$period['from'].'-'.$period['to'].'.csv', ['Content-Type' => 'text/csv; charset=UTF-8', 'Cache-Control' => 'no-store']);
    }
}
