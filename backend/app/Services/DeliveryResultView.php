<?php

namespace App\Services;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

class DeliveryResultView
{
    public function forOrder(int $order, bool $admin = false): ?array
    {
        $result = DB::table('delivery_results')->where('order_id', $order)->first();
        if (! $result) {
            return null;
        }
        $proof = DB::table('delivery_proofs')->where('delivery_result_id', $result->id)->first();
        $payment = DB::table('payment_collections')->where('delivery_result_id', $result->id)->first();

        return ['id' => (string) $result->id, 'outcome' => $result->outcome, 'failure_reason' => $result->failure_reason, 'notes' => $result->notes, 'recorded_at' => CarbonImmutable::parse($result->recorded_at, 'UTC')->toISOString(), 'cash_received_rp' => $payment ? (int) $payment->amount_rp : 0, 'proof_id' => $proof ? (string) $proof->id : null, 'proof_url' => $proof ? ($admin ? '/admin/delivery-proofs/' : '/api/v1/delivery-proofs/').$proof->id : null];
    }
}
