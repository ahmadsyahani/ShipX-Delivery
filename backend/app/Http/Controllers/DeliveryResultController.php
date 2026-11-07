<?php

namespace App\Http\Controllers;

use App\Services\DeliveryResultService;
use App\Services\IdempotencyService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class DeliveryResultController extends Controller
{
    public function store(Request $request, string $id, string $stop, DeliveryResultService $service, IdempotencyService $idempotency)
    {
        $key = Validator::make(['key' => $request->header('Idempotency-Key')], ['key' => ['required', 'uuid']])->validate()['key'];
        $data = $request->validate(['trip_version' => ['required', 'integer', 'min:0'], 'order_version' => ['required', 'integer', 'min:0'], 'outcome' => ['required', 'in:delivered,failed'], 'cash_received_rp' => ['required', 'integer', 'min:0'], 'failure_reason' => ['required_if:outcome,failed', 'nullable', 'string', 'max:500'], 'notes' => ['nullable', 'string', 'max:500'], 'proof_upload_id' => ['required_if:outcome,delivered', 'nullable', 'uuid'], 'items' => ['missing'], 'recorded_by' => ['missing'], 'payment_status' => ['missing']]);
        $payload = ['trip_version' => (int) $data['trip_version'], 'order_version' => (int) $data['order_version'], 'outcome' => $data['outcome'], 'cash_received_rp' => (int) $data['cash_received_rp'], 'failure_reason' => $data['outcome'] === 'failed' ? $data['failure_reason'] : null, 'notes' => $data['notes'] ?? null, 'proof_upload_id' => isset($data['proof_upload_id']) ? strtolower($data['proof_upload_id']) : null];
        $result = $idempotency->run($request->user()->id, 'stops.result:'.$id.':'.$stop, strtolower($key), $payload, fn () => $service->record($request->user()->id, (int) $id, (int) $stop, $payload));

        return response()->json($result['body'], $result['status']);
    }
}
