import { useState } from "react";
import { Head, useForm } from "@inertiajs/react";
import {
    ArrowRight,
    Boxes,
    Eye,
    EyeOff,
    MapPin,
    ShieldCheck,
    Truck,
} from "lucide-react";
import { Brand } from "@/layouts/admin-layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Field, FormErrors, SaveButton } from "@/components/admin";

export default function Login() {
    const form = useForm({ email: "", password: "" });
    const [visible, setVisible] = useState(false);
    return (
        <>
            <Head title="Masuk admin" />
            <div className="grid min-h-dvh lg:grid-cols-[1.05fr_1fr]">
                <section className="relative hidden overflow-hidden bg-[#182e40] p-12 text-white lg:flex lg:flex-col xl:p-16">
                    <div className="flex items-center gap-2 text-xl font-semibold">
                        <Truck className="size-7" />
                        ShipX
                    </div>
                    <div className="relative z-10 my-auto max-w-lg py-20">
                        <h1 className="text-5xl font-bold leading-[1.15] tracking-[-0.055em] xl:text-6xl">
                            Semua barang.
                            <br />
                            Satu kendali.
                        </h1>
                        <p className="mt-6 max-w-sm text-base leading-7 text-white/75">
                            Dari rak depot hingga pintu pelanggan. Siapkan
                            produk, jaga stok, dan atur jadwal di satu ruang
                            kerja.
                        </p>
                        <div className="mt-12 flex items-center gap-3 text-white/80">
                            <div className="grid size-14 place-items-center rounded-2xl bg-white/10 text-[#85d9dd]">
                                <Boxes />
                            </div>
                            <span className="h-px w-12 border-t border-dashed border-white/40" />
                            <div className="grid size-14 place-items-center rounded-2xl bg-primary">
                                <Truck />
                            </div>
                            <span className="h-px w-12 border-t border-dashed border-white/40" />
                            <div className="grid size-14 place-items-center rounded-2xl bg-white/10 text-[#85d9dd]">
                                <MapPin />
                            </div>
                        </div>
                    </div>
                    <p className="text-xs text-white/65">
                        Barang sampai, urusan beres.
                    </p>
                </section>
                <main className="flex flex-col bg-card px-6 py-8 sm:px-12">
                    <div className="lg:invisible">
                        <Brand />
                    </div>
                    <div className="mx-auto my-auto w-full max-w-sm py-16">
                        <div className="mb-7 grid size-12 place-items-center rounded-2xl bg-secondary">
                            <ShieldCheck className="size-5 text-primary" />
                        </div>
                        <h2 className="text-3xl font-semibold tracking-tight">
                            Masuk ke ruang kerja
                        </h2>
                        <p className="mb-8 mt-3 text-sm leading-6 text-muted-foreground">
                            Gunakan akun administrator untuk mengelola
                            operasional ShipX.
                        </p>
                        <form
                            className="space-y-5"
                            onSubmit={(e) => {
                                e.preventDefault();
                                form.post("/admin/login", {
                                    onFinish: () => form.reset("password"),
                                });
                            }}
                        >
                            <FormErrors errors={form.errors} />
                            <Field
                                id="email"
                                label="Email"
                                error={form.errors.email}
                            >
                                <Input
                                    id="email"
                                    name="email"
                                    type="email"
                                    autoComplete="username"
                                    autoFocus
                                    required
                                    value={form.data.email}
                                    onChange={(e) =>
                                        form.setData("email", e.target.value)
                                    }
                                    aria-invalid={!!form.errors.email}
                                />
                            </Field>
                            <Field
                                id="password"
                                label="Kata sandi"
                                error={form.errors.password}
                            >
                                <div className="relative">
                                    <Input
                                        id="password"
                                        name="password"
                                        type={visible ? "text" : "password"}
                                        autoComplete="current-password"
                                        required
                                        className="pr-12"
                                        value={form.data.password}
                                        onChange={(e) =>
                                            form.setData(
                                                "password",
                                                e.target.value,
                                            )
                                        }
                                        aria-invalid={!!form.errors.password}
                                    />
                                    <Button
                                        type="button"
                                        variant="ghost"
                                        size="icon"
                                        className="absolute right-0 top-0 size-9"
                                        aria-label={
                                            visible
                                                ? "Sembunyikan kata sandi"
                                                : "Tampilkan kata sandi"
                                        }
                                        onClick={() => setVisible(!visible)}
                                    >
                                        {visible ? <EyeOff /> : <Eye />}
                                    </Button>
                                </div>
                            </Field>
                            <div className="[&>button]:w-full">
                                <SaveButton processing={form.processing}>
                                    Masuk <ArrowRight />
                                </SaveButton>
                            </div>
                        </form>
                        <p className="mt-8 text-xs leading-5 text-muted-foreground">
                            Akses khusus administrator. Pelanggan menggunakan
                            aplikasi ShipX di Android.
                        </p>
                    </div>
                    <p className="text-center text-xs text-muted-foreground">
                        ShipX · Pengelolaan operasional
                    </p>
                </main>
            </div>
        </>
    );
}
