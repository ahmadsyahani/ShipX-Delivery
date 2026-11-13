<?php

namespace App\Http\Controllers;

use App\Exceptions\BusinessFailure;
use App\Models\Trip;
use App\Services\IdempotencyService;
use App\Services\TripOptimizationService;
use Illuminate\Http\Request;
use Inertia\Inertia;

class TripOptimizationController extends Controller
{
    public function preview(Request $request, Trip $trip, TripOptimizationService $service)
    {
        abort_unless($trip->depot_id === 1, 404);
        $data = $request->validate(['recommend_departure' => ['sometimes', 'boolean'], 'lock_version' => ['required', 'integer', 'min:0'], 'source_reference' => ['required', 'string', 'max:500'],
            'matrix_minutes' => ['required', 'array', 'min:2', 'max:21'], 'matrix_minutes.*' => ['required', 'array', 'min:2', 'max:21'], 'matrix_minutes.*.*' => ['required', 'integer', 'min:0', 'max:1440']]);
        $data['lock_version'] = (int) $data['lock_version'];
        try {
            return response()->json(['data' => $service->preview($request->user()->id, $trip->id, $data)]);
        } catch (BusinessFailure $error) {
            return response()->json($error->body(), $error->status);
        }
    }

    public function apply(Request $request, Trip $trip, TripOptimizationService $service, IdempotencyService $idempotency)
    {
        abort_unless($trip->depot_id === 1, 404);
        $data = $request->validate(['idempotency_key' => ['required', 'uuid'], 'optimization_id' => ['required', 'uuid'], 'lock_version' => ['required', 'integer', 'min:0']]);
        $key = strtolower($data['idempotency_key']);
        unset($data['idempotency_key']);
        $data['lock_version'] = (int) $data['lock_version'];
        $result = $idempotency->run($request->user()->id, 'trips.optimize:'.$trip->id, $key, $data, fn () => $service->apply($request->user()->id, $trip->id, $data));
        if ($result['status'] !== 200) {
            return Inertia::render('Admin/Conflict', ['message' => $result['body']['message'], 'reloadUrl' => route('admin.trips.show', $trip)])->toResponse($request)->setStatusCode($result['status']);
        }

        return redirect()->route('admin.trips.show', $trip)->with('status', 'Rute hasil optimasi diterapkan. Tinjau keberangkatan setelah trip ditetapkan.');
    }
}
