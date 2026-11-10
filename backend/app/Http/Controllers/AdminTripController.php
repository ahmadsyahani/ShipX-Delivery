<?php

namespace App\Http\Controllers;

use App\Http\Requests\TripPlanRequest;
use App\Models\Depot;
use App\Models\Order;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use App\Services\IdempotencyService;
use App\Services\ManualTripService;
use App\Services\TripDepartureReviewService;
use App\Services\TripManifestService;
use App\Services\TripReconciliationService;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Inertia\Inertia;

class AdminTripController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate(['status' => ['nullable', 'in:draft,assigned,in_progress,awaiting_reconciliation,completed,cancelled'], 'page' => ['sometimes', 'integer', 'min:1']]);

        return Inertia::render('Admin/Trips/Index', ['trips' => Trip::where('depot_id', 1)->when($filters['status'] ?? null, fn ($q, $status) => $q->where('status', $status))->with('selectedRoute')->latest('id')->paginate(20)->withQueryString(), 'filters' => ['status' => $filters['status'] ?? '']]);
    }

    public function create()
    {
        return $this->form();
    }

    public function edit(Trip $trip)
    {
        abort_unless($trip->depot_id === 1, 404);
        if ($trip->status !== 'draft') {
            return redirect()->route('admin.trips.show', $trip)->with('status', 'Buka ulang penugasan sebelum mengedit rencana.');
        }

        return $this->form($trip);
    }

    private function form(?Trip $trip = null)
    {
        return Inertia::render('Admin/Trips/Form', [
            'trip' => $trip?->load('selectedRoute'), 'timezone' => Depot::findOrFail(1)->timezone, 'idempotencyKey' => Str::uuid()->toString(),
            'orders' => Order::where('depot_id', 1)->where('status', 'confirmed')->where('window_end_at', '>', now())->whereNotIn('id', DB::table('active_order_allocations')->select('order_id'))->orderBy('window_start_at')->orderBy('id')->get(['id', 'order_number', 'delivery_slot_id', 'recipient_name', 'address_text', 'window_start_at', 'window_end_at', 'total_weight_g', 'total_volume_cm3', 'lock_version']),
            'couriers' => User::where('role', 'courier')->where('is_active', true)->whereNotIn('id', DB::table('courier_trip_locks')->select('courier_id'))->orderBy('name')->get(['id', 'name']),
            'vehicles' => Vehicle::where('depot_id', 1)->where('is_active', true)->whereNotIn('id', DB::table('vehicle_trip_locks')->select('vehicle_id'))->orderBy('code')->get(),
        ]);
    }

    public function show(Trip $trip)
    {
        abort_unless($trip->depot_id === 1, 404);
        $events = DB::table('trip_events')->join('users', 'users.id', '=', 'trip_events.actor_id')->where('trip_id', $trip->id)->orderByDesc('trip_events.id')->get(['action', 'reason', 'trip_version', 'trip_events.created_at', 'users.name'])->map(function ($event) {
            $event->created_at = CarbonImmutable::parse($event->created_at, 'UTC')->toISOString();

            return $event;
        });

        $load = DB::table('trip_load_confirmations')->where('trip_id', $trip->id)->first();

        return Inertia::render('Admin/Trips/Show', ['trip' => $trip->load(['selectedRoute', 'routes']), 'events' => $events, 'actionKeys' => collect(['assign', 'reopen', 'cancel', 'review', 'reconcile'])->mapWithKeys(fn ($a) => [$a => Str::uuid()->toString()]), 'manifest' => app(TripManifestService::class)->forTrip($trip), 'departureReview' => app(TripDepartureReviewService::class)->current($trip), 'departureSchedule' => $load ? json_decode($load->departure_schedule, true, flags: JSON_THROW_ON_ERROR) : null,
            'reconciliation' => in_array($trip->status, ['awaiting_reconciliation', 'completed'], true) ? app(TripReconciliationService::class)->summary($trip) : null,
            'returnProducts' => $trip->status === 'awaiting_reconciliation' ? \App\Models\Product::where('depot_id', 1)->orderBy('name')->get(['id', 'name', 'sku']) : [],
        ]);
    }

    public function store(TripPlanRequest $request, ManualTripService $service, IdempotencyService $idempotency)
    {
        return $this->save($request, $service, $idempotency);
    }

    public function update(TripPlanRequest $request, Trip $trip, ManualTripService $service, IdempotencyService $idempotency)
    {
        abort_unless($trip->depot_id === 1, 404);

        return $this->save($request, $service, $idempotency, $trip);
    }

    private function save(TripPlanRequest $request, ManualTripService $service, IdempotencyService $idempotency, ?Trip $trip = null)
    {
        $payload = $request->safe()->except('idempotency_key');
        $result = $idempotency->run($request->user()->id, $trip ? 'trips.update:'.$trip->id : 'trips.create', strtolower($request->validated('idempotency_key')), $payload, fn () => $service->save($request->user()->id, $payload, $trip?->id));

        return $this->respond($request, $result, $trip ? route('admin.trips.edit', $trip) : route('admin.trips.create'));
    }

    public function action(Request $request, Trip $trip, string $action, ManualTripService $service, IdempotencyService $idempotency)
    {
        abort_unless($trip->depot_id === 1, 404);
        $data = $request->validate(['idempotency_key' => ['required', 'uuid'], 'lock_version' => ['required', 'integer', 'min:0'], 'reason' => [$action === 'assign' ? 'nullable' : 'required', 'string', 'max:500']]);
        $key = strtolower($data['idempotency_key']);
        unset($data['idempotency_key']);
        $result = $idempotency->run($request->user()->id, 'trips.'.$action.':'.$trip->id, $key, $data, fn () => $service->act($request->user()->id, $trip->id, (int) $data['lock_version'], $action, $data['reason'] ?? null));

        return $this->respond($request, $result, route('admin.trips.show', $trip));
    }

    private function respond(Request $request, array $result, string $reloadUrl)
    {
        if ($result['status'] !== 200) {
            return Inertia::render('Admin/Conflict', ['message' => $result['body']['message'], 'reloadUrl' => $reloadUrl])->toResponse($request)->setStatusCode($result['status']);
        }

        return redirect()->route('admin.trips.show', $result['body']['data']['id'])->with('status', 'Perubahan trip disimpan.');
    }

    public function review(Request $request, Trip $trip, TripDepartureReviewService $service, IdempotencyService $idempotency)
    {
        abort_unless($trip->depot_id === 1, 404);
        $data = $request->validate(['idempotency_key' => ['required', 'uuid'], 'lock_version' => ['required', 'integer', 'min:0'], 'leg_minutes' => ['required', 'array', 'min:2', 'max:21'], 'leg_minutes.*' => ['required', 'integer', 'min:0', 'max:1440'], 'source_reference' => ['required', 'string', 'max:500'], 'reason' => ['required', 'string', 'max:500'], 'handling_checked' => ['required', 'accepted'], 'reviewed_by' => ['missing'], 'status' => ['missing']]);
        $key = strtolower($data['idempotency_key']);
        unset($data['idempotency_key']);
        $data['lock_version'] = (int) $data['lock_version'];
        $data['leg_minutes'] = array_map('intval', $data['leg_minutes']);
        $data['handling_checked'] = true;
        $result = $idempotency->run($request->user()->id, 'trips.review:'.$trip->id, $key, $data, fn () => $service->review($request->user()->id, $trip->id, $data));

        return $this->respond($request, $result, route('admin.trips.show', $trip));
    }

    public function reconcile(Request $request, Trip $trip, TripReconciliationService $service, IdempotencyService $idempotency)
    {
        abort_unless($trip->depot_id === 1, 404);
        $data = $request->validate([
            'idempotency_key' => ['required', 'uuid'], 'lock_version' => ['required', 'integer', 'min:0'],
            'actual_cash_rp' => ['required', 'integer', 'min:0', 'max:100000000000000'],
            'discrepancy_reason' => ['nullable', 'string', 'max:500'],
            'received_and_approved' => ['required', 'accepted'],
            'items' => ['required', 'array', 'min:1', 'max:500'],
            'items.*' => ['required', 'array:product_id,available_quantity,quarantine_quantity,discrepancy_reason'],
            'items.*.product_id' => ['required', 'integer', 'min:1', 'distinct'],
            'items.*.available_quantity' => ['required', 'integer', 'min:0', 'max:1000000'],
            'items.*.quarantine_quantity' => ['required', 'integer', 'min:0', 'max:1000000'],
            'items.*.discrepancy_reason' => ['nullable', 'string', 'max:500'],
            'expected_cash_rp' => ['missing'], 'approved_by' => ['missing'], 'status' => ['missing'],
        ]);
        $key = strtolower($data['idempotency_key']);
        unset($data['idempotency_key']);
        $data['lock_version'] = (int) $data['lock_version'];
        $data['actual_cash_rp'] = (int) $data['actual_cash_rp'];
        $data['discrepancy_reason'] = $data['discrepancy_reason'] ?? null;
        $data['received_and_approved'] = true;
        $data['items'] = array_map(fn ($row) => ['product_id' => (int) $row['product_id'], 'available_quantity' => (int) $row['available_quantity'], 'quarantine_quantity' => (int) $row['quarantine_quantity'], 'discrepancy_reason' => $row['discrepancy_reason'] ?? null], $data['items']);
        usort($data['items'], fn ($a, $b) => $a['product_id'] <=> $b['product_id']);
        $result = $idempotency->run($request->user()->id, 'trips.reconcile:'.$trip->id, $key, $data, fn () => $service->close($request->user()->id, $trip->id, $data));

        return $this->respond($request, $result, route('admin.trips.show', $trip));
    }
}
