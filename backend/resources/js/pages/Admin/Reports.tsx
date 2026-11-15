import { Head, Link, useForm } from "@inertiajs/react";
import {
    PageHeading,
    Section,
    Field,
    Pager,
    EmptyState,
    StatusBadge,
} from "@/components/admin";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { money, dateTime } from "@/lib/format";
import type { Paginated } from "@/types";

type Row = {
    id: number;
    order_number: string;
    recipient_name: string;
    status: string;
    delivery_type: string;
    window_start_at: string;
    total_rp: number;
    cash_received_rp: number;
    trip_number: string | null;
};
type Stats = {
    orders: number;
    delivered: number;
    failed: number;
    cod_received_rp: number;
    cod_deposited_rp: number;
    cash_difference_rp: number;
    stock_difference_items: number;
};

export default function Reports({
    filters,
    stats,
    orders,
}: {
    filters: { from: string; to: string; timezone: string };
    stats: Stats;
    orders: Paginated<Row>;
}) {
    const form = useForm({ from: filters.from, to: filters.to });
    const metrics = [
        ["Pesanan", stats.orders],
        ["Terkirim", stats.delivered],
        ["Gagal diantar", stats.failed],
        ["COD diterima", money(stats.cod_received_rp)],
        ["COD disetor", money(stats.cod_deposited_rp)],
        ["Selisih COD bersih", money(stats.cash_difference_rp)],
        ["Selisih barang", `${stats.stock_difference_items} item`],
    ];
    return (
        <>
            <Head title="Laporan pengiriman" />
            <PageHeading
                title="Laporan pengiriman"
                description="Periode mengikuti tanggal pengantaran. Status, penerimaan dan setoran memakai catatan terkini."
                action={
                    <Button variant="outline" asChild>
                        <a
                            href={`/admin/reports/export?${new URLSearchParams({ from: filters.from, to: filters.to })}`}
                        >
                            Unduh CSV
                        </a>
                    </Button>
                }
            />
            <Section title="Periode laporan">
                <form
                    className="flex flex-wrap items-end gap-4"
                    onSubmit={(event) => {
                        event.preventDefault();
                        form.get("/admin/reports", { preserveState: true });
                    }}
                >
                    <Field
                        id="report-from"
                        label="Dari tanggal"
                        error={form.errors.from}
                    >
                        <Input
                            id="report-from"
                            type="date"
                            required
                            value={form.data.from}
                            onChange={(event) =>
                                form.setData("from", event.target.value)
                            }
                        />
                    </Field>
                    <Field
                        id="report-to"
                        label="Sampai tanggal"
                        error={form.errors.to}
                    >
                        <Input
                            id="report-to"
                            type="date"
                            required
                            value={form.data.to}
                            onChange={(event) =>
                                form.setData("to", event.target.value)
                            }
                        />
                    </Field>
                    <Button disabled={form.processing}>
                        Tampilkan laporan
                    </Button>
                </form>
            </Section>
            <div className="my-5 grid grid-cols-2 gap-3 xl:grid-cols-4">
                {metrics.map(([label, value]) => (
                    <div key={label} className="rounded-xl bg-white p-4">
                        <p className="text-xs text-muted-foreground">{label}</p>
                        <p className="mt-2 break-words text-xl font-semibold tabular-nums">
                            {value}
                        </p>
                    </div>
                ))}
            </div>
            <Section title="Pesanan dalam periode">
                {orders.data.length === 0 ? (
                    <EmptyState
                        title="Belum ada data"
                        description="Pilih periode pengantaran yang memiliki pesanan."
                    />
                ) : (
                    <div className="divide-y">
                        {orders.data.map((order) => (
                            <div
                                key={order.id}
                                className="grid gap-3 py-4 text-sm md:grid-cols-3"
                            >
                                <div>
                                    <Link
                                        className="font-semibold text-primary"
                                        href={`/admin/orders/${order.id}`}
                                    >
                                        {order.order_number}
                                    </Link>
                                    <p>{order.recipient_name}</p>
                                    <p className="mt-1 text-xs text-muted-foreground">
                                        {dateTime(
                                            order.window_start_at,
                                            filters.timezone,
                                        )}
                                    </p>
                                </div>
                                <div className="space-y-2">
                                    <StatusBadge status={order.status} />
                                    <p>
                                        {order.delivery_type === "express"
                                            ? "Express"
                                            : "Reguler"}
                                    </p>
                                    <p className="break-words text-xs text-muted-foreground">
                                        {order.trip_number ??
                                            "Belum masuk trip"}
                                    </p>
                                </div>
                                <div>
                                    <p>Total {money(order.total_rp)}</p>
                                    <p className="mt-1 font-semibold text-primary">
                                        Diterima {money(order.cash_received_rp)}
                                    </p>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
                <Pager page={orders} />
            </Section>
        </>
    );
}
