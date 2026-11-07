import { Head, Link, useForm } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
    PageHeading,
    Section,
    Field,
    FormErrors,
    SaveButton,
} from "@/components/admin";
import type { Courier } from "@/types";

export default function CourierForm({ courier }: { courier: Courier | null }) {
    const form = useForm({
        name: courier?.name ?? "",
        email: courier?.email ?? "",
        phone: courier?.phone ?? "",
        password: "",
        password_confirmation: "",
        is_active: courier?.is_active ?? true,
        lock_version: courier?.lock_version ?? 0,
    });
    return (
        <>
            <Head title={courier ? "Edit kurir" : "Tambah kurir"} />
            <PageHeading
                title={courier ? "Edit kurir" : "Tambah kurir"}
                description="Siapkan identitas dan akses aplikasi untuk kurir."
                back={{ href: "/admin/couriers", label: "Semua kurir" }}
            />
            <form
                className="space-y-6"
                onSubmit={(event) => {
                    event.preventDefault();
                    const options = {
                        onFinish: () =>
                            form.reset("password", "password_confirmation"),
                    };
                    courier
                        ? form.put(`/admin/couriers/${courier.id}`, options)
                        : form.post("/admin/couriers", options);
                }}
            >
                <FormErrors errors={form.errors} />
                <div className="grid items-start gap-6 xl:grid-cols-[1fr_300px]">
                    <div className="space-y-6">
                        <Section
                            title="Profil kurir"
                            description="Email digunakan untuk masuk ke aplikasi."
                        >
                            <div className="grid gap-5 sm:grid-cols-2">
                                <Field
                                    id="name"
                                    label="Nama kurir"
                                    error={form.errors.name}
                                    className="sm:col-span-2"
                                >
                                    <Input
                                        id="name"
                                        autoComplete="name"
                                        required
                                        maxLength={255}
                                        value={form.data.name}
                                        onChange={(event) =>
                                            form.setData(
                                                "name",
                                                event.target.value,
                                            )
                                        }
                                        aria-invalid={!!form.errors.name}
                                    />
                                </Field>
                                <Field
                                    id="email"
                                    label="Email"
                                    error={form.errors.email}
                                >
                                    <Input
                                        id="email"
                                        type="email"
                                        autoComplete="email"
                                        required
                                        maxLength={255}
                                        value={form.data.email}
                                        onChange={(event) =>
                                            form.setData(
                                                "email",
                                                event.target.value,
                                            )
                                        }
                                        aria-invalid={!!form.errors.email}
                                    />
                                </Field>
                                <Field
                                    id="phone"
                                    label="Nomor telepon"
                                    error={form.errors.phone}
                                >
                                    <Input
                                        id="phone"
                                        type="tel"
                                        autoComplete="tel"
                                        required
                                        maxLength={30}
                                        value={form.data.phone}
                                        onChange={(event) =>
                                            form.setData(
                                                "phone",
                                                event.target.value,
                                            )
                                        }
                                        aria-invalid={!!form.errors.phone}
                                    />
                                </Field>
                            </div>
                        </Section>
                        <Section
                            title={
                                courier ? "Ubah kata sandi" : "Kata sandi awal"
                            }
                            description={
                                courier
                                    ? "Kosongkan kedua kolom untuk mempertahankan kata sandi saat ini."
                                    : "Gunakan minimal 12 karakter. Sampaikan kata sandi kepada kurir melalui jalur pribadi."
                            }
                        >
                            <div className="grid gap-5 sm:grid-cols-2">
                                <Field
                                    id="password"
                                    label={
                                        courier
                                            ? "Kata sandi baru (opsional)"
                                            : "Kata sandi"
                                    }
                                    error={form.errors.password}
                                >
                                    <Input
                                        id="password"
                                        type="password"
                                        autoComplete="new-password"
                                        required={!courier}
                                        minLength={12}
                                        maxLength={1024}
                                        value={form.data.password}
                                        onChange={(event) =>
                                            form.setData(
                                                "password",
                                                event.target.value,
                                            )
                                        }
                                        aria-invalid={!!form.errors.password}
                                    />
                                </Field>
                                <Field
                                    id="password_confirmation"
                                    label="Ulangi kata sandi"
                                    error={form.errors.password_confirmation}
                                >
                                    <Input
                                        id="password_confirmation"
                                        type="password"
                                        autoComplete="new-password"
                                        required={
                                            !courier ||
                                            form.data.password.length > 0
                                        }
                                        maxLength={1024}
                                        value={form.data.password_confirmation}
                                        onChange={(event) =>
                                            form.setData(
                                                "password_confirmation",
                                                event.target.value,
                                            )
                                        }
                                    />
                                </Field>
                            </div>
                        </Section>
                    </div>
                    <Section title="Akses aplikasi">
                        <div className="flex items-center justify-between gap-3 rounded-lg border p-3">
                            <label
                                htmlFor="is_active"
                                className="text-sm font-medium"
                            >
                                Akun aktif
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
                            Mengubah email atau kata sandi, atau menonaktifkan
                            akun, mengakhiri sesi aplikasi kurir. Akun tetap
                            tersimpan dan dapat diaktifkan kembali.
                        </p>
                        <div className="flex flex-col gap-2 [&>button]:w-full">
                            <SaveButton processing={form.processing}>
                                {courier ? "Simpan perubahan" : "Simpan kurir"}
                            </SaveButton>
                            <Button variant="outline" asChild>
                                <Link href="/admin/couriers">Batal</Link>
                            </Button>
                        </div>
                    </Section>
                </div>
            </form>
        </>
    );
}
