import { useState } from "react";
import { Head, Link, useForm } from "@inertiajs/react";
import {
    PageHeading,
    Section,
    Field,
    FormErrors,
    SaveButton,
} from "@/components/admin";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription } from "@/components/ui/alert";
import {
    AlertDialog,
    AlertDialogContent,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogCancel,
} from "@/components/ui/alert-dialog";
import { dateTime, money } from "@/lib/format";
import { type Trip, tripStatus } from "./types";
import DeparturePanel, {
    type ManifestRow,
    type DepartureReview,
    type Schedule,
} from "./DeparturePanel";
import ReconciliationPanel, {
    type Reconciliation,
    type ReturnProduct,
} from "./ReconciliationPanel";

import OptimizationPanel from "./OptimizationPanel";

type Action = "assign" | "reopen" | "cancel";
const labels: Record<Action, string> = {
    assign: "Tetapkan trip",
    reopen: "Buka ulang trip",
    cancel: "Batalkan trip",
};
export default function TripDetail({
    trip,
    events,
    actionKeys,
    manifest,
    departureReview,
    departureSchedule,
    reconciliation,
    returnProducts,
}: {
    trip: Trip;
    events: {
        action: string;
        name: string;
        reason: string | null;
        created_at: string;
        trip_version: number;
    }[];
    actionKeys: Record<Action | "review" | "reconcile" | "optimize", string>;
    manifest: ManifestRow[];
    departureReview: DepartureReview | null;
    departureSchedule: Schedule | null;
    reconciliation: Reconciliation | null;
    returnProducts: ReturnProduct[];
}) {
    const [mode, setMode] = useState<Action | null>(null);
    const form = useForm({
        idempotency_key: "",
        lock_version: trip.lock_version,
        reason: "",
    });
    const snap = trip.selected_route.input_snapshot;
    function open(action: Action) {
        form.setData({
            idempotency_key: actionKeys[action],
            lock_version: trip.lock_version,
            reason: "",
        });
        form.clearErrors();
        setMode(action);
    }
    return (
        <>
            <Head title={trip.trip_number} />
            <PageHeading
                title={trip.trip_number}
                description={`${tripStatus[trip.status]} · Rute versi ${trip.selected_route.version_number}`}
                back={{ href: "/admin/trips", label: "Semua trip" }}
                action={
                    trip.status === "draft" && (
                        <Button asChild variant="outline">
                            <Link href={`/admin/trips/${trip.id}/edit`}>
                                Edit rencana
                            </Link>
                        </Button>
                    )
                }
            />
            <Alert>
                <AlertDescription>
                    {trip.status === "completed"
                        ? "Barang kembali dan setoran COD sudah diperiksa admin. Trip selesai; kurir dan kendaraan dapat menerima penugasan baru."
                        : ["in_progress", "awaiting_reconciliation"].includes(
                                trip.status,
                            )
                          ? "Trip sudah berangkat; stok dimuat ke akun trip. Hasil tiap pesanan dan COD dicatat kurir. Rekonsiliasi dilakukan setelah kembali ke depot."
                          : departureReview
                            ? "Jadwal dihitung dari estimasi jalan manual yang ditinjau admin. Kurir menghitung muatan dan memulai trip; stok masih di depot sampai start berhasil."
                            : snap.optimization
                              ? "Urutan berasal dari optimasi estimasi jalan. Tetapkan trip, lalu tinjau waktu jalan dan penanganan sebelum berangkat."
                              : "Simpan rekomendasi urutan atau tinjau urutan manual sebelum keberangkatan."}
                </AlertDescription>
            </Alert>
            {trip.status === "draft" && (
                <OptimizationPanel
                    key={`${trip.selected_route.id}-${trip.lock_version}`}
                    trip={trip}
                    idempotencyKey={actionKeys.optimize}
                />
            )}
            <Section title="Penugasan">
                <div className="grid gap-5 text-sm sm:grid-cols-2">
                    <div>
                        <p className="text-muted-foreground">
                            Kurir / kendaraan
                        </p>
                        <p className="mt-1 font-semibold">
                            {snap.courier.name} · {snap.vehicle.plate_number}
                        </p>
                        <p className="mt-1">
                            {snap.vehicle.name} ({snap.vehicle.travel_mode})
                        </p>
                    </div>
                    <div>
                        <p className="text-muted-foreground">
                            Rencana keberangkatan
                        </p>
                        <p className="mt-1 font-semibold">
                            {dateTime(
                                trip.planned_departure_at,
                                trip.timezone_snapshot,
                            )}
                        </p>
                    </div>
                    <p>
                        Beban terpakai:{" "}
                        {Math.ceil(
                            (trip.planned_weight_g /
                                trip.capacity_weight_g_snapshot) *
                                100,
                        )}
                        %
                    </p>
                    <p>
                        Ruang barang terpakai:{" "}
                        {Math.ceil(
                            (trip.planned_volume_cm3 /
                                trip.capacity_volume_cm3_snapshot) *
                                100,
                        )}
                        %
                    </p>
                </div>
                {["draft", "assigned"].includes(trip.status) && (
                    <div className="mt-6 flex flex-wrap gap-3">
                        {trip.status === "draft" ? (
                            <Button onClick={() => open("assign")}>
                                Tetapkan trip
                            </Button>
                        ) : (
                            <Button
                                onClick={() => open("reopen")}
                                variant="outline"
                            >
                                Buka ulang trip
                            </Button>
                        )}
                        <Button
                            variant="destructive"
                            onClick={() => open("cancel")}
                        >
                            Batalkan trip
                        </Button>
                    </div>
                )}
            </Section>
            <DeparturePanel
                key={`${trip.lock_version}-${trip.selected_route.id}`}
                trip={trip}
                manifest={manifest}
                review={departureReview}
                schedule={departureSchedule}
                idempotencyKey={actionKeys.review}
            />
            {reconciliation && (
                <ReconciliationPanel
                    key={`reconcile-${trip.lock_version}`}
                    trip={trip}
                    summary={reconciliation}
                    products={returnProducts}
                    idempotencyKey={actionKeys.reconcile}
                />
            )}
            <Section
                title="Urutan tujuan"
                description={`${snap.depot.name} → tujuan → kembali ke depot`}
            >
                <ol className="space-y-5">
                    {snap.orders.map((o, i) => (
                        <li key={o.id} className="rounded-xl border p-5">
                            <div className="flex gap-3">
                                <span className="grid size-8 shrink-0 place-items-center rounded-full bg-primary/10 text-primary">
                                    {i + 1}
                                </span>
                                <div className="min-w-0 flex-1 text-sm">
                                    <Link
                                        href={`/admin/orders/${o.id}`}
                                        className="break-all font-semibold text-primary underline"
                                    >
                                        {o.order_number}
                                        {o.delivery_type === "express" &&
                                            " · Express"}
                                    </Link>
                                    <p className="mt-2 font-medium">
                                        {o.address.recipient_name} ·{" "}
                                        {o.address.phone}
                                    </p>
                                    <p className="mt-2 whitespace-pre-line break-words">
                                        {o.address.address_text}
                                    </p>
                                    {o.address.directions && (
                                        <p className="mt-1 break-words text-muted-foreground">
                                            {o.address.directions}
                                        </p>
                                    )}
                                    <p className="mt-3 text-xs text-muted-foreground">
                                        Jendela:{" "}
                                        {dateTime(
                                            o.window_start_at,
                                            trip.timezone_snapshot,
                                        )}{" "}
                                        —{" "}
                                        {dateTime(
                                            o.window_end_at,
                                            trip.timezone_snapshot,
                                        )}
                                    </p>
                                    <ul className="mt-3 space-y-2">
                                        {o.items.map((item) => (
                                            <li key={item.id}>
                                                {item.quantity} item ·{" "}
                                                {item.name}
                                                <span className="block text-xs text-muted-foreground">
                                                    {item.handling_notes &&
                                                        ` · ${item.handling_notes}`}
                                                </span>
                                            </li>
                                        ))}
                                    </ul>
                                    <p className="mt-3 font-medium">
                                        Tagihan COD: {money(o.total_rp)}
                                    </p>
                                </div>
                            </div>
                        </li>
                    ))}
                </ol>
            </Section>
            <Section title="Riwayat rencana">
                <p className="mb-4 text-sm text-muted-foreground">
                    Versi rute tersimpan:{" "}
                    {trip.routes?.map((r) => r.version_number).join(", ")}.
                    Versi sebelumnya dipertahankan saat rencana diubah.
                </p>
                <ul className="divide-y">
                    {events.map((e, i) => (
                        <li key={i} className="py-3 text-sm">
                            <p>
                                {(
                                    {
                                        created: "Draft dibuat",
                                        updated: "Rencana diubah",
                                        assign: "Trip ditetapkan",
                                        reopen: "Trip dibuka ulang",
                                        cancel: "Trip dibatalkan",
                                        departure_reviewed:
                                            "Keberangkatan ditinjau",
                                        started:
                                            "Muatan dikonfirmasi dan trip berangkat",
                                        delivery_delivered:
                                            "Pesanan berhasil dikirim",
                                        delivery_failed: "Pengiriman gagal",
                                        reconciled:
                                            "Barang dan COD direkonsiliasi; trip selesai",
                                    } as Record<string, string>
                                )[e.action] ?? e.action}{" "}
                                · {e.name}
                            </p>
                            <p className="mt-1 text-xs text-muted-foreground">
                                {dateTime(e.created_at, trip.timezone_snapshot)}{" "}
                                · revisi {e.trip_version}
                            </p>
                            {e.reason && (
                                <p className="mt-2 break-words">{e.reason}</p>
                            )}
                        </li>
                    ))}
                </ul>
            </Section>
            <AlertDialog
                open={mode !== null}
                onOpenChange={(open) => {
                    if (!open && !form.processing) setMode(null);
                }}
            >
                <AlertDialogContent>
                    <form
                        className="space-y-5"
                        onSubmit={(e) => {
                            e.preventDefault();
                            if (mode)
                                form.post(`/admin/trips/${trip.id}/${mode}`, {
                                    onSuccess: () => setMode(null),
                                });
                        }}
                    >
                        <AlertDialogHeader>
                            <AlertDialogTitle>
                                {mode && labels[mode]}
                            </AlertDialogTitle>
                            <AlertDialogDescription>
                                {mode === "assign"
                                    ? "Tinjau urutan, bentuk barang, kapasitas dan jadwal. Penetapan mengunci pesanan serta armada; perjalanan belum dimulai."
                                    : "Pesanan kembali terkonfirmasi, armada dilepas, dan reservasi stok tetap ditahan. Tujuan versi lama disimpan sebagai riwayat."}
                            </AlertDialogDescription>
                        </AlertDialogHeader>
                        <FormErrors errors={form.errors} />
                        {mode !== "assign" && (
                            <Field id="reason" label="Alasan">
                                <Textarea
                                    id="reason"
                                    value={form.data.reason}
                                    required
                                    maxLength={500}
                                    onChange={(e) =>
                                        form.setData("reason", e.target.value)
                                    }
                                />
                            </Field>
                        )}
                        <AlertDialogFooter>
                            <AlertDialogCancel disabled={form.processing}>
                                Kembali
                            </AlertDialogCancel>
                            <SaveButton processing={form.processing}>
                                {mode && labels[mode]}
                            </SaveButton>
                        </AlertDialogFooter>
                    </form>
                </AlertDialogContent>
            </AlertDialog>
        </>
    );
}
