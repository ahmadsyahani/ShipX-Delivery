import { Head, useForm } from "@inertiajs/react";
import { ArrowUp, ArrowDown, X } from "lucide-react";
import {
    PageHeading,
    Section,
    Field,
    FormErrors,
    SaveButton,
} from "@/components/admin";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { NativeSelect } from "@/components/ui/native-select";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { dateTime } from "@/lib/format";
import type { Vehicle } from "@/types";
import type { Trip, Plan, CandidateOrder } from "./types";

export default function TripForm({
    trip,
    timezone,
    orders,
    couriers,
    vehicles,
    idempotencyKey,
}: {
    trip: Trip | null;
    timezone: string;
    orders: CandidateOrder[];
    couriers: { id: number; name: string }[];
    vehicles: Vehicle[];
    idempotencyKey: string;
}) {
    const plan = trip?.selected_route.input_snapshot.plan;
    const form = useForm<
        Plan & { lock_version: number; idempotency_key: string }
    >({
        courier_id: plan?.courier_id ?? 0,
        vehicle_id: plan?.vehicle_id ?? 0,
        departure_local: plan?.departure_local ?? "",
        orders: plan?.orders ?? [],
        lock_version: trip?.lock_version ?? 0,
        idempotency_key: idempotencyKey,
    });
    const selected = form.data.orders.map((o) =>
        orders.find((c) => c.id === o.id),
    );
    const weight = selected.reduce((s, o) => s + (o?.total_weight_g ?? 0), 0),
        volume = selected.reduce((s, o) => s + (o?.total_volume_cm3 ?? 0), 0);
    const vehicle = vehicles.find((v) => v.id === form.data.vehicle_id);
    const over =
        !!vehicle &&
        (weight > vehicle.max_load_weight_g ||
            volume > vehicle.max_load_volume_cm3);
    const stale = selected.some((o) => !o);
    function move(index: number, delta: number) {
        const next = [...form.data.orders];
        [next[index], next[index + delta]] = [next[index + delta], next[index]];
        form.setData("orders", next);
    }
    return (
        <>
            <Head title={trip ? "Edit rencana trip" : "Buat trip"} />
            <PageHeading
                title={trip ? "Edit rencana trip" : "Buat trip"}
                back={{
                    href: trip ? `/admin/trips/${trip.id}` : "/admin/trips",
                    label: "Kembali ke trip",
                }}
                description="Draft belum mengunci armada atau pesanan. Penetapan dilakukan sesudah rencana ditinjau."
            />
            <Alert>
                <AlertDescription>
                    Urutan dipilih manual. Waktu tempuh jalan dan ETA belum
                    dihitung. Periksa dimensi, penanganan barang, dan jadwal
                    secara manual; fitur ini belum memulai perjalanan.
                </AlertDescription>
            </Alert>
            <form
                className="space-y-6"
                onSubmit={(e) => {
                    e.preventDefault();
                    if (trip) form.put(`/admin/trips/${trip.id}`);
                    else form.post("/admin/trips");
                }}
            >
                <FormErrors errors={form.errors} />
                <Section title="Armada dan keberangkatan">
                    <div className="grid gap-5 sm:grid-cols-2">
                        <Field id="courier_id" label="Kurir">
                            <NativeSelect
                                id="courier_id"
                                value={form.data.courier_id}
                                onChange={(e) =>
                                    form.setData(
                                        "courier_id",
                                        Number(e.target.value),
                                    )
                                }
                                required
                            >
                                <option value="0">Pilih kurir tersedia</option>
                                {couriers.map((c) => (
                                    <option key={c.id} value={c.id}>
                                        {c.name}
                                    </option>
                                ))}
                            </NativeSelect>
                        </Field>
                        <Field id="vehicle_id" label="Kendaraan">
                            <NativeSelect
                                id="vehicle_id"
                                value={form.data.vehicle_id}
                                onChange={(e) =>
                                    form.setData(
                                        "vehicle_id",
                                        Number(e.target.value),
                                    )
                                }
                                required
                            >
                                <option value="0">
                                    Pilih kendaraan tersedia
                                </option>
                                {vehicles.map((v) => (
                                    <option key={v.id} value={v.id}>
                                        {v.code} · {v.plate_number}
                                    </option>
                                ))}
                            </NativeSelect>
                        </Field>
                        <Field id="departure_local" label="Rencana berangkat">
                            <Input
                                id="departure_local"
                                type="datetime-local"
                                required
                                value={form.data.departure_local}
                                onChange={(e) =>
                                    form.setData(
                                        "departure_local",
                                        e.target.value,
                                    )
                                }
                            />
                        </Field>
                    </div>
                </Section>
                <div className="grid items-start gap-6 xl:grid-cols-2">
                    <Section
                        title="Pesanan tersedia"
                        description="Pilih maksimal 20 pesanan dari slot pengiriman yang sama."
                    >
                        <div className="max-h-[600px] space-y-3 overflow-y-auto">
                            {orders.map((o) => {
                                const checked = form.data.orders.some(
                                    (s) => s.id === o.id,
                                );
                                return (
                                    <label
                                        key={o.id}
                                        className="flex cursor-pointer items-start gap-3 rounded-lg border p-4 text-sm"
                                    >
                                        <input
                                            type="checkbox"
                                            className="mt-1 size-4 shrink-0 accent-primary"
                                            checked={checked}
                                            disabled={
                                                !checked &&
                                                form.data.orders.length >= 20
                                            }
                                            onChange={() =>
                                                form.setData(
                                                    "orders",
                                                    checked
                                                        ? form.data.orders.filter(
                                                              (s) =>
                                                                  s.id !== o.id,
                                                          )
                                                        : [
                                                              ...form.data
                                                                  .orders,
                                                              {
                                                                  id: o.id,
                                                                  lock_version:
                                                                      o.lock_version,
                                                              },
                                                          ],
                                                )
                                            }
                                        />
                                        <span className="min-w-0">
                                            <span className="break-all font-semibold">
                                                {o.order_number}
                                            </span>
                                            <span className="mt-1 block">
                                                {o.recipient_name} · Slot #
                                                {o.delivery_slot_id}
                                            </span>
                                            <span className="mt-1 block text-xs text-muted-foreground">
                                                {dateTime(
                                                    o.window_start_at,
                                                    timezone,
                                                )}{" "}
                                                —{" "}
                                                {dateTime(
                                                    o.window_end_at,
                                                    timezone,
                                                )}
                                            </span>
                                            <span className="mt-2 block break-words text-xs">
                                                {o.address_text}
                                            </span>
                                            <span className="mt-2 block text-xs text-muted-foreground">
                                                Pesanan siap ditugaskan�
                                            </span>
                                        </span>
                                    </label>
                                );
                            })}
                            {!orders.length && (
                                <p className="text-sm text-muted-foreground">
                                    Belum ada pesanan terkonfirmasi yang
                                    tersedia.
                                </p>
                            )}
                        </div>
                    </Section>
                    <Section
                        title={`Urutan tujuan · ${selected.length}`}
                        description="Berangkat dari depot, kunjungi tujuan sesuai urutan, lalu kembali ke depot."
                    >
                        <ol className="space-y-3">
                            {form.data.orders.map((o, i) => (
                                <li
                                    key={o.id}
                                    className="flex items-center gap-3 rounded-lg border p-3"
                                >
                                    <span className="grid size-8 shrink-0 place-items-center rounded-full bg-primary/10 text-sm text-primary">
                                        {i + 1}
                                    </span>
                                    <span className="min-w-0 flex-1 break-words text-sm">
                                        {selected[i] && (
                                            <span
                                                className="mb-1 block text-xs text-muted-foreground"
                                                title={selected[i].order_number}
                                            >
                                                #
                                                {selected[i].order_number.slice(
                                                    -8,
                                                )}
                                            </span>
                                        )}
                                        {selected[i]?.recipient_name ??
                                            `Pesanan #${o.id} tidak tersedia; hapus dan pilih ulang.`}
                                    </span>
                                    <Button
                                        type="button"
                                        variant="ghost"
                                        size="icon"
                                        aria-label={`Naikkan tujuan ${i + 1}`}
                                        disabled={i === 0}
                                        onClick={() => move(i, -1)}
                                    >
                                        <ArrowUp />
                                    </Button>
                                    <Button
                                        type="button"
                                        variant="ghost"
                                        size="icon"
                                        aria-label={`Turunkan tujuan ${i + 1}`}
                                        disabled={i === selected.length - 1}
                                        onClick={() => move(i, 1)}
                                    >
                                        <ArrowDown />
                                    </Button>
                                    <Button
                                        type="button"
                                        variant="ghost"
                                        size="icon"
                                        aria-label={`Hapus tujuan ${i + 1}`}
                                        onClick={() =>
                                            form.setData(
                                                "orders",
                                                form.data.orders.filter(
                                                    (s) => s.id !== o.id,
                                                ),
                                            )
                                        }
                                    >
                                        <X />
                                    </Button>
                                </li>
                            ))}
                        </ol>
                        <div
                            className={`mt-5 rounded-lg border p-4 text-sm ${over ? "border-destructive text-destructive" : "bg-muted/40"}`}
                            role="status"
                        >
                            <p>
                                Beban terpakai:{" "}
                                {vehicle
                                    ? `${Math.ceil((weight / vehicle.max_load_weight_g) * 100)}%`
                                    : "Pilih kendaraan"}
                            </p>
                            <p className="mt-2">
                                Ruang barang terpakai:{" "}
                                {vehicle
                                    ? `${Math.ceil((volume / vehicle.max_load_volume_cm3) * 100)}%`
                                    : "Pilih kendaraan"}
                            </p>
                            {over && (
                                <p className="mt-2 font-semibold">
                                    Kapasitas kendaraan terlampaui.
                                </p>
                            )}
                        </div>
                    </Section>
                </div>
                <SaveButton
                    processing={form.processing}
                    disabled={
                        over ||
                        stale ||
                        !form.data.orders.length ||
                        !form.data.courier_id ||
                        !form.data.vehicle_id
                    }
                >
                    Simpan draft
                </SaveButton>
            </form>
        </>
    );
}
