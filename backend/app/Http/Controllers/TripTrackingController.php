<?php

namespace App\Http\Controllers;

use App\Exceptions\BusinessFailure;
use App\Services\TripTracking;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Http\Request;

class TripTrackingController extends Controller
{
    public function publish(Request $request, int $id, TripTracking $tracking)
    {
        $data = $request->validate([
            'session_id' => ['required', 'uuid'], 'route_version_id' => ['required', 'integer', 'min:1'],
            'latitude' => ['required', 'numeric', 'between:-90,90'], 'longitude' => ['required', 'numeric', 'between:-180,180'],
            'accuracy_m' => ['required', 'numeric', 'between:0,40'], 'heading' => ['nullable', 'numeric', 'between:0,360'],
            'recorded_at' => ['required', 'date'],
        ]);
        $data['route_version_id'] = (int) $data['route_version_id'];
        foreach (['latitude', 'longitude', 'accuracy_m'] as $field) {
            $data[$field] = (float) $data[$field];
        }
        $data['heading'] = isset($data['heading']) ? (float) $data['heading'] : null;
        $token = $request->user()->currentAccessToken();
        abort_unless($token instanceof \Laravel\Sanctum\PersonalAccessToken, 403);
        $data['token_id'] = $token->id;
        try {
            return response()->json(['data' => $tracking->publish($request->user()->id, $id, $data)]);
        } catch (BusinessFailure $error) {
            return response()->json($error->body(), $error->status);
        } catch (LockTimeoutException) {
            return response()->json(['message' => 'Lokasi sedang diperbarui. Coba lagi.', 'code' => 'TRACKING_BUSY'], 409);
        }
    }

    public function stop(Request $request, int $id, TripTracking $tracking)
    {
        $data = $request->validate(['session_id' => ['required', 'uuid'], 'route_version_id' => ['required', 'integer', 'min:1']]);
        $data['route_version_id'] = (int) $data['route_version_id'];
        try {
            return response()->json(['data' => $tracking->publish($request->user()->id, $id, $data, true)]);
        } catch (LockTimeoutException) {
            return response()->json(['message' => 'Pelacakan sedang diperbarui. Coba lagi.'], 409);
        }
    }

    public function show(Request $request, int $id, TripTracking $tracking)
    {
        return response()->json(['data' => $tracking->customer($request->user()->id, $id)]);
    }
}
