<?php

namespace App\Services;

use App\Models\Depot;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OperationsReport
{
    public function period(Request $request): array
    {
        $zone = Depot::findOrFail(1)->timezone;
        $today = now($zone)->toDateString();
        $data = $request->validate(['from' => ['sometimes', 'date_format:Y-m-d'], 'to' => ['sometimes', 'date_format:Y-m-d'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $from = $data['from'] ?? $today;
        $to = $data['to'] ?? $from;
        $start = CarbonImmutable::parse($from, $zone)->startOfDay();
        $end = CarbonImmutable::parse($to, $zone)->addDay()->startOfDay();
        if ($end <= $start || $start->diffInDays($end) > 366) {
            throw ValidationException::withMessages(['to' => 'Pilih periode berurutan maksimal 366 hari.']);
        }

        return ['from' => $from, 'to' => $to, 'timezone' => $zone, 'start' => $start->utc(), 'end' => $end->utc()];
    }

    private function orders(array $period): Builder
    {
        return DB::table('orders')->where('orders.depot_id', 1)->where('orders.window_start_at', '>=', $period['start'])->where('orders.window_start_at', '<', $period['end']);
    }

    public function rows(array $period): Builder
    {
        return $this->orders($period)
            ->leftJoin('delivery_results', 'delivery_results.order_id', '=', 'orders.id')
            ->leftJoin('payment_collections', 'payment_collections.delivery_result_id', '=', 'delivery_results.id')
            ->leftJoin('active_order_allocations', 'active_order_allocations.order_id', '=', 'orders.id')
            ->leftJoin('trip_stops', 'trip_stops.id', '=', 'delivery_results.trip_stop_id')
            ->leftJoin('trips', 'trips.id', '=', DB::raw('COALESCE(active_order_allocations.trip_id, trip_stops.trip_id)'))
            ->select(['orders.id', 'orders.order_number', 'orders.recipient_name', 'orders.status', 'orders.delivery_type', 'orders.window_start_at', 'orders.subtotal_rp', 'orders.delivery_fee_rp', 'orders.total_rp', 'trips.trip_number'])
            ->selectRaw('COALESCE(payment_collections.amount_rp, 0) as cash_received_rp');
    }

    public function stats(array $period): array
    {
        $statuses = $this->orders($period)->select('status')->selectRaw('COUNT(*) as total')->groupBy('status')->pluck('total', 'status')->map(fn ($value) => (int) $value);
        $cash = DB::table('payment_collections')->join('delivery_results', 'delivery_results.id', '=', 'payment_collections.delivery_result_id')
            ->whereIn('delivery_results.order_id', $this->orders($period)->select('orders.id'))->sum('payment_collections.amount_rp');
        $tripIds = DB::table('trip_stops')->whereIn('order_id', $this->orders($period)->select('orders.id'))->select('trip_id')->distinct();
        $receipts = DB::table('trip_reconciliations')->whereIn('trip_id', $tripIds);
        $stockDifference = DB::table('reconciliation_items')->whereIn('trip_reconciliation_id', (clone $receipts)->select('id'))->sum(DB::raw('ABS(difference)'));

        return ['orders' => $statuses->sum(), 'delivered' => $statuses->get('delivered', 0), 'failed' => $statuses->get('failed', 0),
            'statuses' => $statuses->all(), 'cod_received_rp' => (int) $cash,
            'cod_deposited_rp' => (int) (clone $receipts)->sum('actual_cash_rp'),
            'cash_difference_rp' => (int) (clone $receipts)->sum('cash_difference_rp'), 'stock_difference_items' => (int) $stockDifference];
    }
}
