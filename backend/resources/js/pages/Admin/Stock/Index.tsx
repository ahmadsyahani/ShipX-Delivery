import { useEffect, useState } from "react";
import { Head, Link, router } from "@inertiajs/react";
import { ArrowUpRight, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
import type { Paginated, Product } from "@/types";

export default function Stock({
    products,
    filters,
}: {
    products: Paginated<Product>;
    filters: { q: string };
}) {
    const [q, setQ] = useState(filters.q);
    useEffect(() => setQ(filters.q), [filters.q]);
    return (
        <>
            <Head title="Stok" />
            <PageHeading
                title="Stok depot"
                description="Saldo per produk. Stok yang direservasi tidak dapat dijual kembali."
            />
            <Card className="gap-0 overflow-hidden py-0 shadow-none">
                <form
                    className="flex flex-wrap gap-3 border-b p-4"
                    onSubmit={(e) => {
                        e.preventDefault();
                        router.get(
                            "/admin/stock",
                            { q },
                            { preserveState: true, replace: true },
                        );
                    }}
                >
                    <div className="relative min-w-48 flex-1 sm:max-w-sm">
                        <Search className="absolute left-3 top-2.5 size-4 text-muted-foreground" />
                        <Input
                            aria-label="Cari stok produk"
                            maxLength={100}
                            placeholder="Cari nama atau SKU…"
                            className="pl-9"
                            value={q}
                            onChange={(e) => setQ(e.target.value)}
                        />
                    </div>
                    <Button variant="outline">Cari</Button>
                    {filters.q && (
                        <Button variant="ghost" asChild>
                            <Link href="/admin/stock">Reset</Link>
                        </Button>
                    )}
                </form>
                {products.data.length ? (
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="pl-5">Produk</TableHead>
                                <TableHead className="text-right">
                                    Fisik tersedia
                                </TableHead>
                                <TableHead className="text-right">
                                    Reservasi
                                </TableHead>
                                <TableHead className="text-right">
                                    Siap dipesan
                                </TableHead>
                                <TableHead className="text-right">
                                    Karantina
                                </TableHead>
                                <TableHead className="pr-5 text-right">
                                    Aksi
                                </TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {products.data.map((product) => (
                                <TableRow key={product.id}>
                                    <TableCell className="max-w-xs whitespace-normal py-4 pl-5">
                                        <p className="font-medium">
                                            {product.name}
                                        </p>
                                        <p className="mb-2 mt-1 text-xs text-muted-foreground">
                                            {product.sku} · item
                                        </p>
                                        <StatusBadge
                                            status={product.is_active}
                                        />
                                    </TableCell>
                                    <TableCell className="text-right tabular-nums">
                                        {Number(product.physical_quantity ?? 0)}
                                    </TableCell>
                                    <TableCell className="text-right tabular-nums text-muted-foreground">
                                        {Number(product.reserved_quantity ?? 0)}
                                    </TableCell>
                                    <TableCell className="text-right font-semibold tabular-nums text-primary">
                                        {Math.max(
                                            0,
                                            Number(product.physical_quantity) -
                                                Number(
                                                    product.reserved_quantity,
                                                ),
                                        )}
                                    </TableCell>
                                    <TableCell className="text-right tabular-nums text-muted-foreground">
                                        {Number(
                                            product.quarantine_quantity ?? 0,
                                        )}
                                    </TableCell>
                                    <TableCell className="pr-5 text-right">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            asChild
                                        >
                                            <Link
                                                href={`/admin/stock/${product.id}`}
                                            >
                                                Catat mutasi
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
                        title="Tidak ada produk"
                        description={
                            filters.q
                                ? "Coba kata kunci lain untuk menemukan stok produk."
                                : "Tambahkan produk terlebih dahulu, lalu catat stok fisik sebenarnya."
                        }
                        action={
                            !filters.q && (
                                <Button variant="outline" asChild>
                                    <Link href="/admin/products/create">
                                        Tambah produk
                                    </Link>
                                </Button>
                            )
                        }
                    />
                )}
                <Pager page={products} />
            </Card>
            <p className="max-w-3xl text-xs leading-6 text-muted-foreground">
                Fisik tersedia adalah barang layak jual di depot. Reservasi
                menahan barang untuk pesanan. Karantina dicatat terpisah dan
                tidak masuk jumlah siap dipesan.
            </p>
        </>
    );
}
