import { Head, Link, useForm } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import {
    Field,
    FormErrors,
    PageHeading,
    SaveButton,
    Section,
} from "@/components/admin";
import type { Product } from "@/types";

export default function ProductForm({ product }: { product: Product | null }) {
    const form = useForm({
        name: product?.name ?? "",
        sku: product?.sku ?? "",
        category: product?.category ?? "",
        unit_label: product?.unit_label ?? "",
        unit_price_rp: String(product?.unit_price_rp ?? ""),
        shipping_weight_g: String(product?.shipping_weight_g ?? ""),
        length_mm: String(product?.length_mm ?? ""),
        width_mm: String(product?.width_mm ?? ""),
        height_mm: String(product?.height_mm ?? ""),
        handling_notes: product?.handling_notes ?? "",
        is_active: product?.is_active ?? false,
        lock_version: product?.lock_version ?? 0,
    });
    const volume =
        Number(form.data.length_mm) *
        Number(form.data.width_mm) *
        Number(form.data.height_mm);
    const textFields = [
        ["name", "Nama produk", 160],
        ["sku", "Kode SKU", 64],
        ["category", "Kategori", 80],
        ["unit_label", "Satuan jual", 30],
    ] as const;
    const sizes = [
        ["shipping_weight_g", "Berat (gram)", 1000000],
        ["length_mm", "Panjang (mm)", 10000],
        ["width_mm", "Lebar (mm)", 10000],
        ["height_mm", "Tinggi (mm)", 10000],
    ] as const;
    return (
        <>
            <Head title={product ? "Edit produk" : "Tambah produk"} />
            <PageHeading
                title={product ? "Edit produk" : "Tambah produk"}
                description="Informasi yang tepat membantu barang sampai dengan baik."
                back={{ href: "/admin/products", label: "Semua produk" }}
            />
            <form
                className="space-y-6"
                onSubmit={(e) => {
                    e.preventDefault();
                    product
                        ? form.put(`/admin/products/${product.id}`)
                        : form.post("/admin/products");
                }}
            >
                <FormErrors errors={form.errors} />
                <div className="grid items-start gap-6 xl:grid-cols-[1fr_300px]">
                    <div className="space-y-6">
                        <Section
                            title="Informasi produk"
                            description="Gunakan nama yang mudah dikenali pelanggan."
                        >
                            <div className="grid gap-5 sm:grid-cols-2">
                                {textFields.map(([key, label, max]) => (
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
                                            name={key}
                                            required
                                            maxLength={max}
                                            value={form.data[key]}
                                            onChange={(e) =>
                                                form.setData(
                                                    key,
                                                    e.target.value,
                                                )
                                            }
                                            aria-invalid={!!form.errors[key]}
                                        />
                                    </Field>
                                ))}
                                <Field
                                    id="unit_price_rp"
                                    label="Harga per satuan (Rp)"
                                    error={form.errors.unit_price_rp}
                                >
                                    <Input
                                        id="unit_price_rp"
                                        type="number"
                                        required
                                        min={1}
                                        max={1000000000}
                                        step={1}
                                        value={form.data.unit_price_rp}
                                        onChange={(e) =>
                                            form.setData(
                                                "unit_price_rp",
                                                e.target.value,
                                            )
                                        }
                                        aria-invalid={
                                            !!form.errors.unit_price_rp
                                        }
                                    />
                                </Field>
                            </div>
                        </Section>
                        <Section
                            title="Ukuran kemasan"
                            description="Ukur satu unit jual dalam kondisi siap dikirim, termasuk kemasannya."
                        >
                            <div className="grid gap-5 sm:grid-cols-2">
                                {sizes.map(([key, label, max]) => (
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
                                            min={1}
                                            max={max}
                                            step={1}
                                            value={form.data[key]}
                                            onChange={(e) =>
                                                form.setData(
                                                    key,
                                                    e.target.value,
                                                )
                                            }
                                            aria-invalid={!!form.errors[key]}
                                        />
                                    </Field>
                                ))}
                                <Field
                                    id="handling_notes"
                                    label="Catatan penanganan (opsional)"
                                    error={form.errors.handling_notes}
                                    className="sm:col-span-2"
                                >
                                    <Textarea
                                        id="handling_notes"
                                        rows={3}
                                        maxLength={1000}
                                        value={form.data.handling_notes}
                                        onChange={(e) =>
                                            form.setData(
                                                "handling_notes",
                                                e.target.value,
                                            )
                                        }
                                    />
                                </Field>
                            </div>
                            <p className="mt-5 rounded-lg bg-muted/60 p-3 text-xs leading-5 text-muted-foreground">
                                10 mm = 1 cm.{" "}
                                {volume > 0 && Number.isFinite(volume)
                                    ? `Perkiraan volume: ${Math.ceil(volume / 1000).toLocaleString("id-ID")} cm³. `
                                    : ""}
                                Volume akhir dihitung otomatis saat disimpan.
                            </p>
                        </Section>
                    </div>
                    <Section
                        title="Visibilitas katalog"
                        description="Atur produk yang dilihat pelanggan."
                    >
                        <div className="flex items-center justify-between gap-3 rounded-lg border p-3">
                            <label
                                htmlFor="is_active"
                                className="text-sm font-medium"
                            >
                                Produk aktif
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
                            Produk nonaktif tetap tersimpan. Stok dicatat
                            terpisah melalui menu Stok setelah produk dibuat.
                        </p>
                        <div className="flex flex-col gap-2 [&>button]:w-full">
                            <SaveButton processing={form.processing}>
                                {product ? "Simpan perubahan" : "Simpan produk"}
                            </SaveButton>
                            <Button variant="outline" asChild>
                                <Link href="/admin/products">Batal</Link>
                            </Button>
                        </div>
                    </Section>
                </div>
            </form>
        </>
    );
}
