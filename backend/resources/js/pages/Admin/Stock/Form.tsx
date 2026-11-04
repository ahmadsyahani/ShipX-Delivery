import { Head, useForm } from "@inertiajs/react";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
    NativeSelect,
    NativeSelectOption,
} from "@/components/ui/native-select";
import { Card, CardContent } from "@/components/ui/card";
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table";
import {
    EmptyState,
    Field,
    FormErrors,
    PageHeading,
    Pager,
    SaveButton,
    Section,
} from "@/components/admin";
import { dateTime } from "@/lib/format";
import type { Paginated, Product } from "@/types";

type Entry = {
    created_at: string;
    stock_state: string;
    quantity_delta: number;
    kind: string;
    reason: string;
};
export default function StockForm({
    product,
    mutationKey,
    entries,
}: {
    product: Product;
    mutationKey: string;
    entries: Paginated<Entry>;
}) {
    const form = useForm({
        idempotency_key: mutationKey,
        stock_state: "available",
        quantity_delta: "",
        reason: "",
    });
    const counts = [
        ["Fisik tersedia", Number(product.physical_quantity ?? 0)],
        ["Direservasi", Number(product.reserved_quantity ?? 0)],
        [
            "Siap dipesan",
            Math.max(
                0,
                Number(product.physical_quantity ?? 0) -
                    Number(product.reserved_quantity ?? 0),
            ),
        ],
        ["Karantina", Number(product.quarantine_quantity ?? 0)],
    ];
    return (
        <>
            <Head title={`Stok ${product.name}`} />
            <PageHeading
                title={product.name}
                description={`${product.sku} · Satuan ${product.unit_label}`}
                back={{ href: "/admin/stock", label: "Stok depot" }}
            />
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                {counts.map(([label, value]) => (
                    <Card key={label} className="shadow-none">
                        <CardContent>
                            <p className="text-xs text-muted-foreground">
                                {label}
                            </p>
                            <p className="mt-3 text-2xl font-semibold tabular-nums">
                                {value}
                            </p>
                        </CardContent>
                    </Card>
                ))}
            </div>
            <form
                className="space-y-5"
                onSubmit={(e) => {
                    e.preventDefault();
                    form.post(`/admin/stock/${product.id}`, {
                        preserveScroll: true,
                        onSuccess: (page) => {
                            // Inertia preserves same-page form state after POST. A successful mutation
                            // must adopt the NEW server key so a subsequent intent is not a replay.
                            if (typeof page.props.mutationKey === "string")
                                form.setData({
                                    idempotency_key: page.props.mutationKey,
                                    stock_state: "available",
                                    quantity_delta: "",
                                    reason: "",
                                });
                        },
                    });
                }}
            >
                <FormErrors errors={form.errors} />
                <Section
                    title="Catat perubahan stok"
                    description="Angka positif menambah stok, angka negatif mengurangi. Setiap perubahan dicatat dalam riwayat."
                >
                    <fieldset
                        disabled={form.processing}
                        className="grid gap-5 sm:grid-cols-2"
                    >
                        <Field
                            id="stock_state"
                            label="Kondisi stok"
                            error={form.errors.stock_state}
                        >
                            <NativeSelect
                                id="stock_state"
                                className="w-full"
                                value={form.data.stock_state}
                                onChange={(e) =>
                                    form.setData("stock_state", e.target.value)
                                }
                            >
                                <NativeSelectOption value="available">
                                    Tersedia
                                </NativeSelectOption>
                                <NativeSelectOption value="quarantine">
                                    Karantina
                                </NativeSelectOption>
                            </NativeSelect>
                        </Field>
                        <Field
                            id="quantity_delta"
                            label={`Perubahan jumlah (${product.unit_label})`}
                            error={form.errors.quantity_delta}
                        >
                            <Input
                                id="quantity_delta"
                                type="number"
                                min={-1000000}
                                max={1000000}
                                step={1}
                                required
                                placeholder="Contoh: 10 atau -2"
                                value={form.data.quantity_delta}
                                onChange={(e) =>
                                    form.setData(
                                        "quantity_delta",
                                        e.target.value,
                                    )
                                }
                                aria-invalid={!!form.errors.quantity_delta}
                            />
                        </Field>
                        <Field
                            id="reason"
                            label="Alasan perubahan"
                            error={form.errors.reason}
                            className="sm:col-span-2"
                        >
                            <Textarea
                                id="reason"
                                required
                                maxLength={500}
                                rows={2}
                                placeholder="Contoh: stok awal hasil pemeriksaan fisik"
                                value={form.data.reason}
                                onChange={(e) =>
                                    form.setData("reason", e.target.value)
                                }
                                aria-invalid={!!form.errors.reason}
                            />
                        </Field>
                    </fieldset>
                    <div className="mt-5 flex flex-wrap items-center justify-between gap-4">
                        <p className="max-w-xl text-xs leading-5 text-muted-foreground">
                            Saldo akhir tidak boleh negatif atau kurang dari
                            reservasi aktif. Catat hanya jumlah yang sudah
                            diperiksa.
                        </p>
                        <SaveButton processing={form.processing}>
                            Catat mutasi
                        </SaveButton>
                    </div>
                </Section>
            </form>
            <Card className="gap-0 overflow-hidden py-0 shadow-none">
                <div className="border-b px-5 py-5">
                    <h2 className="font-semibold">Riwayat stok</h2>
                    <p className="mt-1 text-xs text-muted-foreground">
                        Waktu ditampilkan dalam WIB (Asia/Jakarta).
                    </p>
                </div>
                {entries.data.length ? (
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="pl-5">Waktu</TableHead>
                                <TableHead>Kondisi</TableHead>
                                <TableHead className="text-right">
                                    Perubahan
                                </TableHead>
                                <TableHead>Jenis</TableHead>
                                <TableHead className="pr-5">Alasan</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {entries.data.map((entry, index) => (
                                <TableRow key={index}>
                                    <TableCell className="py-4 pl-5 text-xs text-muted-foreground">
                                        {dateTime(
                                            entry.created_at.replace(" ", "T") +
                                                (entry.created_at.includes("Z")
                                                    ? ""
                                                    : "Z"),
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        {entry.stock_state === "available"
                                            ? "Tersedia"
                                            : "Karantina"}
                                    </TableCell>
                                    <TableCell className="text-right font-medium tabular-nums">
                                        {entry.quantity_delta > 0 ? "+" : ""}
                                        {entry.quantity_delta}
                                    </TableCell>
                                    <TableCell className="text-xs">
                                        {entry.kind === "opening"
                                            ? "Stok awal"
                                            : "Penyesuaian"}
                                    </TableCell>
                                    <TableCell className="max-w-md whitespace-normal pr-5 text-sm">
                                        {entry.reason}
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                ) : (
                    <EmptyState
                        title="Belum ada mutasi stok"
                        description="Catat stok awal berdasarkan jumlah barang yang benar-benar tersedia di depot."
                    />
                )}
                <Pager page={entries} />
            </Card>
        </>
    );
}
