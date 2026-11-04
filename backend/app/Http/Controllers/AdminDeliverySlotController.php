<?php

namespace App\Http\Controllers;

use App\Models\DeliverySlot;
use App\Models\Depot;
use Carbon\CarbonImmutable;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

class AdminDeliverySlotController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate(['date' => ['nullable', 'date_format:Y-m-d'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $query = DeliverySlot::where('depot_id', 1);
        if ($date = $filters['date'] ?? null) {
            $query->whereDate('service_date', $date);
        }

        return Inertia::render('Admin/Slots/Index', ['filters' => ['date' => $filters['date'] ?? ''], 'serverNow' => now()->toISOString(), 'slots' => $query->orderByDesc('service_date')->orderBy('window_start_at')->orderBy('id')->paginate(20)->withQueryString(), 'depot' => Depot::findOrFail(1)]);
    }

    public function create()
    {
        return Inertia::render('Admin/Slots/Form', ['slot' => null, 'depot' => Depot::findOrFail(1)]);
    }

    public function edit(DeliverySlot $slot)
    {
        abort_unless((int) $slot->depot_id === 1, 404);

        return Inertia::render('Admin/Slots/Form', ['slot' => $slot, 'depot' => Depot::findOrFail(1)]);
    }

    public function store(Request $request)
    {
        return $this->persist($request);
    }

    public function update(Request $request, DeliverySlot $slot)
    {
        return $this->persist($request, $slot);
    }

    private function persist(Request $request, ?DeliverySlot $slot = null)
    {
        $data = $request->validate(['service_date' => ['required', 'date_format:Y-m-d'], 'start_time' => ['required', 'date_format:H:i'], 'end_time' => ['required', 'date_format:H:i'], 'cutoff_local' => ['required', 'date_format:Y-m-d\TH:i'], 'is_active' => ['required', 'boolean'], 'lock_version' => [$slot ? 'required' : 'sometimes', 'integer', 'min:0']]);

        return DB::transaction(function () use ($data, $slot, $request) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            if (! $depot->configured()) {
                throw ValidationException::withMessages(['service_date' => 'Lengkapi konfigurasi depot sebelum membuat slot.']);
            }
            $record = $slot ? DeliverySlot::where('depot_id', 1)->lockForUpdate()->findOrFail($slot->id) : new DeliverySlot;
            if ($slot && $record->lock_version !== (int) $data['lock_version']) {
                return Inertia::render('Admin/Conflict', ['message' => 'Slot telah diperbarui. Muat jadwal terbaru sebelum mengedit kembali.', 'reloadUrl' => route('admin.slots.edit', $record)])->toResponse($request)->setStatusCode(409);
            }
            $start = CarbonImmutable::createFromFormat('!Y-m-d H:i', $data['service_date'].' '.$data['start_time'], $depot->timezone);
            $end = CarbonImmutable::createFromFormat('!Y-m-d H:i', $data['service_date'].' '.$data['end_time'], $depot->timezone);
            $cutoff = CarbonImmutable::createFromFormat('!Y-m-d\TH:i', $data['cutoff_local'], $depot->timezone);
            if ($end <= $start) {
                throw ValidationException::withMessages(['end_time' => 'Waktu selesai harus setelah waktu mulai pada tanggal yang sama.']);
            }
            if ($cutoff > $start) {
                throw ValidationException::withMessages(['cutoff_local' => 'Batas pemesanan tidak boleh melewati waktu mulai pengiriman.']);
            }
            if ($data['is_active'] && ($cutoff <= now() || $start > now()->addDays(365))) {
                throw ValidationException::withMessages(['cutoff_local' => 'Slot aktif harus belum cutoff dan maksimal 365 hari ke depan.']);
            }
            $record->depot_id = 1;
            $record->fill(['service_date' => $data['service_date'], 'window_start_at' => $start->utc(), 'window_end_at' => $end->utc(), 'cutoff_at' => $cutoff->utc(), 'is_active' => $data['is_active']]);
            if ($slot) {
                $record->lock_version++;
            }
            try {
                $record->save();
            } catch (UniqueConstraintViolationException) {
                throw ValidationException::withMessages(['start_time' => 'Slot dengan rentang waktu yang sama sudah ada. Edit slot tersebut.']);
            }

            return redirect()->route('admin.slots.index')->with('status', $slot ? 'Perubahan slot disimpan.' : 'Slot pengiriman ditambahkan.');
        });
    }
}
