<?php

use App\Models\Depot;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

require __DIR__.'/../backend/vendor/autoload.php';
$app = require __DIR__.'/../backend/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

try {
    DB::connection()->getPdo();
} catch (Throwable) {
    fwrite(STDERR, "MySQL belum dapat dihubungi. Aktifkan MySQL melalui Laragon dan periksa koneksi database.\n");
    exit(1);
}

try {
    $migrator = app('migrator');
    $pending = array_diff(array_keys($migrator->getMigrationFiles([database_path('migrations')])), $migrator->getRepository()->getRan());
    if ($pending) {
        throw new RuntimeException('Ada migration tertunda. Jalankan php artisan migrate dari folder backend sebelum demo.');
    }
    $depot = Depot::findOrFail(1);
    if (! $depot->configured()) {
        throw new RuntimeException('Lengkapi konfigurasi depot melalui web admin sebelum demo.');
    }
    echo json_encode([
        'database' => 'ok',
        'depot' => $depot->only(['latitude', 'longitude', 'service_radius_m']),
        'routing_url' => config('navigation.url'),
    ], JSON_THROW_ON_ERROR).PHP_EOL;
} catch (RuntimeException $error) {
    fwrite(STDERR, $error->getMessage().PHP_EOL);
    exit(1);
}
