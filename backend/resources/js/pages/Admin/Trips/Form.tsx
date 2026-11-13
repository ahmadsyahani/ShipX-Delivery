import { useState } from "react";
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
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { NativeSelect } from "@/components/ui/native-select";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { dateTime, time } from "@/lib/format";
import type { Vehicle } from "@/types";
import type { Trip, Plan, CandidateOrder, DeliveryGroup } from "./types";

export default function TripForm({
    trip,
    timezone,
    orders,
    couriers,
    vehicles,
    idempotencyKey,
    deliveryGroups,
}: {
    trip: Trip | null;
    timezone: string;
    orders: CandidateOrder[];
    couriers: { id: number; name: string }[];
    vehicles: Vehicle[];
    idempotencyKey: string;
    deliveryGroups: DeliveryGroup[];
}) {
    const plan = trip?.selected_route.input_snapshot.plan;
    const form = useForm<
        Plan & { lock_version: number; idempotency_key: string }
    >({
        courier_id: Number(plan?.courier_id ?? 0),
        vehicle_id: Number(plan?.vehicle_id ?? 0),
        departure_local: plan?.departure_local ?? "",
        orders:
            plan?.orders.map((order) => ({
                id: Number(order.id),
                lock_version: Number(order.lock_version),
            })) ?? [],
        lock_version: trip?.lock_version ?? 0,
        idempotency_key: idempotencyKey,
    });
    function groupKey(order: CandidateOrder) {
        return `${order.delivery_slot_id}|${order.window_start_at}|${order.window_end_at}`;
    }
    const initialOrder = orders.find(
        (order) => order.id === Number(plan?.orders[0]?.id),
    );
    const [group, setGroup] = useState(
        initialOrder ? groupKey(initialOrder) : "",
    );
    const deliveryGroup = deliveryGroups.find(
        (candidate) => candidate.key === group,
    );
    const available = orders.filter((order) => groupKey(order) === group);
    function chooseGroup(key: string) {
        setGroup(key);
        const next = deliveryGroups.find((candidate) => candidate.key === key);
        form.setData((data) => ({
            ...data,
            orders: [],
            departure_local: next?.default_departure_local ?? "",
        }));
    }
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
    const stale = selected.some((o) => !o || groupKey(o) !== group);
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
                    Susun pilihan pesanan dan armada, lalu simpan draft untuk
                    menghitung rekomendasi rute dari waktu jalan. Periksa
                    dimensi dan penanganan barang sebelum menetapkan trip.
                </AlertDescription>
            </Alert>
            <form
                className="space-y-6 [&_[data-slot=native-select-wrapper]]:w-full"
                onSubmit={(e) => {
                    e.preventDefault();
                    if (trip) form.put(`/admin/trips/${trip.id}`);
                    else form.post("/admin/trips");
                }}
            >
                <FormErrors errors={form.errors} />
                <Section
                    title="Jadwal dan layanan pelanggan"
                    description="Pilih kelompok pesanan berdasarkan jadwal yang sudah dipilih pelanggan."
                >
                    <Field id="delivery_group" label="Jadwal pengantaran">
                        <NativeSelect
                            id="delivery_group"
                            className="w-full"
                            value={group}
                            onChange={(event) =>
                                chooseGroup(event.target.value)
                            }
                        >
                            <option value="">Pilih jadwal pesanan</option>
                            {deliveryGroups.map((candidate) => (
                                <option
                                    key={candidate.key}
                                    value={candidate.key}
                                >
                                    {dateTime(
                                        candidate.window_start_at,
                                        timezone,
                                    )}
                                    –{time(candidate.window_end_at, timezone)} ·{" "}
                                    {candidate.order_count} pesanan
                                </option>
                            ))}
                        </NativeSelect>
                    </Field>
                    {deliveryGroup && (
                        <div className="mt-4 flex flex-wrap items-center gap-2">
                            <Badge variant="outline">
                                Express {deliveryGroup.express_count}
                            </Badge>
                            <Badge variant="outline">
                                Reguler {deliveryGroup.regular_count}
                            </Badge>
                            <p className="w-full text-xs text-muted-foreground">
                                Layanan mengikuti pilihan setiap pelanggan.
                            </p>
                        </div>
                    )}
                </Section>
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
                        <Field
                            id="departure_date"
                            label="Tanggal berangkat kurir"
                        >
                            <Input
                                id="departure_date"
                                type="date"
                                value={deliveryGroup?.service_date ?? ""}
                                readOnly
                            />
                        </Field>
                        <Field
                            id="departure_local"
                            label="Waktu berangkat kurir"
                        >
                            <Input
                                id="departure_local"
                                type="time"
                                required
                                disabled={!deliveryGroup}
                                min={deliveryGroup?.opens_at}
                                max={deliveryGroup?.latest_departure}
                                value={form.data.departure_local.slice(11)}
                                onChange={(event) =>
                                    form.setData(
                                        "departure_local",
                                        event.target.value && deliveryGroup
                                            ? `${deliveryGroup.service_date}T${event.target.value}`
                                            : "",
                                    )
                                }
                            />
                        </Field>
                        <p className="text-xs leading-6 text-muted-foreground sm:col-span-2">
                            Tanggal mengikuti jadwal pelanggan. Jam awal
                            disarankan dari jadwal terpilih. Setelah draft disimpan, tabel
                            waktu jalan dipakai untuk menyarankan waktu
                            berangkat beserta rute.
                        </p>
                    </div>
                </Section>
                <div className="grid items-start gap-6 xl:grid-cols-2">
                    <Section
                        title="Pesanan tersedia"
                        description="Pilih maksimal 20 pesanan dari jadwal yang sedang ditampilkan."
                    >
                        <div className="max-h-[600px] space-y-3 overflow-y-auto">
                            {available.map((o) => {
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
                                                {o.recipient_name}
                                            </span>
                                            <Badge
                                                variant="outline"
                                                className="mt-2"
                                            >
                                                {o.delivery_type === "express"
                                                    ? "Express"
                                                    : "Reguler"}
                                            </Badge>
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
                                        </span>
                                    </label>
                                );
                            })}
                            {!available.length && (
                                <p className="text-sm text-muted-foreground">
                                    {group
                                        ? "Belum ada pesanan terkonfirmasi yang tersedia pada jadwal ini."
                                        : "Pilih jadwal pengantaran untuk melihat pesanan."}
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
                        !deliveryGroup ||
                        !form.data.departure_local ||
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
