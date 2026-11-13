import { Head, Link, useForm } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
    Field,
    FormErrors,
    PageHeading,
    SaveButton,
    Section,
} from "@/components/admin";
import { localInput } from "@/lib/format";
import type { Depot, Slot } from "@/types";

export default function SlotForm({
    slot,
    depot,
    nationalHolidays = [],
}: {
    slot: Slot | null;
    depot: Depot;
    nationalHolidays?: string[];
}) {
    const start = localInput(slot?.window_start_at, depot.timezone);
    const form = useForm({
        service_date: slot ? start.slice(0, 10) : "",
        start_time: start.slice(11),
        end_time: localInput(slot?.window_end_at, depot.timezone).slice(11),
        cutoff_local: localInput(slot?.cutoff_at, depot.timezone),
        is_active: slot?.is_active ?? true,
        lock_version: slot?.lock_version ?? 0,
    });
    function hours(date: string) {
        const day = new Date(`${date}T12:00:00Z`).getUTCDay();
        const shortDay =
            day === 0 || day === 6 || nationalHolidays.includes(date);
        return {
            start: shortDay ? "09:00" : "08:00",
            end: shortDay ? "16:00" : "17:00",
        };
    }
    function schedule(date: string) {
        const opening = hours(date).start;
        const cutoff = new Date(
            new Date(`${date}T${opening}:00Z`).getTime() -
                depot.delivery_prep_minutes * 60000,
        );
        return {
            service_date: date,
            start_time: opening,
            end_time: `${String(Number(opening.slice(0, 2)) + 1).padStart(2, "0")}:00`,
            cutoff_local: cutoff.toISOString().slice(0, 16),
        };
    }
    const operating = hours(form.data.service_date);
    return (
        <>
            <Head title={slot ? "Edit slot" : "Tambah slot"} />
            <PageHeading
                title={slot ? "Edit slot" : "Tambah slot"}
                description="Atur tanggal dan jam pengiriman."
                back={{ href: "/admin/slots", label: "Slot pengiriman" }}
            />
            <form
                className="space-y-6"
                onSubmit={(e) => {
                    e.preventDefault();
                    slot
                        ? form.put(`/admin/slots/${slot.id}`)
                        : form.post("/admin/slots");
                }}
            >
                <FormErrors errors={form.errors} />
                <div className="grid items-start gap-6 xl:grid-cols-[1fr_300px]">
                    <Section
                        title="Jadwal layanan"
                        description="Tetapkan rentang pengantaran dan batas penerimaan pesanan."
                    >
                        <div className="grid gap-5 sm:grid-cols-2">
                            {(
                                [
                                    [
                                        "service_date",
                                        "Tanggal pengiriman",
                                        "date",
                                    ],
                                    ["start_time", "Mulai antar", "time"],
                                    ["end_time", "Selesai antar", "time"],
                                    [
                                        "cutoff_local",
                                        "Batas pemesanan",
                                        "datetime-local",
                                    ],
                                ] as const
                            ).map(([key, label, type]) => (
                                <Field
                                    key={key}
                                    id={key}
                                    label={label}
                                    error={form.errors[key]}
                                    className={
                                        key === "service_date" ||
                                        key === "cutoff_local"
                                            ? "sm:col-span-2"
                                            : ""
                                    }
                                >
                                    <Input
                                        id={key}
                                        type={type}
                                        required
                                        min={
                                            key === "start_time" ||
                                            key === "end_time"
                                                ? operating.start
                                                : undefined
                                        }
                                        max={
                                            key === "start_time" ||
                                            key === "end_time"
                                                ? operating.end
                                                : undefined
                                        }
                                        value={form.data[key]}
                                        onChange={(e) =>
                                            key === "service_date" && !slot
                                                ? form.setData((data) => ({
                                                      ...data,
                                                      ...(e.target.value
                                                          ? schedule(
                                                                e.target.value,
                                                            )
                                                          : {
                                                                service_date:
                                                                    "",
                                                            }),
                                                  }))
                                                : form.setData(
                                                      key,
                                                      e.target.value,
                                                  )
                                        }
                                        aria-invalid={!!form.errors[key]}
                                    />
                                </Field>
                            ))}
                        </div>
                        <p className="mt-5 rounded-lg bg-muted/60 p-3 text-xs leading-6 text-muted-foreground">
                            Jam layanan {operating.start}–{operating.end}.
                            Senin–Jumat 08.00–17.00, akhir pekan dan libur
                            nasional 09.00–16.00. Waktu selesai harus setelah
                            mulai pada tanggal yang sama. Batas pemesanan paling
                            lambat saat mulai. Slot aktif harus belum ditutup
                            dan maksimal 365 hari ke depan.
                        </p>
                    </Section>
                    <Section title="Ketersediaan slot">
                        <div className="flex items-center justify-between gap-3 rounded-lg border p-3">
                            <label
                                htmlFor="is_active"
                                className="text-sm font-medium"
                            >
                                Slot aktif
                            </label>
                            <Switch
                                id="is_active"
                                checked={form.data.is_active}
                                onCheckedChange={(value) =>
                                    form.setData("is_active", value)
                                }
                            />
                        </div>
                        <p className="my-5 text-xs leading-6 text-muted-foreground">
                            Nonaktifkan jadwal yang tidak dapat dilayani.
                            Pelanggan hanya melihat slot aktif yang belum
                            melewati batas pemesanan.
                        </p>
                        <div className="flex flex-col gap-2 [&>button]:w-full">
                            <SaveButton processing={form.processing}>
                                Simpan slot
                            </SaveButton>
                            <Button variant="outline" asChild>
                                <Link href="/admin/slots">Batal</Link>
                            </Button>
                        </div>
                    </Section>
                </div>
            </form>
        </>
    );
}
