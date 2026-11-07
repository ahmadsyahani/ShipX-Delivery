<?php

namespace App\Http\Controllers;

use App\Http\Requests\CourierRequest;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

class CourierController extends Controller
{
    private const FIELDS = ['id', 'name', 'email', 'phone', 'is_active', 'lock_version'];

    public function index(Request $request)
    {
        $filters = $request->validate(['q' => ['nullable', 'string', 'max:100'], 'status' => ['nullable', 'in:active,inactive'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $query = User::where('role', 'courier');
        if ($q = $filters['q'] ?? null) {
            $query->where(fn ($builder) => $builder->where('name', 'like', '%'.$q.'%')->orWhere('email', 'like', '%'.$q.'%')->orWhere('phone', 'like', '%'.$q.'%'));
        }
        if ($status = $filters['status'] ?? null) {
            $query->where('is_active', $status === 'active');
        }

        return Inertia::render('Admin/Couriers/Index', ['couriers' => $query->select(self::FIELDS)->orderBy('name')->orderBy('id')->paginate(20)->withQueryString(), 'filters' => ['q' => $filters['q'] ?? '', 'status' => $filters['status'] ?? '']]);
    }

    public function create()
    {
        return Inertia::render('Admin/Couriers/Form', ['courier' => null]);
    }

    public function store(CourierRequest $request)
    {
        $courier = new User($request->safe()->only(['name', 'email', 'phone', 'password']));
        $courier->role = 'courier';
        $courier->is_active = $request->boolean('is_active');
        $this->save($courier);

        return redirect()->route('admin.couriers.index')->with('status', 'Akun kurir ditambahkan.');
    }

    public function edit(User $courier)
    {
        abort_unless($courier->role === 'courier', 404);

        return Inertia::render('Admin/Couriers/Form', ['courier' => $courier->only(self::FIELDS)]);
    }

    public function update(CourierRequest $request, User $courier)
    {
        abort_unless($courier->role === 'courier', 404);

        return DB::transaction(function () use ($request, $courier) {
            $courier = User::where('role', 'courier')->lockForUpdate()->findOrFail($courier->id);
            if ($courier->lock_version !== (int) $request->validated('lock_version')) {
                return Inertia::render('Admin/Conflict', ['message' => 'Data kurir telah berubah. Muat data terbaru sebelum menyimpan kembali.', 'reloadUrl' => route('admin.couriers.edit', $courier)])->toResponse($request)->setStatusCode(409);
            }
            $oldEmail = $courier->email;
            if (DB::table('courier_trip_locks')->where('courier_id', $courier->id)->lockForUpdate()->exists()) {
                return Inertia::render('Admin/Conflict', ['message' => 'Kurir sedang ditugaskan. Buka ulang trip sebelum mengubah master.', 'reloadUrl' => route('admin.trips.index')])->toResponse($request)->setStatusCode(409);
            }
            $courier->fill($request->safe()->only(['name', 'email', 'phone']));
            $courier->is_active = $request->boolean('is_active');
            $passwordChanged = $request->filled('password');
            if ($passwordChanged) {
                $courier->password = $request->validated('password');
            }
            if (! $courier->is_active || $passwordChanged || $oldEmail !== $courier->email) {
                $courier->tokens()->delete();
                $courier->remember_token = Str::random(60);
            }
            $courier->lock_version++;
            $this->save($courier);

            return redirect()->route('admin.couriers.index')->with('status', 'Perubahan kurir disimpan.');
        });
    }

    private function save(User $courier): void
    {
        try {
            $courier->save();
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['email' => 'Email sudah digunakan akun lain.']);
        }
    }
}
