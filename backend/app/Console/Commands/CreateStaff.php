<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;

class CreateStaff extends Command
{
    protected $signature = 'shipx:create-staff {role : admin atau courier}';

    protected $description = 'Buat akun staf lokal tanpa kredensial bawaan atau register publik';

    public function handle(): int
    {
        $data = [
            'role' => $this->argument('role'),
            'name' => $this->ask('Nama'),
            'email' => mb_strtolower(trim((string) $this->ask('Email'))),
            'phone' => $this->ask('Nomor telepon'),
            'password' => $this->secret('Kata sandi (minimal 12 karakter)'),
            'password_confirmation' => $this->secret('Ulangi kata sandi'),
        ];
        $validator = Validator::make($data, [
            'role' => 'required|in:admin,courier', 'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email', 'phone' => 'required|string|max:30',
            'password' => 'required|string|min:12|max:1024|confirmed',
        ]);
        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }
        $user = new User;
        $user->fill(collect($data)->only(['name', 'email', 'phone', 'password'])->all());
        $user->role = $data['role'];
        $user->is_active = true;
        $user->save();
        $this->info('Akun staf dibuat.');

        return self::SUCCESS;
    }
}
