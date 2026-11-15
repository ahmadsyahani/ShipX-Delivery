<?php

namespace App\Observers;

use App\Models\Trip;
use App\Models\User;
use App\Notifications\OperationalNotification;

class TripObserver
{
    public function updated(Trip $trip): void
    {
        if (! $trip->wasChanged('status')) {
            return;
        }
        $message = match ($trip->status) {
            'assigned' => 'Ada penugasan trip baru. Tinjau muatan dan jadwal keberangkatan.',
            'in_progress' => 'Trip dimulai. Buka navigasi untuk membagikan posisi pengiriman.',
            'awaiting_reconciliation' => 'Seluruh tujuan ditangani. Kembalikan barang dan setorkan COD ke admin.',
            'completed' => 'Rekonsiliasi selesai. Barang dan setoran sudah diperiksa admin.',
            'draft' => 'Penugasan dibuka ulang untuk ditinjau admin.',
            'cancelled' => 'Trip dibatalkan oleh admin.',
            default => null,
        };
        if ($message === null) {
            return;
        }
        $courier = User::where('role', 'courier')->where('is_active', true)->find($trip->courier_id);
        $courier?->notify(new OperationalNotification(['title' => $trip->trip_number, 'message' => $message,
            'kind' => in_array($trip->status, ['draft', 'cancelled'], true) ? 'notice' : 'trip',
            'target_id' => (string) $trip->id, 'status' => $trip->status]));
    }
}
