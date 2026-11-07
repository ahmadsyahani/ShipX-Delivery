<?php

namespace App\Http\Controllers;

use App\Http\Requests\VehicleRequest;
use App\Models\Vehicle;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

class VehicleController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate(['q' => ['nullable', 'string', 'max:100'], 'status' => ['nullable', 'in:active,inactive'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $query = Vehicle::where('depot_id', 1);
        if ($q = $filters['q'] ?? null) {
            $plate = strtoupper(preg_replace('/[\s-]+/u', '', $q));
            $query->where(function ($builder) use ($q, $plate) {
                $builder->where('name', 'like', '%'.$q.'%')->orWhere('code', 'like', '%'.$q.'%');
                if ($plate !== '') {
                    $builder->orWhere('plate_number', 'like', '%'.$plate.'%');
                }
            });
        }
        if ($status = $filters['status'] ?? null) {
            $query->where('is_active', $status === 'active');
        }

        return Inertia::render('Admin/Vehicles/Index', ['vehicles' => $query->orderBy('code')->orderBy('id')->paginate(20)->withQueryString(), 'filters' => ['q' => $filters['q'] ?? '', 'status' => $filters['status'] ?? '']]);
    }

    public function create()
    {
        return Inertia::render('Admin/Vehicles/Form', ['vehicle' => null]);
    }

    public function store(VehicleRequest $request)
    {
        $vehicle = new Vehicle($request->safe()->except('lock_version'));
        $vehicle->depot_id = 1;
        $this->save($vehicle);

        return redirect()->route('admin.vehicles.index')->with('status', 'Kendaraan ditambahkan.');
    }

    public function edit(Vehicle $vehicle)
    {
        abort_unless($vehicle->depot_id === 1, 404);

        return Inertia::render('Admin/Vehicles/Form', compact('vehicle'));
    }

    public function update(VehicleRequest $request, Vehicle $vehicle)
    {
        abort_unless($vehicle->depot_id === 1, 404);

        return DB::transaction(function () use ($request, $vehicle) {
            $vehicle = Vehicle::where('depot_id', 1)->lockForUpdate()->findOrFail($vehicle->id);
            if ($vehicle->lock_version !== (int) $request->validated('lock_version')) {
                return Inertia::render('Admin/Conflict', ['message' => 'Data kendaraan telah berubah. Muat data terbaru sebelum menyimpan kembali.', 'reloadUrl' => route('admin.vehicles.edit', $vehicle)])->toResponse($request)->setStatusCode(409);
            }
            $vehicle->fill($request->safe()->except('lock_version'));
            if (DB::table('vehicle_trip_locks')->where('vehicle_id', $vehicle->id)->lockForUpdate()->exists()) {
                return Inertia::render('Admin/Conflict', ['message' => 'Kendaraan sedang ditugaskan. Buka ulang trip sebelum mengubah master.', 'reloadUrl' => route('admin.trips.index')])->toResponse($request)->setStatusCode(409);
            }
            $vehicle->lock_version++;
            $this->save($vehicle);

            return redirect()->route('admin.vehicles.index')->with('status', 'Perubahan kendaraan disimpan.');
        });
    }

    private function save(Vehicle $vehicle): void
    {
        try {
            $vehicle->save();
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['code' => 'Kode atau pelat nomor sudah digunakan kendaraan lain.']);
        }
    }
}
