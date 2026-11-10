<?php

namespace App\Http\Controllers;

use App\Exceptions\BusinessFailure;
use App\Http\Requests\StartTripRequest;
use App\Models\Depot;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use App\Services\DeliveryResultView;
use App\Services\IdempotencyService;
use App\Services\TripDepartureReviewService;
use App\Services\TripDepartureService;
use App\Services\TripManifestService;
use App\Services\TripScheduleService;
use App\Services\TripReconciliationService;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CourierTripController extends Controller
{
    public function index(Request $request)
    {
        $request->validate(['page' => ['sometimes', 'integer', 'min:1']]);

        return response()->json(['data' => Trip::where('courier_id', $request->user()->id)->whereIn('status', ['assigned', 'in_progress', 'awaiting_reconciliation'])->with('selectedRoute')->orderBy('planned_departure_at')->get()->map(fn ($trip) => $this->data($trip)),
            'recent_completed' => Trip::where('courier_id', $request->user()->id)->where('status', 'completed')->with('selectedRoute')->orderByDesc('actual_return_at')->orderByDesc('id')->limit(5)->get()->map(fn ($trip) => $this->data($trip)),
        ]);
    }

    public function show(Request $request, string $id)
    {
        $trip = Trip::where('courier_id', $request->user()->id)->whereIn('status', ['assigned', 'in_progress', 'awaiting_reconciliation', 'completed'])->with('selectedRoute')->findOrFail($id);

        return response()->json(['data' => $this->data($trip, true)]);
    }

    private function data(Trip $trip, bool $detail = false): array
    {
        $snapshot = $trip->selectedRoute->input_snapshot;
        $data = ['id' => (string) $trip->id, 'trip_number' => $trip->trip_number, 'status' => $trip->status, 'lock_version' => $trip->lock_version, 'planned_departure_at' => $trip->planned_departure_at->toISOString(), 'timezone' => $trip->timezone_snapshot, 'vehicle' => array_diff_key($snapshot['vehicle'], ['lock_version' => 1]), 'total_stops' => count($snapshot['orders']), 'planned_weight_g' => $trip->planned_weight_g, 'planned_volume_cm3' => $trip->planned_volume_cm3, 'feasibility_status' => 'not_evaluated', 'estimated_arrival_at' => null];
        $data['vehicle']['id'] = (string) $data['vehicle']['id'];
        $data['actual_departure_at'] = $trip->actual_departure_at?->toISOString();
        $data['actual_return_at'] = $trip->actual_return_at?->toISOString();
        $data['loaded_weight_g'] = $trip->loaded_weight_g;
        $data['loaded_volume_cm3'] = $trip->loaded_volume_cm3;
        if ($detail) {
            $data['depot'] = array_diff_key($snapshot['depot'], ['lock_version' => 1]);
            $data['depot']['id'] = (string) $data['depot']['id'];
            $data['route_version'] = $trip->selectedRoute->version_number;
            $data['route_version_id'] = (string) $trip->selected_route_version_id;
            $review = app(TripDepartureReviewService::class)->current($trip);
            $load = DB::table('trip_load_confirmations')->where('trip_id', $trip->id)->first();
            $schedule = $load ? json_decode($load->departure_schedule, true, flags: JSON_THROW_ON_ERROR) : $review?->schedule_snapshot;
            $estimates = collect($schedule['stops'] ?? [])->keyBy('order_id');
            $data['stops'] = collect($snapshot['orders'])->values()->map(fn ($order, $i) => ['sequence_no' => $i + 1, 'order_id' => $order['id'], 'order_number' => $order['order_number'], 'address' => $order['address'], 'items' => $order['items'], 'window_start_at' => $order['window_start_at'], 'window_end_at' => $order['window_end_at'], 'total_rp' => $order['total_rp'], 'estimated_arrival_at' => $estimates->get($order['id'])['estimated_arrival_at'] ?? null, 'estimated_service_start_at' => $estimates->get($order['id'])['estimated_service_start_at'] ?? null]);
            $data['manifest'] = app(TripManifestService::class)->forTrip($trip);
            $data['departure_review'] = $review ? ['id' => (string) $review->id, 'source' => $review->source, 'source_reference' => $review->source_reference, 'reviewed_at' => $review->reviewed_at->toISOString(), 'expires_at' => $review->expires_at->toISOString()] : null;
            $data['feasibility_status'] = $review ? 'feasible_manual' : 'not_evaluated';
            $data['estimated_return_at'] = $schedule['estimated_return_at'] ?? null;
            $data['can_start'] = false;
            $data['start_block_reason'] = 'Menunggu tinjauan estimasi jalan oleh admin.';
            if (in_array($trip->status, ['in_progress', 'awaiting_reconciliation', 'completed'], true)) {
                $data['start_block_reason'] = 'Trip sudah berangkat.';
            } elseif ($review && $review->expires_at > now()) {
                if ($trip->planned_departure_at > now()) {
                    $data['start_block_reason'] = 'Belum waktunya berangkat sesuai rencana.';
                } else {
                    try {
                        app(TripDepartureReviewService::class)->assertMasters($snapshot, Depot::findOrFail(1), User::findOrFail($trip->courier_id), Vehicle::findOrFail($trip->vehicle_id));
                        app(TripScheduleService::class)->evaluate($snapshot, $review->leg_seconds, CarbonImmutable::instance(now()));
                        $data['can_start'] = true;
                        $data['start_block_reason'] = null;
                    } catch (BusinessFailure $error) {
                        $data['start_block_reason'] = $error->getMessage();
                    }
                }
            } elseif ($review) {
                $data['start_block_reason'] = 'Tinjauan estimasi jalan kedaluwarsa. Hubungi admin.';
            }
        }

        if ($detail) {
            $data['reconciliation'] = in_array($trip->status, ['awaiting_reconciliation', 'completed'], true) ? app(TripReconciliationService::class)->summary($trip) : null;
            $stops = DB::table('trip_stops')->join('orders', 'orders.id', '=', 'trip_stops.order_id')->where('trip_id', $trip->id)->where('route_version_id', $trip->selected_route_version_id)->orderBy('sequence_no')->get(['trip_stops.id', 'trip_stops.order_id', 'trip_stops.status', 'orders.lock_version'])->keyBy('order_id');
            $next = $stops->firstWhere('status', 'pending');
            $data['stops'] = $data['stops']->map(function ($item) use ($stops, $next, $trip) {
                $stop = $stops->get($item['order_id']);

                return [...$item, 'id' => $stop ? (string) $stop->id : null, 'status' => $stop?->status, 'order_version' => $stop ? (int) $stop->lock_version : null, 'can_record_result' => $trip->status === 'in_progress' && $stop && $next?->id === $stop->id, 'result' => app(DeliveryResultView::class)->forOrder((int) $item['order_id'])];
            });
        }

        return $data;
    }

    public function start(StartTripRequest $request, string $id, TripDepartureService $service, IdempotencyService $idempotency)
    {
        $key = $request->idempotencyKey();
        $payload = $request->payload();
        $result = $idempotency->run($request->user()->id, 'trips.start:'.$id, $key, $payload, fn () => $service->start($request->user()->id, (int) $id, $payload));

        return response()->json($result['body'], $result['status']);
    }
}
