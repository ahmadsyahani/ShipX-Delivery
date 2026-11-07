import { useEffect, useState } from "react";
import { Head, Link, router } from "@inertiajs/react";
import { ArrowUpRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
    NativeSelect,
    NativeSelectOption,
} from "@/components/ui/native-select";
import { Card } from "@/components/ui/card";
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
    PageHeading,
    Pager,
    StatusBadge,
} from "@/components/admin";
import { dateTime, money, orderStatus } from "@/lib/format";
import type { Order, Paginated } from "@/types";

export default function Orders({
    orders,
    filters,
}: {
    orders: Paginated<Order>;
    filters: { status: string };
}) {
    const [status, setStatus] = useState(filters.status);
    useEffect(() => setStatus(filters.status), [filters.status]);
    return (
        <>
            <Head title="Pesanan" />
            <PageHeading
                title="Pesanan"
                description="Tinjau pesanan pelanggan, tujuan, dan jadwal pengirimannya."
            />
            <Card className="gap-0 overflow-hidden py-0 shadow-none">
                <form
                    className="flex flex-wrap items-center gap-3 border-b p-4"
                    onSubmit={(e) => {
                        e.preventDefault();
                        router.get(
                            "/admin/orders",
                            { status },
                            { preserveState: true, replace: true },
                        );
                    }}
                >
                    <NativeSelect
                        aria-label="Status pesanan"
                        value={status}
                        onChange={(e) => setStatus(e.target.value)}
                    >
                        <NativeSelectOption value="">
                            Semua status
                        </NativeSelectOption>
                        {[
                            "pending",
                            "confirmed",
                            "assigned",
                            "out_for_delivery",
                            "delivered",
                            "failed",
                            "rejected",
                            "cancelled",
                        ].map((value) => (
                            <NativeSelectOption key={value} value={value}>
                                {orderStatus[value]}
                            </NativeSelectOption>
                        ))}
                    </NativeSelect>
                    <Button variant="outline">Terapkan</Button>
                    {filters.status && (
                        <Button variant="ghost" asChild>
                            <Link href="/admin/orders">Reset</Link>
                        </Button>
                    )}
                </form>
                {orders.data.length ? (
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="pl-5">
                                    Pesanan / penerima
                                </TableHead>
                                <TableHead>Jadwal pengiriman</TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead className="text-right">
                                    Total COD
                                </TableHead>
                                <TableHead className="pr-5 text-right">
                                    Aksi
                                </TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {orders.data.map((order) => (
                                <TableRow key={order.id}>
                                    <TableCell className="py-4 pl-5">
                                        <Link
                                            href={`/admin/orders/${order.id}`}
                                            className="text-sm font-medium text-primary hover:underline"
                                        >
                                            {order.order_number}
                                        </Link>
                                        <p className="mt-1 text-xs text-muted-foreground">
                                            {order.recipient_name}
                                        </p>
                                    </TableCell>
                                    <TableCell className="text-xs text-muted-foreground">
                                        {dateTime(
                                            order.window_start_at,
                                            order.timezone_snapshot,
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        <StatusBadge status={order.status} />
                                    </TableCell>
                                    <TableCell className="text-right font-medium tabular-nums">
                                        {money(order.total_rp)}
                                    </TableCell>
                                    <TableCell className="pr-5 text-right">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            asChild
                                        >
                                            <Link
                                                href={`/admin/orders/${order.id}`}
                                            >
                                                Detail
                                                <ArrowUpRight />
                                            </Link>
                                        </Button>
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                ) : (
                    <EmptyState
                        title="Belum ada pesanan"
                        description={
                            filters.status
                                ? "Belum ada pesanan dengan status ini. Pilih status lain untuk melihat pesanan."
                                : "Pesanan akan muncul setelah pelanggan checkout melalui aplikasi ShipX."
                        }
                    />
                )}
                <Pager page={orders} />
            </Card>
            <p className="max-w-3xl text-xs leading-6 text-muted-foreground">
                Buka detail untuk mengonfirmasi atau menolak pesanan pending.
                Penugasan dan pengantaran menyusul. Pesanan pending yang
                melewati batas waktu dibatalkan otomatis dan reservasi stok
                dilepas.
            </p>
        </>
    );
}
