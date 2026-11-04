<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\IdempotencyRecord;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\QueryException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class IdempotencyService
{
    public function run(int $user, string $operation, string $key, array $payload, callable $callback): array
    {
        $hash = hash('sha256', json_encode($this->canonical($payload), JSON_THROW_ON_ERROR));
        try {
            // Claim, domain changes and stored response commit together. A crashed
            // worker leaves neither an order nor a persistent processing claim.
            return DB::transaction(function () use ($user, $operation, $key, $hash, $callback) {
                $query = IdempotencyRecord::where('user_id', $user)->where('operation', $operation)->where('idempotency_key', $key);
                $record = (clone $query)->lockForUpdate()->first();
                $fresh = false;
                if (! $record) {
                    try {
                        $record = IdempotencyRecord::create(['user_id' => $user, 'operation' => $operation, 'idempotency_key' => $key, 'request_hash' => $hash, 'status' => 'processing', 'expires_at' => now()->addDays(30)]);
                        $fresh = true;
                    } catch (UniqueConstraintViolationException) {
                        $record = (clone $query)->lockForUpdate()->firstOrFail();
                    }
                }
                if (! $fresh) {
                    if ($record->request_hash !== $hash) {
                        return ['status' => 409, 'body' => ['message' => 'Key sudah dipakai untuk isi permintaan berbeda.', 'code' => 'IDEMPOTENCY_CONFLICT']];
                    }
                    if ($record->expires_at <= now()) {
                        return ['status' => 409, 'body' => ['message' => 'Key sudah kedaluwarsa. Periksa riwayat pesanan sebelum memulai permintaan baru.', 'code' => 'IDEMPOTENCY_EXPIRED']];
                    }
                    if ($record->status !== 'completed') {
                        return ['status' => 409, 'body' => ['message' => 'Permintaan masih diproses. Coba lagi dengan key yang sama.', 'code' => 'REQUEST_IN_PROGRESS']];
                    }

                    return ['status' => $record->response_code, 'body' => $record->response_body];
                }
                try {
                    $result = DB::transaction($callback);
                } catch (BusinessFailure $error) {
                    $result = ['status' => $error->status, 'body' => $error->body()];
                } catch (ValidationException $error) {
                    $result = ['status' => 422, 'body' => ['message' => 'Data permintaan tidak valid.', 'errors' => $error->errors()]];
                } catch (ModelNotFoundException) {
                    $result = ['status' => 404, 'body' => ['message' => 'Resource tidak ditemukan.']];
                }
                $record->update(['status' => 'completed', 'response_code' => $result['status'], 'response_body' => $result['body']]);

                return $result;
            }, 3);
        } catch (QueryException $error) {
            if (in_array((int) ($error->errorInfo[1] ?? 0), [1205, 1213], true)) {
                return ['status' => 409, 'body' => ['message' => 'Permintaan sedang berjalan. Coba lagi dengan key yang sama.', 'code' => 'REQUEST_IN_PROGRESS']];
            }
            throw $error;
        }
    }

    private function canonical(array $value): array
    {
        if (! array_is_list($value)) {
            ksort($value);
        }
        foreach ($value as &$entry) {
            if (is_array($entry)) {
                $entry = $this->canonical($entry);
            }
        }

        return $value;
    }
}
