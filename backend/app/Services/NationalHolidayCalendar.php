<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class NationalHolidayCalendar
{
    public function dates(int $year): array
    {
        $dates = Cache::get("shipx.holidays.$year", config("national_holidays.$year.dates"));
        if (! is_array($dates)) {
            throw new RuntimeException('Kalender libur nasional tahun ini belum tersedia.');
        }

        return $dates;
    }

    public function sync(int $year): int
    {
        $source = config("national_holidays.$year.source");
        if (! $source) {
            throw new RuntimeException('Sumber resmi kalender belum tersedia untuk tahun ini.');
        }
        $html = Http::connectTimeout(5)->timeout(20)->get($source)->throw()->body();
        $text = html_entity_decode(strip_tags(preg_replace('~</(?:p|li|div|h[1-6])>|<br\s*/?>~i', "\n", $html)), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $start = strpos($text, '1 Januari');
        if ($start === false) {
            throw new RuntimeException('Daftar tanggal resmi tidak ditemukan.');
        }
        $text = substr($text, $start);
        $end = stripos($text, 'Cuti Bersama');
        if ($end === false) {
            throw new RuntimeException('Batas daftar libur nasional tidak ditemukan.');
        }
        $text = substr($text, 0, $end);
        $months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
        preg_match_all('/(?<!\d)(\d{1,2})\s*(?:[–—-]\s*(\d{1,2}))?\s*('.implode('|', $months).')\b/u', $text, $matches, PREG_SET_ORDER);
        $dates = [];
        foreach ($matches as $match) {
            $month = array_search($match[3], $months, true) + 1;
            $last = $match[2] !== '' ? (int) $match[2] : (int) $match[1];
            if ($last < (int) $match[1] || $last - (int) $match[1] > 4) {
                throw new RuntimeException('Rentang tanggal kalender tidak valid.');
            }
            for ($day = (int) $match[1]; $day <= $last; $day++) {
                if (! checkdate($month, $day, $year)) {
                    throw new RuntimeException('Tanggal kalender tidak valid.');
                }
                $dates[] = sprintf('%04d-%02d-%02d', $year, $month, $day);
            }
        }
        $dates = array_values(array_unique($dates));
        sort($dates);
        if (count($dates) < 15 || count($dates) > 30) {
            throw new RuntimeException('Jumlah hari libur tidak valid. Kalender tersimpan dipertahankan.');
        }
        Cache::forever("shipx.holidays.$year", $dates);
        Cache::forever("shipx.holidays.synced.$year", now()->toISOString());

        return count($dates);
    }
}
