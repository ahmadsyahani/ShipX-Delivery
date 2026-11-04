import { Head } from "@inertiajs/react";
import { Clock3, MapPin } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table";
import { PageHeading, Section, StatusBadge } from "@/components/admin";
import { dateTime, money, time } from "@/lib/format";
import type { Order } from "@/types";
import OrderDecision, { type DecisionKeys } from "@/components/order-decision";

export default function OrderDetail({
    order,
    decisionKeys,
}: {
    order: Order;
    decisionKeys: DecisionKeys;
}) {
    return (
        <>
            <Head title={order.order_number} />
            <PageHeading
                title={order.order_number}
                description={`Dibuat ${dateTime(order.created_at, order.timezone_snapshot)}`}
                back={{ href: "/admin/orders", label: "Semua pesanan" }}
                action={<StatusBadge status={order.status} />}
            />
            <OrderDecision order={order} keys={decisionKeys} />
            {order.decision && (
                <Section title="Keputusan admin">
                    <p className="text-sm leading-6">
                        {order.decision.decision === "confirmed"
                            ? "Dikonfirmasi"
                            : "Ditolak"}{" "}
                        oleh {order.decision.admin.name} pada{" "}
                        {dateTime(
                            order.decision.decided_at,
                            order.timezone_snapshot,
                        )}
                        .
                    </p>
                    {order.decision.reason && (
                        <p className="mt-2 break-words text-sm text-muted-foreground">
                            Alasan: {order.decision.reason}
                        </p>
                    )}
                </Section>
            )}
            <div className="grid items-start gap-6 xl:grid-cols-[1fr_320px]">
                <div className="space-y-6">
                    <Section title="Tujuan dan jadwal">
                        <div className="grid gap-6 sm:grid-cols-2">
                            <div className="flex items-start gap-3">
                                <MapPin className="mt-1 size-4 shrink-0 text-primary" />
                                <div className="text-sm leading-6">
                                    <p className="font-semibold">
                                        {order.recipient_name}
                                    </p>
                                    <p className="text-muted-foreground">
                                        {order.recipient_phone}
                                    </p>
                                    <p className="mt-3 whitespace-pre-line">
                                        {order.address_text}
                                    </p>
                                    {order.directions && (
                                        <p className="mt-2 whitespace-pre-line text-xs text-muted-foreground">
                                            {order.directions}
                                        </p>
                                    )}
                                </div>
                            </div>
                            <div className="flex items-start gap-3">
                                <Clock3 className="mt-1 size-4 shrink-0 text-primary" />
                                <div className="text-sm leading-6">
                                    <p className="font-medium">
                                        {dateTime(
                                            order.window_start_at,
                                            order.timezone_snapshot,
                                        )}
                                        –
                                        {time(
                                            order.window_end_at,
                                            order.timezone_snapshot,
                                        )}
                                    </p>
                                    <p className="text-xs text-muted-foreground">
                                        {order.timezone_snapshot}
                                    </p>
                                    {order.status === "pending" && (
                                        <p className="mt-3 text-xs text-amber-800">
                                            Batas konfirmasi:{" "}
                                            {dateTime(
                                                order.pending_expires_at,
                                                order.timezone_snapshot,
                                            )}
                                        </p>
                                    )}
                                </div>
                            </div>
                        </div>
                    </Section>
                    <Card className="gap-0 overflow-hidden py-0 shadow-none">
                        <div className="border-b px-5 py-5">
                            <h2 className="font-semibold">
                                Barang yang dipesan
                            </h2>
                            <p className="mt-1 text-xs text-muted-foreground">
                                Informasi tersimpan saat checkout.
                            </p>
                        </div>
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead className="pl-5">
                                        Produk
                                    </TableHead>
                                    <TableHead>Jumlah</TableHead>
                                    <TableHead className="text-right">
                                        Harga satuan
                                    </TableHead>
                                    <TableHead className="pr-5 text-right">
                                        Total
                                    </TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {order.items.map((item) => (
                                    <TableRow key={item.id}>
                                        <TableCell className="max-w-sm whitespace-normal py-4 pl-5">
                                            <p className="font-medium">
                                                {item.product_name_snapshot}
                                            </p>
                                            <p className="mt-1 text-xs text-muted-foreground">
                                                {item.unit_weight_g} g ·{" "}
                                                {item.unit_volume_cm3} cm³
                                            </p>
                                            {item.handling_notes_snapshot && (
                                                <p className="mt-1 text-xs text-muted-foreground">
                                                    {
                                                        item.handling_notes_snapshot
                                                    }
                                                </p>
                                            )}
                                        </TableCell>
                                        <TableCell>
                                            {item.quantity}{" "}
                                            {item.unit_label_snapshot}
                                        </TableCell>
                                        <TableCell className="text-right tabular-nums">
                                            {money(item.unit_price_rp)}
                                        </TableCell>
                                        <TableCell className="pr-5 text-right font-medium tabular-nums">
                                            {money(item.line_total_rp)}
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    </Card>
                </div>
                <Section title="Ringkasan pembayaran">
                    <dl className="space-y-4 text-sm">
                        <div className="flex justify-between gap-3">
                            <dt className="text-muted-foreground">Subtotal</dt>
                            <dd className="tabular-nums">
                                {money(order.subtotal_rp)}
                            </dd>
                        </div>
                        <div className="flex justify-between gap-3">
                            <dt className="text-muted-foreground">Ongkir</dt>
                            <dd className="tabular-nums">
                                {money(order.delivery_fee_rp)}
                            </dd>
                        </div>
                    </dl>
                    <Separator className="my-5" />
                    <div className="flex justify-between gap-3 text-base font-semibold">
                        <span>Total COD</span>
                        <span className="tabular-nums">
                            {money(order.total_rp)}
                        </span>
                    </div>
                    <p className="mt-3 text-xs text-muted-foreground">
                        Tunai ·{" "}
                        {order.payment_status === "unpaid"
                            ? "Belum dibayar"
                            : order.payment_status}
                    </p>
                    <p className="mt-5 text-xs text-muted-foreground">
                        {order.total_weight_g} gram · {order.total_volume_cm3}{" "}
                        cm³
                    </p>
                    {order.status_reason && (
                        <div className="mt-5 rounded-lg bg-muted p-3 text-xs leading-6">
                            Alasan status:{" "}
                            {order.status_reason === "PENDING_EXPIRED"
                                ? "Batas konfirmasi habis"
                                : order.status_reason}
                        </div>
                    )}
                </Section>
            </div>
        </>
    );
}
