import { useEffect, useRef, useState } from "react";
import { Head, Link, useForm } from "@inertiajs/react";
import { ImagePlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { NativeSelect } from "@/components/ui/native-select";
import {
    Field,
    FormErrors,
    PageHeading,
    SaveButton,
    Section,
} from "@/components/admin";
import type { Product } from "@/types";

export default function ProductForm({
    product,
    categories,
}: {
    product: Product | null;
    categories: string[];
}) {
    const photoInput = useRef<HTMLInputElement>(null);
    const [preview, setPreview] = useState<string | null>(null);
    const [addingCategory, setAddingCategory] = useState(false);
    const form = useForm({
        name: product?.name ?? "",
        sku: product?.sku ?? "",
        category: product?.category ?? "",
        unit_label: product?.unit_label ?? "item",
        unit_price_rp: String(product?.unit_price_rp ?? ""),
        shipping_weight_g: String(product?.shipping_weight_g ?? ""),
        length_mm: String(product?.length_mm ?? ""),
        width_mm: String(product?.width_mm ?? ""),
        height_mm: String(product?.height_mm ?? ""),
        handling_notes: product?.handling_notes ?? "",
        is_active: product?.is_active ?? false,
        lock_version: product?.lock_version ?? 0,
        photo: null as File | null,
        remove_photo: false,
    });
    useEffect(() => {
        if (!form.data.photo) {
            setPreview(null);
            return;
        }
        const url = URL.createObjectURL(form.data.photo);
        setPreview(url);
        return () => URL.revokeObjectURL(url);
    }, [form.data.photo]);
    const photoUrl =
        preview ?? (form.data.remove_photo ? null : product?.photo_url);
    const textFields = [
        ["name", "Nama produk", 160],
        ["sku", "Kode SKU", 64],
    ] as const;
    const sizes = [
        ["shipping_weight_g", "Berat satu item (kg)", 1000000, 1000],
        ["length_mm", "Panjang kemasan (cm)", 10000, 10],
        ["width_mm", "Lebar kemasan (cm)", 10000, 10],
        ["height_mm", "Tinggi kemasan (cm)", 10000, 10],
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
                    form.transform((data) =>
                        product && data.photo
                            ? { ...data, _method: "put" }
                            : data,
                    );
                    if (product && form.data.photo) {
                        form.post(`/admin/products/${product.id}`, {
                            forceFormData: true,
                        });
                    } else if (product) {
                        form.put(`/admin/products/${product.id}`);
                    } else {
                        form.post("/admin/products");
                    }
                }}
            >
                <FormErrors errors={form.errors} />
                <div className="grid items-start gap-6 xl:grid-cols-[1fr_300px]">
                    <div className="space-y-6">
                        <Section
                            title="Foto produk"
                            description="Foto ini ditampilkan pada katalog dan keranjang pelanggan."
                        >
                            <div className="grid items-start gap-5 sm:grid-cols-[160px_1fr]">
                                <div className="grid aspect-square w-full max-w-52 place-items-center overflow-hidden rounded-2xl border bg-muted/30">
                                    {photoUrl ? (
                                        <img
                                            key={photoUrl}
                                            src={photoUrl}
                                            alt="Preview foto produk"
                                            className="h-full w-full object-contain"
                                        />
                                    ) : (
                                        <ImagePlus
                                            className="size-10 text-muted-foreground"
                                            aria-hidden="true"
                                        />
                                    )}
                                </div>
                                <div className="min-w-0 space-y-3">
                                    <Field
                                        id="photo"
                                        label="Pilih foto produk"
                                        error={form.errors.photo}
                                        hint="Opsional. JPG, PNG atau WebP, maksimal 2 MB dan 4096 × 4096 piksel."
                                    >
                                        <Input
                                            ref={photoInput}
                                            id="photo"
                                            name="photo"
                                            type="file"
                                            accept="image/jpeg,image/png,image/webp"
                                            disabled={form.processing}
                                            className="h-auto min-h-11 py-2"
                                            onChange={(event) => {
                                                form.setData({
                                                    ...form.data,
                                                    photo:
                                                        event.target
                                                            .files?.[0] ?? null,
                                                    remove_photo: false,
                                                });
                                                form.clearErrors("photo");
                                            }}
                                        />
                                    </Field>
                                    {(photoUrl || form.data.remove_photo) && (
                                        <Button
                                            type="button"
                                            variant="outline"
                                            disabled={form.processing}
                                            onClick={() => {
                                                form.setData({
                                                    ...form.data,
                                                    photo: null,
                                                    remove_photo:
                                                        !form.data.remove_photo,
                                                });
                                                if (photoInput.current)
                                                    photoInput.current.value =
                                                        "";
                                            }}
                                        >
                                            {form.data.remove_photo
                                                ? "Batalkan penghapusan"
                                                : "Hapus foto"}
                                        </Button>
                                    )}
                                    <p className="text-xs leading-6 text-muted-foreground">
                                        Perubahan foto diterapkan saat produk
                                        disimpan.
                                    </p>
                                </div>
                            </div>
                        </Section>
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
                                        hint={
                                            key === "sku" && !product
                                                ? "Kosongkan agar kode dibuat otomatis saat disimpan."
                                                : undefined
                                        }
                                        className={
                                            key === "name"
                                                ? "sm:col-span-2"
                                                : ""
                                        }
                                    >
                                        <Input
                                            id={key}
                                            name={key}
                                            required={
                                                key !== "sku" || !!product
                                            }
                                            placeholder={
                                                key === "sku" && !product
                                                    ? "Otomatis saat disimpan"
                                                    : undefined
                                            }
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
                                    id="category"
                                    label="Kategori"
                                    error={form.errors.category}
                                    className="[&>[data-slot=native-select-wrapper]]:w-full"
                                >
                                    <NativeSelect
                                        id="category"
                                        required
                                        value={
                                            addingCategory
                                                ? "new"
                                                : form.data.category
                                                  ? `category:${form.data.category}`
                                                  : ""
                                        }
                                        aria-invalid={!!form.errors.category}
                                        onChange={(event) => {
                                            const isNew =
                                                event.target.value === "new";
                                            setAddingCategory(isNew);
                                            form.setData(
                                                "category",
                                                isNew
                                                    ? ""
                                                    : event.target.value.slice(
                                                          "category:".length,
                                                      ),
                                            );
                                        }}
                                    >
                                        <option value="" disabled>
                                            Pilih kategori
                                        </option>
                                        {categories.map((category) => (
                                            <option
                                                key={category}
                                                value={`category:${category}`}
                                            >
                                                {category}
                                            </option>
                                        ))}
                                        <option value="new">
                                            + Tambah kategori baru
                                        </option>
                                    </NativeSelect>
                                    {addingCategory && (
                                        <Field
                                            id="new_category"
                                            label="Nama kategori baru"
                                        >
                                            <Input
                                                id="new_category"
                                                required
                                                maxLength={80}
                                                autoFocus
                                                value={form.data.category}
                                                onChange={(event) =>
                                                    form.setData(
                                                        "category",
                                                        event.target.value,
                                                    )
                                                }
                                                aria-invalid={
                                                    !!form.errors.category
                                                }
                                            />
                                        </Field>
                                    )}
                                </Field>
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
                        <details
                            open={!product}
                            className="rounded-xl border bg-card p-5"
                        >
                            <summary className="mb-5 cursor-pointer text-sm font-semibold">
                                Detail pengiriman barang
                            </summary>
                            <Section
                                title="Data kemasan untuk pengiriman"
                                description="Ukur satu unit jual dalam kondisi siap dikirim, termasuk kemasannya."
                            >
                                <div className="grid gap-5 sm:grid-cols-2">
                                    {sizes.map(([key, label, max, scale]) => (
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
                                                min={1 / scale}
                                                max={max / scale}
                                                step={1 / scale}
                                                value={
                                                    form.data[key] === ""
                                                        ? ""
                                                        : Number(
                                                              form.data[key],
                                                          ) / scale
                                                }
                                                onChange={(e) =>
                                                    form.setData(
                                                        key,
                                                        e.target.value === ""
                                                            ? ""
                                                            : String(
                                                                  Math.round(
                                                                      Number(
                                                                          e
                                                                              .target
                                                                              .value,
                                                                      ) * scale,
                                                                  ),
                                                              ),
                                                    )
                                                }
                                                aria-invalid={
                                                    !!form.errors[key]
                                                }
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
                                <p className="mt-5 text-xs leading-6 text-muted-foreground">
                                    Detail ini dipakai untuk memeriksa kecocokan
                                    kendaraan. Pelanggan melihat jumlah item.
                                </p>
                            </Section>
                        </details>
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
