import { Head, useForm } from "@inertiajs/react";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
    NativeSelect,
    NativeSelectOption,
} from "@/components/ui/native-select";
import { LocationPicker } from "@/components/location-picker";
import { Badge } from "@/components/ui/badge";
import {
    Field,
    FormErrors,
    PageHeading,
    SaveButton,
    Section,
} from "@/components/admin";
import type { Depot as DepotData } from "@/types";

export default function Depot({
    depot,
    configured,
    timezoneLocked,
}: {
    depot: DepotData;
    configured: boolean;
    timezoneLocked: boolean;
}) {
    const form = useForm({
        name: depot.name,
        address_text: depot.address_text ?? "",
        latitude: depot.latitude ?? "",
        longitude: depot.longitude ?? "",
        timezone: depot.timezone,
        service_radius_m: String(depot.service_radius_m ?? ""),
        delivery_fee_rp: String(depot.delivery_fee_rp ?? ""),
        pending_ttl_minutes: String(depot.pending_ttl_minutes),
        default_service_seconds: String(depot.default_service_seconds),
        delivery_per_km_rp: String(depot.delivery_per_km_rp ?? 1000),
        express_extra_percent: String(depot.express_extra_percent ?? 50),
        delivery_prep_minutes: String(depot.delivery_prep_minutes ?? 30),
        delivery_speed_kmh: String(depot.delivery_speed_kmh ?? 20),
        lock_version: depot.lock_version,
    });
    return (
        <>
            <Head title="Depot" />
            <PageHeading
                title="Konfigurasi depot"
                description="Titik berangkat, cakupan layanan, dan ongkir pelanggan."
                action={
                    <Badge
                        variant="outline"
                        className={
                            configured
                                ? "border-primary/25 bg-primary/5 text-primary"
                                : ""
                        }
                    >
                        {configured ? "Terkonfigurasi" : "Belum lengkap"}
                    </Badge>
                }
            />
            <form
                className="space-y-6"
                onSubmit={(e) => {
                    e.preventDefault();
                    form.put("/admin/depot", {
                        onSuccess: (page) => {
                            if (page.props.depot)
                                form.setData(
                                    "lock_version",
                                    (page.props.depot as DepotData)
                                        .lock_version,
                                );
                        },
                    });
                }}
            >
                <FormErrors errors={form.errors} />
                <div className="grid items-start gap-6 xl:grid-cols-[1fr_300px]">
                    <div className="space-y-6">
                        <Section
                            title="Lokasi dan cakupan"
                            description="Pilih posisi depot di peta. Cakupan layanan mengikuti titik ini."
                        >
                            <div className="grid gap-5 sm:grid-cols-2">
                                <Field
                                    id="name"
                                    label="Nama depot"
                                    className="sm:col-span-2"
                                    error={form.errors.name}
                                >
                                    <Input
                                        id="name"
                                        required
                                        maxLength={160}
                                        value={form.data.name}
                                        onChange={(e) =>
                                            form.setData("name", e.target.value)
                                        }
                                    />
                                </Field>
                                <Field
                                    id="address_text"
                                    label="Alamat depot"
                                    className="sm:col-span-2"
                                    error={form.errors.address_text}
                                >
                                    <Textarea
                                        id="address_text"
                                        required
                                        rows={3}
                                        maxLength={2000}
                                        value={form.data.address_text}
                                        onChange={(e) =>
                                            form.setData(
                                                "address_text",
                                                e.target.value,
                                            )
                                        }
                                    />
                                </Field>
                                <div className="space-y-2 sm:col-span-2">
                                    <p className="text-sm font-semibold">
                                        Lokasi depot
                                    </p>
                                    <LocationPicker
                                        latitude={form.data.latitude}
                                        longitude={form.data.longitude}
                                        radius={Number(
                                            form.data.service_radius_m,
                                        )}
                                        disabled={form.processing}
                                        onChange={(latitude, longitude) =>
                                            form.setData((previous) => ({
                                                ...previous,
                                                latitude: String(latitude),
                                                longitude: String(longitude),
                                            }))
                                        }
                                    />
                                    {(form.errors.latitude ||
                                        form.errors.longitude) && (
                                        <p className="text-xs text-destructive">
                                            Pilih titik depot yang valid pada
                                            peta.
                                        </p>
                                    )}
                                </div>
                                <Field
                                    id="service_radius_m"
                                    label="Radius layanan (meter)"
                                    error={form.errors.service_radius_m}
                                >
                                    <Input
                                        id="service_radius_m"
                                        type="number"
                                        min={1}
                                        max={200000}
                                        step={1}
                                        required
                                        value={form.data.service_radius_m}
                                        onChange={(e) =>
                                            form.setData(
                                                "service_radius_m",
                                                e.target.value,
                                            )
                                        }
                                    />
                                </Field>
                                <Field
                                    id="timezone"
                                    label="Zona waktu"
                                    error={form.errors.timezone}
                                    hint={
                                        timezoneLocked
                                            ? "Zona waktu dikunci karena sudah ada slot."
                                            : undefined
                                    }
                                >
                                    <NativeSelect
                                        id="timezone"
                                        className="w-full"
                                        disabled={timezoneLocked}
                                        value={form.data.timezone}
                                        onChange={(e) =>
                                            form.setData(
                                                "timezone",
                                                e.target.value,
                                            )
                                        }
                                    >
                                        <NativeSelectOption value="Asia/Jakarta">
                                            Indonesia bagian barat
                                        </NativeSelectOption>
                                        <NativeSelectOption value="Asia/Makassar">
                                            Indonesia bagian tengah
                                        </NativeSelectOption>
                                        <NativeSelectOption value="Asia/Jayapura">
                                            Indonesia bagian timur
                                        </NativeSelectOption>
                                    </NativeSelect>
                                </Field>
                            </div>
                            <p className="mt-5 text-xs leading-6 text-muted-foreground">
                                Pilih titik depot sesuai alamat pada peta.
                                Radius memakai jarak garis lurus, bukan jarak
                                perjalanan jalan raya.
                            </p>
                        </Section>
                        <Section title="Biaya dan waktu layanan">
                            <div className="grid gap-5 sm:grid-cols-2">
                                {(
                                    [
                                        [
                                            "delivery_per_km_rp",
                                            "Tambahan setiap km berikutnya (Rp)",
                                            0,
                                            1000000,
                                        ],
                                        [
                                            "express_extra_percent",
                                            "Tambahan Express (%)",
                                            0,
                                            500,
                                        ],
                                        [
                                            "delivery_prep_minutes",
                                            "Persiapan pengiriman (menit)",
                                            1,
                                            240,
                                        ],
                                        [
                                            "delivery_speed_kmh",
                                            "Kecepatan estimasi (km/jam)",
                                            1,
                                            100,
                                        ],
                                        [
                                            "delivery_fee_rp",
                                            "Ongkir dasar, termasuk 1 km pertama (Rp)",
                                            0,
                                            1000000000,
                                        ],
                                        [
                                            "pending_ttl_minutes",
                                            "Batas order pending (menit)",
                                            1,
                                            1440,
                                        ],
                                        [
                                            "default_service_seconds",
                                            "Durasi layanan per tujuan (detik)",
                                            1,
                                            7200,
                                        ],
                                    ] as const
                                ).map(([key, label, min, max]) => (
                                    <Field
                                        key={key}
                                        id={key}
                                        label={label}
                                        error={form.errors[key]}
                                    >
                                        <Input
                                            id={key}
                                            type="number"
                                            required
                                            min={min}
                                            max={max}
                                            step={1}
                                            value={form.data[key]}
                                            onChange={(e) =>
                                                form.setData(
                                                    key,
                                                    e.target.value,
                                                )
                                            }
                                        />
                                    </Field>
                                ))}
                            </div>
                        </Section>
                    </div>
                    <Section title="Simpan konfigurasi">
                        <p className="mb-5 text-sm leading-6 text-muted-foreground">
                            Perubahan titik atau radius memeriksa ulang alamat
                            lama. Alamat di luar cakupan tidak dapat digunakan
                            untuk checkout.
                        </p>
                        <SaveButton processing={form.processing}>
                            Simpan depot
                        </SaveButton>
                    </Section>
                </div>
            </form>
        </>
    );
}
