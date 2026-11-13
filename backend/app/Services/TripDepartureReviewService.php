<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\Trip;
use App\Models\TripDepartureReview;
use App\Models\User;
use App\Models\Vehicle;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

class TripDepartureReviewService
{
    public function current(Trip $trip): ?TripDepartureReview
    {
        $reviewId = DB::table('trip_load_confirmations')->where('trip_id', $trip->id)->value('departure_review_id');

        return TripDepartureReview::where('trip_id', $trip->id)->where('route_version_id', $trip->selected_route_version_id)
            ->when($reviewId, fn ($q) => $q->where('id', $reviewId), fn ($q) => $q->where('trip_version', $trip->lock_version))->first();
    }

    public function review(int $actor, int $id, array $data): array
    {
        return DB::transaction(function () use ($actor, $id, $data) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            $trip = Trip::where('depot_id', 1)->findOrFail($id);
            $courier = User::lockForUpdate()->findOrFail($trip->courier_id);
            $vehicle = Vehicle::lockForUpdate()->findOrFail($trip->vehicle_id);
            $trip = Trip::lockForUpdate()->findOrFail($id);
            if ($trip->lock_version !== $data['lock_version']) {
                throw new BusinessFailure('STALE_VERSION', 'Trip berubah. Muat ulang sebelum meninjau keberangkatan.');
            }
            if ($trip->status !== 'assigned' || $trip->actual_departure_at !== null) {
                throw new BusinessFailure('TRIP_LOCKED', 'Tinjauan hanya untuk trip yang sudah ditetapkan dan belum berangkat.');
            }
            if (($data['handling_checked'] ?? false) !== true) {
                throw new BusinessFailure('HANDLING_NOT_REVIEWED', 'Tinjau dimensi dan penanganan barang terlebih dahulu.');
            }
            $snapshot = $trip->selectedRoute->input_snapshot;
            $versions = $this->assertMasters($snapshot, $depot, $courier, $vehicle);
            $now = CarbonImmutable::instance(now());
            $expires = $now->addDay();
            if ($trip->planned_departure_at >= $expires) {
                throw new BusinessFailure('REVIEW_TOO_EARLY', 'Tinjau estimasi jalan dalam 24 jam sebelum rencana keberangkatan.');
            }
            $legs = array_map(fn ($minutes) => (int) $minutes * 60, $data['leg_minutes']);
            $schedule = app(TripScheduleService::class)->evaluate($snapshot, $legs, $trip->planned_departure_at->max($now));
            $trip->lock_version++;
            $review = TripDepartureReview::create(['trip_id' => $id, 'route_version_id' => $trip->selected_route_version_id, 'trip_version' => $trip->lock_version, 'source' => 'manual_road_estimate', 'source_reference' => $data['source_reference'], 'leg_seconds' => $legs, 'schedule_snapshot' => $schedule, 'master_versions' => $versions, 'reviewed_by' => $actor, 'reason' => $data['reason'], 'handling_checked' => true, 'reviewed_at' => $now, 'expires_at' => $expires]);
            $trip->save();
            DB::table('trip_events')->insert(['trip_id' => $id, 'actor_id' => $actor, 'action' => 'departure_reviewed', 'trip_version' => $trip->lock_version, 'reason' => $data['reason'], 'created_at' => $now]);

            return ['status' => 200, 'body' => ['data' => ['id' => (string) $id, 'review_id' => (string) $review->id, 'lock_version' => $trip->lock_version]]];
        });
    }

    public function assertMasters(array $snapshot, Depot $depot, User $courier, Vehicle $vehicle): array
    {
        if (! $courier->is_active || $courier->role !== 'courier' || ! $vehicle->is_active || $vehicle->depot_id !== 1) {
            throw new BusinessFailure('FLEET_UNAVAILABLE', 'Kurir atau kendaraan tidak tersedia. Hubungi admin.');
        }
        $versions = ['depot' => $depot->lock_version, 'courier' => $courier->lock_version, 'vehicle' => $vehicle->lock_version];
        foreach ($versions as $name => $version) {
            if ($version !== $snapshot[$name]['lock_version']) {
                throw new BusinessFailure('PLAN_CHANGED', 'Master depot/armada berubah. Admin perlu membuka ulang dan meninjau rencana.');
            }
        }

        if (isset($snapshot['operating_hours']) && count($snapshot['orders']) > 0) {
            $date = CarbonImmutable::parse($snapshot['orders'][0]['window_start_at'])->setTimezone($depot->timezone)->toDateString();
            [$opens, $closes] = app(DeliveryPolicy::class)->bounds($depot, $date);
            if ($snapshot['operating_hours'] !== ['opens_at' => $opens->toISOString(), 'closes_at' => $closes->toISOString()]) {
                throw new BusinessFailure('PLAN_CHANGED', 'Kalender jam layanan berubah. Buka ulang dan tinjau rencana trip.');
            }
        }

        return $versions;
    }
}
