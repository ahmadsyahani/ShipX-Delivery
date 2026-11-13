import { useForm } from "@inertiajs/react";
import { Field, FormErrors, SaveButton, Section } from "@/components/admin";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { dateTime } from "@/lib/format";
import type { Trip } from "./types";
export type ManifestRow = {
    product_id: string;
    quantity: number;
    weight_g: number;
    volume_cm3: number;
    variants: {
        name: string;
        unit_label: string;
        quantity: number;
        order_number: string;
        handling_notes: string | null;
        length_mm: number;
        width_mm: number;
        height_mm: number;
    }[];
};
export type Schedule = {
    departure_at: string;
    estimated_return_at: string;
    travel_seconds: number;
    stops: {
        order_id: string;
        sequence_no: number;
        estimated_arrival_at: string;
        estimated_service_start_at: string;
        estimated_service_end_at: string;
        waiting_seconds: number;
    }[];
};
export type DepartureReview = {
    id: number;
    source_reference: string;
    reviewed_at: string;
    expires_at: string;
    reason: string;
    leg_seconds: number[];
    schedule_snapshot: Schedule;
};
export default function DeparturePanel({
    trip,
    manifest,
    review,
    schedule,
    idempotencyKey,
}: {
    trip: Trip;
    manifest: ManifestRow[];
    review: DepartureReview | null;
    schedule: Schedule | null;
    idempotencyKey: string;
}) {
    const orders = trip.selected_route.input_snapshot.orders;
    const optimization = trip.selected_route.input_snapshot.optimization;
    const labels = [
        ...orders.map(
            (o, i) =>
                `${i === 0 ? "Depot" : `Tujuan ${i}`} → Tujuan ${i + 1} (${o.address.recipient_name})`,
        ),
        `Tujuan ${orders.length} → Depot`,
    ];
    const form = useForm({
        idempotency_key: idempotencyKey,
        lock_version: trip.lock_version,
        leg_minutes: labels.map((_, i) =>
            review
                ? String(review.leg_seconds[i] / 60)
                : optimization
                  ? String(optimization.leg_seconds[i] / 60)
                  : "",
        ),
        source_reference:
            review?.source_reference ?? optimization?.source_reference ?? "",
        reason: "",
        handling_checked: false,
    });
    const shown = schedule ?? review?.schedule_snapshot;
    return (
        <>
            <Section
                title={
                    [
                        "in_progress",
                        "awaiting_reconciliation",
                        "completed",
                    ].includes(trip.status)
                        ? "Muatan sudah diberangkatkan"
                        : "Manifest muatan per SKU"
                }
                description="Kurir menghitung jumlah fisik setiap SKU. Start hanya menerima seluruh manifest yang sesuai."
            >
                <div className="divide-y">
                    {manifest.map((row) => (
                        <div key={row.product_id} className="py-4 text-sm">
                            <p className="font-semibold">
                                {row.variants[0].name} · ID produk #
                                {row.product_id}
                            </p>
                            <p className="mt-1">Total {row.quantity} item</p>
                            <details className="mt-2 text-xs text-muted-foreground">
                                <summary className="cursor-pointer">
                                    Rincian kemasan dan pesanan
                                </summary>
                                <ul className="mt-3 space-y-2">
                                    {row.variants.map((v, i) => (
                                        <li key={i} className="break-words">
                                            {v.quantity} item · {v.name} · #
                                            {v.order_number.slice(-8)}
                                            {v.handling_notes &&
                                                ` · ${v.handling_notes}`}
                                        </li>
                                    ))}
                                </ul>
                            </details>
                        </div>
                    ))}
                </div>
                {trip.actual_departure_at && (
                    <p className="mt-4 text-sm font-medium">
                        Berangkat{" "}
                        {dateTime(
                            trip.actual_departure_at,
                            trip.timezone_snapshot,
                        )}{" "}
                        {trip.status === "completed"
                            ? "Muatan dan barang kembali sudah direkonsiliasi."
                            : "Reservasi sudah dikonsumsi, stok tercatat pada trip."}
                    </p>
                )}
            </Section>
            {trip.status === "assigned" && (
                <Section
                    title="Tinjau keberangkatan"
                    description="Tinjau estimasi waktu jalan, sumber, serta penanganan barang sebelum berangkat."
                >
                    <form
                        className="space-y-5"
                        onSubmit={(e) => {
                            e.preventDefault();
                            form.post(
                                `/admin/trips/${trip.id}/departure-review`,
                            );
                        }}
                    >
                        <FormErrors errors={form.errors} />
                        <p className="text-sm text-muted-foreground">
                            Isi seluruh ruas sesuai urutan, termasuk pulang.
                            Sistem memeriksa waktu tunggu dan batas selesai
                            pengiriman. Tinjauan berlaku 24 jam; jika rencana
                            berubah, tinjau ulang.
                        </p>
                        <div className="grid gap-4 sm:grid-cols-2">
                            {labels.map((label, i) => (
                                <Field
                                    key={i}
                                    id={`leg-${i}`}
                                    label={`${label} · menit`}
                                >
                                    <Input
                                        id={`leg-${i}`}
                                        type="number"
                                        min={0}
                                        max={1440}
                                        step={1}
                                        required
                                        value={form.data.leg_minutes[i]}
                                        onChange={(e) =>
                                            form.setData(
                                                "leg_minutes",
                                                form.data.leg_minutes.map(
                                                    (value, j) =>
                                                        j === i
                                                            ? e.target.value
                                                            : value,
                                                ),
                                            )
                                        }
                                    />
                                </Field>
                            ))}
                        </div>
                        <Field
                            id="source_reference"
                            label="Sumber estimasi jalan"
                            hint="Contoh: aplikasi peta, mode kendaraan, waktu pemeriksaan dan kondisi jalan yang ditinjau."
                        >
                            <Textarea
                                id="source_reference"
                                required
                                maxLength={500}
                                value={form.data.source_reference}
                                onChange={(e) =>
                                    form.setData(
                                        "source_reference",
                                        e.target.value,
                                    )
                                }
                            />
                        </Field>
                        <Field id="review-reason" label="Catatan tinjauan">
                            <Textarea
                                id="review-reason"
                                required
                                maxLength={500}
                                value={form.data.reason}
                                onChange={(e) =>
                                    form.setData("reason", e.target.value)
                                }
                            />
                        </Field>
                        <label className="flex items-start gap-3 text-sm leading-6">
                            <input
                                type="checkbox"
                                className="mt-1 size-4 shrink-0 accent-primary"
                                required
                                checked={form.data.handling_checked}
                                onChange={(e) =>
                                    form.setData(
                                        "handling_checked",
                                        e.target.checked,
                                    )
                                }
                            />
                            Saya sudah meninjau bentuk/dimensi, penanganan
                            barang dan kesesuaian kendaraan.
                        </label>
                        <SaveButton processing={form.processing}>
                            Simpan tinjauan keberangkatan
                        </SaveButton>
                    </form>
                </Section>
            )}
            {review && shown && (
                <Section
                    title="Estimasi jadwal manual"
                    description={
                        schedule
                            ? "Dihitung ulang saat keberangkatan aktual."
                            : "Dihitung saat admin meninjau rencana; diperiksa ulang ketika kurir mulai."
                    }
                >
                    <div className="space-y-3 text-sm">
                        <p className="break-words">
                            Sumber: {review.source_reference}
                        </p>
                        <p>
                            Ditinjau{" "}
                            {dateTime(
                                review.reviewed_at,
                                trip.timezone_snapshot,
                            )}{" "}
                            · berlaku sampai{" "}
                            {dateTime(
                                review.expires_at,
                                trip.timezone_snapshot,
                            )}
                        </p>
                        <p className="break-words">{review.reason}</p>
                        <ol className="space-y-3 border-t pt-4">
                            {shown.stops.map((s) => (
                                <li key={s.order_id}>
                                    Tujuan {s.sequence_no}: tiba{" "}
                                    {dateTime(
                                        s.estimated_arrival_at,
                                        trip.timezone_snapshot,
                                    )}
                                    , mulai layanan{" "}
                                    {dateTime(
                                        s.estimated_service_start_at,
                                        trip.timezone_snapshot,
                                    )}{" "}
                                    · tunggu{" "}
                                    {Math.round(s.waiting_seconds / 60)} menit
                                </li>
                            ))}
                        </ol>
                        <p className="font-medium">
                            Estimasi kembali ke depot:{" "}
                            {dateTime(
                                shown.estimated_return_at,
                                trip.timezone_snapshot,
                            )}
                        </p>
                    </div>
                </Section>
            )}
        </>
    );
}
