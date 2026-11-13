import { useState } from "react";
import { useForm } from "@inertiajs/react";
import axios from "axios";
import { Section, Field, FormErrors } from "@/components/admin";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { dateTime } from "@/lib/format";
import type { Trip } from "./types";
import type { Schedule } from "./DeparturePanel";

type RouteResult = {
    order_ids: string[];
    schedule: Schedule;
    express_completion_seconds: number;
};
type Preview = {
    id: string;
    expires_at: string;
    baseline: RouteResult | null;
    fifo: RouteResult | null;
    selected: RouteResult | null;
    selected_from: string | null;
    departure_at: string;
    departure_recommended: boolean;
};

export default function OptimizationPanel({
    trip,
    idempotencyKey,
}: {
    trip: Trip;
    idempotencyKey: string;
}) {
    const orders = trip.selected_route.input_snapshot.orders;
    const names = ["Depot", ...orders.map((order) => order.order_number)];
    const optimization = trip.selected_route.input_snapshot.optimization;
    const [matrix, setMatrix] = useState<string[][]>(() => {
        if (optimization) {
            const indices = [
                0,
                ...orders.map(
                    (order) =>
                        optimization.matrix_order_ids.indexOf(order.id) + 1,
                ),
            ];
            return indices.map((from) =>
                indices.map((to) =>
                    String(optimization.matrix_seconds[from][to] / 60),
                ),
            );
        }
        return names.map((_, i) => names.map((_, j) => (i === j ? "0" : "")));
    });
    const [source, setSource] = useState(optimization?.source_reference ?? "");
    const [paste, setPaste] = useState("");
    const [preview, setPreview] = useState<Preview | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [busy, setBusy] = useState(false);
    const [recommendDeparture, setRecommendDeparture] = useState(true);
    const apply = useForm({
        idempotency_key: idempotencyKey,
        lock_version: trip.lock_version,
        optimization_id: "",
    });

    function importTable() {
        const rows = paste
            .trim()
            .split(/\r?\n/)
            .map((row) => row.trim().split(/[\t, ]+/));
        if (
            rows.length !== names.length ||
            rows.some(
                (row) =>
                    row.length !== names.length ||
                    row.some(
                        (value) => !/^\d+$/.test(value) || Number(value) > 1440,
                    ),
            )
        ) {
            setError(
                `Tempel tabel ${names.length} baris × ${names.length} kolom berisi menit 0–1440.`,
            );
            return;
        }
        setMatrix(rows);
        setPreview(null);
        setError(null);
    }

    async function calculate() {
        setBusy(true);
        setError(null);
        setPreview(null);
        try {
            const response = await axios.post(
                `/admin/trips/${trip.id}/optimization/preview`,
                {
                    lock_version: trip.lock_version,
                    recommend_departure: recommendDeparture,
                    source_reference: source,
                    matrix_minutes: matrix,
                },
                { headers: { Accept: "application/json" } },
            );
            setPreview(response.data.data);
        } catch (caught) {
            if (axios.isAxiosError(caught)) {
                const errors = caught.response?.data.errors as
                    Record<string, string[]> | undefined;
                setError(
                    errors
                        ? Object.values(errors)[0]?.[0]
                        : (caught.response?.data.message ??
                              "Optimasi belum dapat dihitung. Periksa koneksi dan coba lagi."),
                );
            } else {
                setError("Optimasi belum dapat dihitung. Coba lagi.");
            }
        } finally {
            setBusy(false);
        }
    }

    return (
        <Section
            title="Optimasi urutan pengantaran"
            description="Isi waktu jalan sesuai mode kendaraan, lalu bandingkan rute sebelum diterapkan."
        >
            <div className="space-y-5">
                <p className="text-sm text-muted-foreground">
                    Baris adalah titik berangkat, kolom adalah tujuan. Isi kedua
                    arah termasuk kembali ke depot. Prioritas dihitung dari
                    deadline, penyelesaian Express, dan total waktu jalan.
                </p>
                <Field id="optimization-source" label="Sumber waktu jalan">
                    <Input
                        id="optimization-source"
                        value={source}
                        maxLength={500}
                        disabled={busy || apply.processing}
                        placeholder="Contoh, hasil pemeriksaan peta jalan untuk motor"
                        onChange={(event) => {
                            setSource(event.target.value);
                            setPreview(null);
                        }}
                    />
                </Field>
                <details>
                    <summary className="cursor-pointer text-sm font-medium text-primary">
                        Tempel tabel dari spreadsheet
                    </summary>
                    <div className="mt-3 space-y-3">
                        <Textarea
                            aria-label="Tabel waktu jalan dalam menit"
                            value={paste}
                            disabled={busy || apply.processing}
                            onChange={(event) => setPaste(event.target.value)}
                        />
                        <Button
                            type="button"
                            variant="outline"
                            disabled={busy || apply.processing}
                            onClick={importTable}
                        >
                            Gunakan tabel
                        </Button>
                    </div>
                </details>
                <div className="max-w-full overflow-x-auto rounded-xl border">
                    <table className="w-full text-sm">
                        <caption className="sr-only">
                            Waktu jalan antar titik dalam menit
                        </caption>
                        <thead>
                            <tr>
                                <th className="p-3 text-left">Dari / ke</th>
                                {names.map((name, i) => (
                                    <th
                                        key={name}
                                        className="min-w-24 p-3"
                                        title={name}
                                    >
                                        {i === 0 ? "Depot" : `Tujuan ${i}`}
                                    </th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {names.map((name, i) => (
                                <tr key={name} className="border-t">
                                    <th
                                        scope="row"
                                        className="min-w-36 max-w-48 p-3 text-left font-medium"
                                    >
                                        {i === 0 ? (
                                            "Depot"
                                        ) : (
                                            <>
                                                <span className="block">
                                                    Tujuan {i}{" "}
                                                    {orders[i - 1]
                                                        .delivery_type ===
                                                        "express" &&
                                                        "· Express"}
                                                </span>
                                                <span className="block break-words text-xs text-muted-foreground">
                                                    {name}
                                                </span>
                                            </>
                                        )}
                                    </th>
                                    {names.map((destination, j) => (
                                        <td key={destination} className="p-2">
                                            <Input
                                                type="number"
                                                min={0}
                                                max={1440}
                                                step={1}
                                                aria-label={`Waktu ${name} ke ${destination}`}
                                                value={matrix[i][j]}
                                                disabled={
                                                    i === j ||
                                                    busy ||
                                                    apply.processing
                                                }
                                                onChange={(event) => {
                                                    setMatrix((rows) =>
                                                        rows.map((row, r) =>
                                                            r === i
                                                                ? row.map(
                                                                      (
                                                                          value,
                                                                          c,
                                                                      ) =>
                                                                          c ===
                                                                          j
                                                                              ? event
                                                                                    .target
                                                                                    .value
                                                                              : value,
                                                                  )
                                                                : row,
                                                        ),
                                                    );
                                                    setPreview(null);
                                                }}
                                            />
                                        </td>
                                    ))}
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
                <label className="flex items-start gap-3 text-sm">
                    <input
                        type="checkbox"
                        className="mt-1 size-4 accent-primary"
                        checked={recommendDeparture}
                        disabled={busy || apply.processing}
                        onChange={(event) => {
                            setRecommendDeparture(event.target.checked);
                            setPreview(null);
                        }}
                    />
                    <span>
                        Rekomendasikan waktu berangkat kurir
                        <span className="mt-1 block text-xs text-muted-foreground">
                            Memperhitungkan waktu jalan, persiapan depot, dan
                            jam layanan tanggal tersebut.
                        </span>
                    </span>
                </label>
                {error && (
                    <p role="alert" className="text-sm text-destructive">
                        {error}
                    </p>
                )}
                <FormErrors errors={apply.errors} />
                <Button
                    type="button"
                    disabled={busy || apply.processing}
                    onClick={calculate}
                >
                    {busy ? "Menghitung rute…" : "Hitung rekomendasi rute"}
                </Button>
                {preview && (
                    <div className="space-y-4 rounded-xl border bg-muted/30 p-4">
                        <div className="rounded-lg bg-primary/10 p-3 text-sm">
                            <p>
                                Waktu berangkat kurir{" "}
                                {dateTime(
                                    preview.departure_at,
                                    trip.timezone_snapshot,
                                )}
                            </p>
                            <p className="mt-1 text-xs text-muted-foreground">
                                Waktu ini diterapkan bersama rekomendasi rute.
                            </p>
                        </div>
                        <div className="grid gap-4 sm:grid-cols-3">
                            {(
                                [
                                    ["Urutan awal", preview.baseline],
                                    ["Urutan pesanan masuk", preview.fifo],
                                    ["Rekomendasi", preview.selected],
                                ] as const
                            ).map(([label, route]) => (
                                <div key={label}>
                                    <p className="text-sm font-semibold">
                                        {label}
                                    </p>
                                    {route ? (
                                        <p className="mt-1 text-sm">
                                            {Math.round(
                                                route.schedule.travel_seconds /
                                                    60,
                                            )}{" "}
                                            menit jalan
                                            <br />
                                            Kembali{" "}
                                            {dateTime(
                                                route.schedule
                                                    .estimated_return_at,
                                                trip.timezone_snapshot,
                                            )}
                                            <br />
                                            Total waktu selesai Express{" "}
                                            {Math.round(
                                                route.express_completion_seconds /
                                                    60,
                                            )}{" "}
                                            menit
                                        </p>
                                    ) : (
                                        <p className="mt-1 text-sm text-muted-foreground">
                                            Belum ditemukan rute yang memenuhi
                                            jadwal.
                                        </p>
                                    )}
                                </div>
                            ))}
                        </div>
                        {preview.selected && (
                            <>
                                <ol className="space-y-2 text-sm">
                                    {preview.selected.order_ids.map((id, i) => {
                                        const order = orders.find(
                                            (order) => order.id === id,
                                        )!;
                                        const stop =
                                            preview.selected!.schedule.stops[i];
                                        return (
                                            <li key={id}>
                                                {i + 1}. {order.order_number}{" "}
                                                {order.delivery_type ===
                                                    "express" && "· Express"}
                                                <br />
                                                <span className="text-muted-foreground">
                                                    Selesai{" "}
                                                    {dateTime(
                                                        stop.estimated_service_end_at,
                                                        trip.timezone_snapshot,
                                                    )}
                                                </span>
                                            </li>
                                        );
                                    })}
                                </ol>
                                <p className="text-xs text-muted-foreground">
                                    Rekomendasi berlaku sampai{" "}
                                    {dateTime(
                                        preview.expires_at,
                                        trip.timezone_snapshot,
                                    )}
                                    . Tinjauan keberangkatan dilakukan setelah
                                    penetapan trip.
                                </p>
                                <Button
                                    type="button"
                                    disabled={apply.processing}
                                    onClick={() => {
                                        apply.transform((data) => ({
                                            ...data,
                                            optimization_id: preview.id,
                                        }));
                                        apply.post(
                                            `/admin/trips/${trip.id}/optimization/apply`,
                                        );
                                    }}
                                >
                                    {apply.processing
                                        ? "Menerapkan…"
                                        : "Terapkan rekomendasi"}
                                </Button>
                            </>
                        )}
                    </div>
                )}
            </div>
        </Section>
    );
}
