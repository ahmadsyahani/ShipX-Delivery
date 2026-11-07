import { useState } from "react";
import { Head, Link, useForm } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
    NativeSelect,
    NativeSelectOption,
} from "@/components/ui/native-select";
import { Switch } from "@/components/ui/switch";
import {
    PageHeading,
    Section,
    Field,
    FormErrors,
    SaveButton,
} from "@/components/admin";
import type { Vehicle } from "@/types";

export default function VehicleForm({ vehicle }: { vehicle: Vehicle | null }) {
    const form = useForm({
        code: vehicle?.code ?? "",
        name: vehicle?.name ?? "",
        plate_number: vehicle?.plate_number ?? "",
        travel_mode: vehicle?.travel_mode ?? "motorcycle",
        max_load_weight_g: String(vehicle?.max_load_weight_g ?? ""),
        max_load_volume_cm3: String(vehicle?.max_load_volume_cm3 ?? ""),
        is_active: vehicle?.is_active ?? false,
        lock_version: vehicle?.lock_version ?? 0,
    });
    const [measuring, setMeasuring] = useState(!vehicle);
    const [box, setBox] = useState(["", "", ""]);
    function measure(index: number, value: string) {
        const next = box.map((size, i) => (i === index ? value : size));
        setBox(next);
        form.setData(
            "max_load_volume_cm3",
            next.every((size) => Number(size) > 0)
                ? String(
                      Math.round(
                          next.reduce(
                              (amount, size) => amount * Number(size),
                              1,
                          ),
                      ),
                  )
                : "",
        );
    }
    return (
        <>
            <Head title={vehicle ? "Edit kendaraan" : "Tambah kendaraan"} />
            <PageHeading
                title={vehicle ? "Edit kendaraan" : "Tambah kendaraan"}
                description="Gunakan kapasitas operasional yang aman, termasuk perlengkapan pengiriman."
                back={{ href: "/admin/vehicles", label: "Semua kendaraan" }}
            />
            <form
                className="space-y-6"
                onSubmit={(event) => {
                    event.preventDefault();
                    vehicle
                        ? form.put(`/admin/vehicles/${vehicle.id}`)
                        : form.post("/admin/vehicles");
                }}
            >
                <FormErrors errors={form.errors} />
                <div className="grid items-start gap-6 xl:grid-cols-[1fr_300px]">
                    <div className="space-y-6">
                        <Section title="Identitas kendaraan">
                            <div className="grid gap-5 sm:grid-cols-2">
                                {(
                                    [
                                        ["name", "Nama kendaraan", 160],
                                        ["code", "Kode kendaraan", 64],
                                        ["plate_number", "Pelat nomor", 32],
                                    ] as const
                                ).map(([key, label, max]) => (
                                    <Field
                                        key={key}
                                        id={key}
                                        label={label}
                                        error={form.errors[key]}
                                        className={
                                            key === "name"
                                                ? "sm:col-span-2"
                                                : ""
                                        }
                                    >
                                        <Input
                                            id={key}
                                            required
                                            maxLength={max}
                                            value={form.data[key]}
                                            onChange={(event) =>
                                                form.setData(
                                                    key,
                                                    event.target.value,
                                                )
                                            }
                                            aria-invalid={!!form.errors[key]}
                                        />
                                    </Field>
                                ))}
                                <Field
                                    id="travel_mode"
                                    label="Jenis kendaraan"
                                    error={form.errors.travel_mode}
                                >
                                    <NativeSelect
                                        id="travel_mode"
                                        value={form.data.travel_mode}
                                        onChange={(event) =>
                                            form.setData(
                                                "travel_mode",
                                                event.target
                                                    .value as Vehicle["travel_mode"],
                                            )
                                        }
                                    >
                                        <NativeSelectOption value="motorcycle">
                                            Sepeda motor
                                        </NativeSelectOption>
                                        <NativeSelectOption value="car">
                                            Mobil
                                        </NativeSelectOption>
                                    </NativeSelect>
                                </Field>
                            </div>
                            <p className="mt-5 text-xs leading-6 text-muted-foreground">
                                Kode dan pelat nomor harus unik. Pelat disimpan
                                tanpa spasi atau tanda hubung agar penulisan
                                berbeda tidak menjadi kendaraan ganda.
                            </p>
                        </Section>
                        <Section
                            title="Kapasitas muatan"
                            description="Isi batas untuk barang yang dapat diangkut, bukan berat total kendaraan."
                        >
                            <div className="grid gap-5 sm:grid-cols-2">
                                <Field
                                    id="max_load_weight_g"
                                    label="Beban aman (kg)"
                                    error={form.errors.max_load_weight_g}
                                    hint="Batas aman barang yang boleh dibawa kendaraan."
                                >
                                    <Input
                                        id="max_load_weight_g"
                                        type="number"
                                        required
                                        min={0.001}
                                        max={1000000}
                                        step={0.001}
                                        value={
                                            form.data.max_load_weight_g === ""
                                                ? ""
                                                : Number(
                                                      form.data
                                                          .max_load_weight_g,
                                                  ) / 1000
                                        }
                                        onChange={(event) =>
                                            form.setData(
                                                "max_load_weight_g",
                                                event.target.value === ""
                                                    ? ""
                                                    : String(
                                                          Math.round(
                                                              Number(
                                                                  event.target
                                                                      .value,
                                                              ) * 1000,
                                                          ),
                                                      ),
                                            )
                                        }
                                    />
                                </Field>
                                <div className="space-y-3 sm:col-span-2">
                                    <p className="text-sm font-medium">
                                        Ruang barang kendaraan
                                    </p>
                                    {!measuring ? (
                                        <>
                                            <p className="text-sm text-muted-foreground">
                                                Kapasitas tersimpan dipakai
                                                untuk memeriksa penugasan.
                                            </p>
                                            <Button
                                                type="button"
                                                variant="outline"
                                                onClick={() => {
                                                    setMeasuring(true);
                                                    form.setData(
                                                        "max_load_volume_cm3",
                                                        "",
                                                    );
                                                }}
                                            >
                                                Ukur ulang ruang barang
                                            </Button>
                                        </>
                                    ) : (
                                        <div className="grid gap-4 sm:grid-cols-3">
                                            {["Panjang", "Lebar", "Tinggi"].map(
                                                (label, index) => (
                                                    <Field
                                                        key={label}
                                                        id={`space-${index}`}
                                                        label={`${label} ruang barang (cm)`}
                                                    >
                                                        <Input
                                                            id={`space-${index}`}
                                                            type="number"
                                                            min={0.1}
                                                            max={100000}
                                                            step={0.1}
                                                            required
                                                            value={box[index]}
                                                            onChange={(event) =>
                                                                measure(
                                                                    index,
                                                                    event.target
                                                                        .value,
                                                                )
                                                            }
                                                        />
                                                    </Field>
                                                ),
                                            )}
                                        </div>
                                    )}
                                    {form.errors.max_load_volume_cm3 && (
                                        <p className="text-xs text-destructive">
                                            Periksa ukuran ruang barang
                                            kendaraan.
                                        </p>
                                    )}
                                </div>
                            </div>
                        </Section>
                    </div>
                    <Section title="Ketersediaan kendaraan">
                        <div className="flex items-center justify-between gap-3 rounded-lg border p-3">
                            <label
                                htmlFor="is_active"
                                className="text-sm font-medium"
                            >
                                Kendaraan aktif
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
                            Aktifkan setelah kapasitas dan kondisi kendaraan
                            diperiksa. Nonaktifkan saat kendaraan tidak dapat
                            digunakan. Penugasan trip menyusul.
                        </p>
                        <div className="flex flex-col gap-2 [&>button]:w-full">
                            <SaveButton processing={form.processing}>
                                {vehicle
                                    ? "Simpan perubahan"
                                    : "Simpan kendaraan"}
                            </SaveButton>
                            <Button variant="outline" asChild>
                                <Link href="/admin/vehicles">Batal</Link>
                            </Button>
                        </div>
                    </Section>
                </div>
            </form>
        </>
    );
}
