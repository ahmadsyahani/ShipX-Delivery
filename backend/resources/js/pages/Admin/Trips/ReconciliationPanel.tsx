import { useState } from "react";
import { useForm } from "@inertiajs/react";
import { CheckCircle2, PackageCheck, Wallet } from "lucide-react";
import { Field, FormErrors, Section } from "@/components/admin";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { NativeSelect } from "@/components/ui/native-select";
import {
    AlertDialog,
    AlertDialogContent,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogCancel,
} from "@/components/ui/alert-dialog";
import { dateTime, money } from "@/lib/format";
import type { Trip } from "./types";

export type ReturnProduct = { id: number; name: string; sku: string };
type Count = {
    product_id: string;
    name: string;
    sku: string;
    stock_state: string;
    expected_quantity: number;
};
type RecordedItem = Count & {
    actual_quantity: number;
    difference: number;
    discrepancy_reason: string | null;
};
export type Reconciliation = {
    expected_cash_rp: number;
    items: Count[];
    record: null | {
        expected_cash_rp: number;
        actual_cash_rp: number;
        cash_difference_rp: number;
        discrepancy_reason: string | null;
        approved_at: string;
        approved_by_name: string;
        items: RecordedItem[];
    };
};
type InputRow = {
    product_id: number;
    available_quantity: string;
    quarantine_quantity: string;
    discrepancy_reason: string;
};

export default function ReconciliationPanel({
    trip,
    summary,
    products,
    idempotencyKey,
}: {
    trip: Trip;
    summary: Reconciliation;
    products: ReturnProduct[];
    idempotencyKey: string;
}) {
    const [confirming, setConfirming] = useState(false);
    const [extra, setExtra] = useState("");
    const ids = [...new Set(summary.items.map((i) => Number(i.product_id)))];
    const form = useForm({
        idempotency_key: idempotencyKey,
        lock_version: trip.lock_version,
        actual_cash_rp: "",
        discrepancy_reason: "",
        received_and_approved: false,
        items: ids.map((id): InputRow => ({
            product_id: id,
            available_quantity: "",
            quarantine_quantity: "",
            discrepancy_reason: "",
        })),
    });
    const expected = (id: number, state: string) =>
        summary.items.find(
            (i) => Number(i.product_id) === id && i.stock_state === state,
        )?.expected_quantity ?? 0;
    const edit = (
        index: number,
        field: keyof Omit<InputRow, "product_id">,
        value: string,
    ) =>
        form.setData(
            "items",
            form.data.items.map((row, i) =>
                i === index ? { ...row, [field]: value } : row,
            ),
        );
    const record = summary.record;
    if (record)
        return (
            <Section
                title="Trip selesai"
                description={`Disetujui ${record.approved_by_name} pada ${dateTime(record.approved_at, trip.timezone_snapshot)}`}
            >
                <div className="mb-6 flex items-start gap-3 text-primary">
                    <CheckCircle2 className="mt-0.5 size-5 shrink-0" />
                    <p className="text-sm leading-6">
                        Barang kembali dan setoran sudah diterima. Kurir serta
                        kendaraan telah dilepas untuk penugasan berikutnya.
                    </p>
                </div>
                <dl className="grid gap-4 text-sm sm:grid-cols-3">
                    <div>
                        <dt className="text-muted-foreground">COD tercatat</dt>
                        <dd className="mt-1 font-semibold">
                            {money(record.expected_cash_rp)}
                        </dd>
                    </div>
                    <div>
                        <dt className="text-muted-foreground">
                            Setoran diterima
                        </dt>
                        <dd className="mt-1 font-semibold">
                            {money(record.actual_cash_rp)}
                        </dd>
                    </div>
                    <div>
                        <dt className="text-muted-foreground">
                            Selisih setoran
                        </dt>
                        <dd className="mt-1 font-semibold">
                            {money(record.cash_difference_rp)}
                        </dd>
                    </div>
                </dl>
                {record.discrepancy_reason && (
                    <p className="mt-4 break-words text-sm">
                        Alasan selisih uang: {record.discrepancy_reason}
                    </p>
                )}
                <div className="mt-6 divide-y">
                    {record.items.map((row) => (
                        <div
                            key={`${row.product_id}-${row.stock_state}`}
                            className="py-3 text-sm"
                        >
                            <p className="break-words font-medium">
                                {row.name} ·{" "}
                                {row.stock_state === "available"
                                    ? "Layak jual"
                                    : "Karantina"}
                            </p>
                            <p className="mt-1 text-muted-foreground">
                                Perkiraan {row.expected_quantity} · Diterima{" "}
                                {row.actual_quantity} item · Selisih{" "}
                                {row.difference > 0 ? "+" : ""}
                                {row.difference}
                            </p>
                            {row.discrepancy_reason && (
                                <p className="mt-2 break-words">
                                    {row.discrepancy_reason}
                                </p>
                            )}
                        </div>
                    ))}
                </div>
            </Section>
        );
    if (trip.status !== "awaiting_reconciliation") return null;
    const cashDiff =
        form.data.actual_cash_rp === ""
            ? null
            : Number(form.data.actual_cash_rp) - summary.expected_cash_rp;
    return (
        <Section
            title="Terima barang & setoran"
            description="Hitung bersama kurir setelah kembali ke depot. Isi 0 jika tidak ada barang atau uang yang diterima."
        >
            <form
                className="space-y-7"
                onSubmit={(e) => {
                    e.preventDefault();
                    setConfirming(true);
                }}
            >
                <FormErrors errors={form.errors} />
                <fieldset disabled={form.processing} className="space-y-5">
                    <legend className="mb-4 flex items-center gap-2 text-sm font-semibold">
                        <PackageCheck className="size-5 text-primary" />
                        Barang kembali
                    </legend>
                    {form.data.items.map((row, index) => {
                        const product =
                            products.find((p) => p.id === row.product_id) ??
                            summary.items.find(
                                (p) => Number(p.product_id) === row.product_id,
                            );
                        const changed =
                            (row.available_quantity !== "" &&
                                Number(row.available_quantity) !==
                                    expected(row.product_id, "available")) ||
                            (row.quarantine_quantity !== "" &&
                                Number(row.quarantine_quantity) !==
                                    expected(row.product_id, "quarantine"));
                        return (
                            <div
                                key={row.product_id}
                                className="space-y-4 rounded-xl border p-4 sm:p-5"
                            >
                                <div>
                                    <p className="break-words font-semibold">
                                        {product?.name}
                                    </p>
                                    <p className="mt-1 break-all text-xs text-muted-foreground">
                                        {product?.sku}
                                    </p>
                                    <p className="mt-2 text-sm text-muted-foreground">
                                        Perkiraan kembali:{" "}
                                        {expected(row.product_id, "available")}{" "}
                                        layak jual ·{" "}
                                        {expected(row.product_id, "quarantine")}{" "}
                                        karantina
                                    </p>
                                </div>
                                <div className="grid gap-4 sm:grid-cols-2">
                                    {(["available", "quarantine"] as const).map(
                                        (state) => (
                                            <Field
                                                key={state}
                                                label={
                                                    state === "available"
                                                        ? "Diterima layak jual (item)"
                                                        : "Diterima karantina (item)"
                                                }
                                                id={`return-${state}-${row.product_id}`}
                                            >
                                                <Input
                                                    id={`return-${state}-${row.product_id}`}
                                                    type="number"
                                                    inputMode="numeric"
                                                    min={0}
                                                    max={1000000}
                                                    step={1}
                                                    required
                                                    value={
                                                        row[`${state}_quantity`]
                                                    }
                                                    onChange={(e) =>
                                                        edit(
                                                            index,
                                                            `${state}_quantity`,
                                                            e.target.value,
                                                        )
                                                    }
                                                />
                                            </Field>
                                        ),
                                    )}
                                </div>
                                {changed && (
                                    <Field
                                        label="Alasan selisih / perubahan kondisi"
                                        id={`return-reason-${row.product_id}`}
                                    >
                                        <Textarea
                                            id={`return-reason-${row.product_id}`}
                                            required
                                            maxLength={500}
                                            value={row.discrepancy_reason}
                                            onChange={(e) =>
                                                edit(
                                                    index,
                                                    "discrepancy_reason",
                                                    e.target.value,
                                                )
                                            }
                                            placeholder="Contoh: 1 item rusak, dipindahkan ke karantina."
                                        />
                                    </Field>
                                )}
                            </div>
                        );
                    })}
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
                        <Field
                            label="Ada barang lain yang ikut kembali?"
                            id="extra-return"
                        >
                            <NativeSelect
                                id="extra-return"
                                value={extra}
                                onChange={(e) => setExtra(e.target.value)}
                            >
                                <option value="">Pilih barang tambahan</option>
                                {products
                                    .filter(
                                        (p) =>
                                            !form.data.items.some(
                                                (row) =>
                                                    row.product_id === p.id,
                                            ),
                                    )
                                    .map((p) => (
                                        <option key={p.id} value={p.id}>
                                            {p.name} ({p.sku})
                                        </option>
                                    ))}
                            </NativeSelect>
                        </Field>
                        <Button
                            type="button"
                            variant="outline"
                            disabled={!extra}
                            onClick={() => {
                                form.setData("items", [
                                    ...form.data.items,
                                    {
                                        product_id: Number(extra),
                                        available_quantity: "",
                                        quarantine_quantity: "",
                                        discrepancy_reason: "",
                                    },
                                ]);
                                setExtra("");
                            }}
                        >
                            Tambahkan barang
                        </Button>
                    </div>
                </fieldset>
                <fieldset
                    disabled={form.processing}
                    className="space-y-4 border-t pt-6"
                >
                    <legend className="float-left mb-4 flex w-full items-center gap-2 text-sm font-semibold">
                        <Wallet className="size-5 text-primary" />
                        Setoran COD
                    </legend>
                    <p className="clear-both text-sm text-muted-foreground">
                        COD tercatat dari pengiriman berhasil:{" "}
                        <span className="font-semibold text-foreground">
                            {money(summary.expected_cash_rp)}
                        </span>
                    </p>
                    <Field
                        label="Uang yang benar-benar diterima (Rp)"
                        id="actual-cash"
                    >
                        <Input
                            id="actual-cash"
                            type="number"
                            inputMode="numeric"
                            min={0}
                            max={100000000000000}
                            step={1}
                            required
                            value={form.data.actual_cash_rp}
                            onChange={(e) =>
                                form.setData("actual_cash_rp", e.target.value)
                            }
                        />
                    </Field>
                    {cashDiff !== null && (
                        <p className="text-sm">
                            Selisih setoran: <strong>{money(cashDiff)}</strong>
                        </p>
                    )}
                    {cashDiff !== null && cashDiff !== 0 && (
                        <Field label="Alasan selisih uang" id="cash-reason">
                            <Textarea
                                id="cash-reason"
                                required
                                maxLength={500}
                                value={form.data.discrepancy_reason}
                                onChange={(e) =>
                                    form.setData(
                                        "discrepancy_reason",
                                        e.target.value,
                                    )
                                }
                            />
                        </Field>
                    )}
                    <label className="flex items-start gap-3 text-sm leading-6">
                        <input
                            className="mt-1 size-4 shrink-0 accent-primary"
                            type="checkbox"
                            required
                            checked={form.data.received_and_approved}
                            onChange={(e) =>
                                form.setData(
                                    "received_and_approved",
                                    e.target.checked,
                                )
                            }
                        />
                        <span>
                            Saya sudah menerima barang dan uang di depot, serta
                            menyetujui hasil hitung dan seluruh selisih yang
                            dicatat.
                        </span>
                    </label>
                </fieldset>
                <Button type="submit" disabled={form.processing}>
                    Tinjau & tutup trip
                </Button>
            </form>
            <AlertDialog
                open={confirming}
                onOpenChange={(open) => {
                    if (!form.processing) setConfirming(open);
                }}
            >
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>Tutup trip ini?</AlertDialogTitle>
                        <AlertDialogDescription>
                            Setoran {money(Number(form.data.actual_cash_rp))}{" "}
                            dan hasil hitung {form.data.items.length} jenis
                            barang akan dicatat final. Stok depot diperbarui,
                            lalu kurir serta kendaraan dilepas. Periksa kembali
                            sebelum menyetujui.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel disabled={form.processing}>
                            Periksa lagi
                        </AlertDialogCancel>
                        <Button
                            type="button"
                            disabled={form.processing}
                            onClick={() =>
                                form.post(`/admin/trips/${trip.id}/reconcile`, {
                                    onSuccess: () => setConfirming(false),
                                    onError: () => setConfirming(false),
                                    preserveScroll: true,
                                })
                            }
                        >
                            {form.processing
                                ? "Menyimpan…"
                                : "Setujui & tutup trip"}
                        </Button>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
        </Section>
    );
}
