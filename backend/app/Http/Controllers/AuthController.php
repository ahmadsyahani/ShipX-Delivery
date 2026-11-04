<?php

namespace App\Http\Controllers;

use App\Http\Requests\AuthRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(AuthRequest $request): JsonResponse
    {
        return DB::transaction(function () use ($request): JsonResponse {
            $user = User::create($request->safe()->only(['name', 'email', 'phone', 'password']));

            return $this->issueToken($user->refresh(), $request->validated('device_name'), 201);
        });
    }

    public function login(AuthRequest $request): JsonResponse
    {
        $user = User::where('email', $request->validated('email'))->first();
        // Hash a dummy value as well so unknown accounts follow the password-check path.
        $valid = Hash::check($request->validated('password'), $user?->password ?? '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.');
        if (! $user || ! $valid) {
            throw ValidationException::withMessages(['email' => ['Email atau kata sandi tidak sesuai.']]);
        }
        abort_unless($user->is_active, 403, 'Akun tidak aktif.');

        return $this->issueToken($user, $request->validated('device_name'));
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    private function issueToken(User $user, string $device, int $status = 200): JsonResponse
    {
        $expires = now()->addDays(30);
        $token = $user->createToken($device, ['*'], $expires);

        return response()->json(['data' => [
            'user' => new UserResource($user),
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => $expires->toISOString(),
        ]], $status);
    }
}
