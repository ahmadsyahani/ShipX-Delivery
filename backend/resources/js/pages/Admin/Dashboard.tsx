import { Head, Link, usePage } from "@inertiajs/react";
import {
    ArrowRight,
    CalendarClock,
    ClipboardList,
    MapPin,
    Package,
    Plus,
} from "lucide-react";
import { Button } from "@/components/ui/button";
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
    PageHeading,
    EmptyState,
    Section,
    StatusBadge,
} from "@/components/admin";
import { money } from "@/lib/format";
import type { Order, Shared } from "@/types";

type Props = {
    depot: { name: string; configured: boolean; timezone: string };
    stats: {
        products: number;
        pending: number;
        confirmed: number;
        open_slots: number;
    };
    recentOrders: Order[];
};
export default function Dashboard({ depot, stats, recentOrders }: Props) {
    const { auth } = usePage<Shared>().props;
    const cards = [
        {
            label: "Menunggu konfirmasi",
            value: stats.pending,
            icon: ClipboardList,
            href: "/admin/orders?status=pending",
            hint: "Pesanan pending",
        },
        {
            label: "Produk aktif",
            value: stats.products,
            icon: Package,
            href: "/admin/products?status=active",
            hint: "Tampil di katalog pelanggan",
        },
        {
            label: "Slot terbuka",
            value: stats.open_slots,
            icon: CalendarClock,
            href: "/admin/slots",
            hint: "Masih menerima pesanan",
        },
    ];
    return (
        <>
            <Head title="Ringkasan" />
            <PageHeading
                title={`Selamat bekerja, ${auth.user?.name.split(" ")[0] ?? "Admin"}.`}
                description="Pantau pesanan dan siapkan kebutuhan pengiriman hari ini."
                action={
                    <Button asChild>
                        <Link href="/admin/products/create">
                            <Plus />
                            Tambah produk
                        </Link>
                    </Button>
                }
            />
            <div className="grid gap-4 sm:grid-cols-3">
                {cards.map(({ label, value, icon: Icon, href, hint }) => (
                    <Link
                        key={label}
                        href={href}
                        className="rounded-xl focus-visible:outline-2 focus-visible:outline-ring"
                    >
                        <Card className="h-full shadow-none transition-colors hover:border-primary/40">
                            <CardContent className="pt-0">
                                <div className="mb-5 flex items-center justify-between gap-2">
                                    <span className="text-sm text-muted-foreground">
                                        {label}
                                    </span>
                                    <Icon className="size-[18px] text-primary" />
                                </div>
                                <div className="text-3xl font-semibold tabular-nums tracking-tight">
                                    {value}
                                </div>
                                <p className="mt-2 text-xs text-muted-foreground">
                                    {hint}
                                </p>
                            </CardContent>
                        </Card>
                    </Link>
                ))}
            </div>
            <div className="grid gap-6 xl:grid-cols-[1fr_320px]">
                <Card className="gap-0 overflow-hidden shadow-none">
                    <div className="flex flex-wrap items-center justify-between gap-3 border-b px-6 py-5">
                        <div>
                            <h2 className="font-semibold">Pesanan terbaru</h2>
                            <p className="mt-1 text-xs text-muted-foreground">
                                Aktivitas pemesanan pelanggan.
                            </p>
                        </div>
                        <Button variant="ghost" size="sm" asChild>
                            <Link href="/admin/orders">
                                Semua pesanan
                                <ArrowRight />
                            </Link>
                        </Button>
                    </div>
                    {recentOrders.length ? (
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead className="pl-6">
                                        Pesanan
                                    </TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead className="pr-6 text-right">
                                        Total COD
                                    </TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {recentOrders.map((order) => (
                                    <TableRow key={order.id}>
                                        <TableCell className="py-4 pl-6">
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
                                        <TableCell>
                                            <StatusBadge
                                                status={order.status}
                                            />
                                        </TableCell>
                                        <TableCell className="pr-6 text-right font-medium tabular-nums">
                                            {money(order.total_rp)}
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    ) : (
                        <EmptyState
                            title="Belum ada pesanan"
                            description="Pesanan pelanggan akan tampil di sini setelah checkout. Pastikan stok dan slot pengiriman sudah siap."
                            action={
                                <Button variant="outline" asChild>
                                    <Link href="/admin/stock">
                                        Periksa stok
                                    </Link>
                                </Button>
                            }
                        />
                    )}
                </Card>
                <div className="space-y-5">
                    <Section
                        title={depot.name}
                        description="Pusat pemenuhan ShipX"
                    >
                        <div className="flex items-start gap-3 rounded-lg bg-muted/60 p-3">
                            <MapPin className="mt-0.5 size-4 shrink-0 text-primary" />
                            <div>
                                <p className="text-sm font-medium">
                                    {depot.configured
                                        ? "Wilayah layanan siap"
                                        : "Lengkapi wilayah layanan"}
                                </p>
                                <p className="mt-1 text-xs leading-5 text-muted-foreground">
                                    {depot.configured
                                        ? `Jadwal mengikuti ${depot.timezone}.`
                                        : "Tentukan lokasi, radius, dan ongkir sebelum menerima pesanan."}
                                </p>
                            </div>
                        </div>
                        <Button
                            variant="outline"
                            className="mt-4 w-full"
                            asChild
                        >
                            <Link href="/admin/depot">
                                Lihat depot
                                <ArrowRight />
                            </Link>
                        </Button>
                    </Section>
                    <div className="rounded-xl border border-dashed p-5">
                        <h2 className="text-sm font-semibold">
                            Sebelum menerima pesanan
                        </h2>
                        <ul className="mt-3 space-y-3 text-sm text-muted-foreground">
                            {[
                                [
                                    "/admin/products",
                                    "Lengkapi harga dan kemasan",
                                ],
                                [
                                    "/admin/stock",
                                    "Catat stok fisik yang tersedia",
                                ],
                                ["/admin/slots", "Siapkan jadwal pengiriman"],
                            ].map(([href, text]) => (
                                <li key={href}>
                                    <Link
                                        href={href}
                                        className="flex items-center justify-between gap-2 hover:text-primary"
                                    >
                                        {text}
                                        <ArrowRight className="size-3.5 shrink-0" />
                                    </Link>
                                </li>
                            ))}
                        </ul>
                    </div>
                </div>
            </div>
        </>
    );
}
