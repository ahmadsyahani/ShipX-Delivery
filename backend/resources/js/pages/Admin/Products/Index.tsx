import { useEffect, useState } from "react";
import { Head, Link, router } from "@inertiajs/react";
import { ArrowUpRight, Plus, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
    PageHeading,
    EmptyState,
    Pager,
    StatusBadge,
} from "@/components/admin";
import { money } from "@/lib/format";
import type { Paginated, Product } from "@/types";

export default function Products({
    products,
    filters,
    total,
    active,
}: {
    products: Paginated<Product>;
    filters: { q: string; status: string };
    total: number;
    active: number;
}) {
    const [q, setQ] = useState(filters.q);
    const [status, setStatus] = useState(filters.status);
    useEffect(() => {
        setQ(filters.q);
        setStatus(filters.status);
    }, [filters.q, filters.status]);
    return (
        <>
            <Head title="Produk" />
            <PageHeading
                title="Produk"
                description="Katalog yang rapi untuk setiap kebutuhan pelanggan."
                action={
                    <Button asChild>
                        <Link href="/admin/products/create">
                            <Plus />
                            Tambah produk
                        </Link>
                    </Button>
                }
            />
            <div className="flex flex-wrap items-center gap-5 text-sm">
                <span>
                    <strong className="font-semibold">{total}</strong>{" "}
                    <span className="text-muted-foreground">
                        produk tersimpan
                    </span>
                </span>
                <span className="h-4 border-l" />
                <span>
                    <strong className="font-semibold text-primary">
                        {active}
                    </strong>{" "}
                    <span className="text-muted-foreground">
                        aktif di katalog
                    </span>
                </span>
            </div>
            <Card className="gap-0 overflow-hidden py-0 shadow-none">
                <form
                    className="flex flex-wrap items-center gap-3 border-b p-4"
                    onSubmit={(e) => {
                        e.preventDefault();
                        router.get(
                            "/admin/products",
                            { q, status },
                            { preserveState: true, replace: true },
                        );
                    }}
                >
                    <div className="relative min-w-48 flex-1 sm:max-w-sm">
                        <Search className="absolute left-3 top-2.5 size-4 text-muted-foreground" />
                        <Input
                            aria-label="Cari produk"
                            className="pl-9"
                            maxLength={100}
                            placeholder="Cari nama atau SKU…"
                            value={q}
                            onChange={(e) => setQ(e.target.value)}
                        />
                    </div>
                    <NativeSelect
                        aria-label="Status produk"
                        value={status}
                        onChange={(e) => setStatus(e.target.value)}
                    >
                        <NativeSelectOption value="">
                            Semua status
                        </NativeSelectOption>
                        <NativeSelectOption value="active">
                            Aktif
                        </NativeSelectOption>
                        <NativeSelectOption value="inactive">
                            Nonaktif
                        </NativeSelectOption>
                    </NativeSelect>
                    <Button variant="outline" type="submit">
                        Terapkan
                    </Button>
                    {(filters.q || filters.status) && (
                        <Button variant="ghost" asChild>
                            <Link href="/admin/products">Reset</Link>
                        </Button>
                    )}
                </form>
                {products.data.length ? (
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="pl-5">Produk</TableHead>
                                <TableHead>Harga / satuan</TableHead>
                                <TableHead>Kemasan</TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead className="pr-5 text-right">
                                    Aksi
                                </TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {products.data.map((product) => (
                                <TableRow key={product.id}>
                                    <TableCell className="max-w-xs whitespace-normal py-4 pl-5">
                                        <Link
                                            href={`/admin/products/${product.id}/edit`}
                                            className="font-medium hover:text-primary"
                                        >
                                            {product.name}
                                        </Link>
                                        <p className="mt-1 text-xs text-muted-foreground">
                                            {product.sku} · {product.category}
                                        </p>
                                    </TableCell>
                                    <TableCell>
                                        <p className="font-medium tabular-nums">
                                            {money(product.unit_price_rp)}
                                        </p>
                                        <p className="mt-1 text-xs text-muted-foreground">
                                            per {product.unit_label}
                                        </p>
                                    </TableCell>
                                    <TableCell className="text-xs leading-5 text-muted-foreground">
                                        {product.shipping_weight_g} g<br />
                                        {product.length_mm} × {product.width_mm}{" "}
                                        × {product.height_mm} mm
                                    </TableCell>
                                    <TableCell>
                                        <StatusBadge
                                            status={product.is_active}
                                        />
                                    </TableCell>
                                    <TableCell className="pr-5 text-right">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            asChild
                                        >
                                            <Link
                                                href={`/admin/products/${product.id}/edit`}
                                                aria-label={`Edit ${product.name}`}
                                            >
                                                Edit
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
                        title={
                            total === 0
                                ? "Siapkan katalog pertama"
                                : "Produk tidak ditemukan"
                        }
                        description={
                            total === 0
                                ? "Tambahkan produk beserta harga, berat, dan ukuran kemasannya untuk mulai menyusun katalog."
                                : "Coba kata kunci lain atau hapus filter untuk melihat produk."
                        }
                        action={
                            total === 0 && (
                                <Button asChild>
                                    <Link href="/admin/products/create">
                                        <Plus />
                                        Tambah produk
                                    </Link>
                                </Button>
                            )
                        }
                    />
                )}
                <Pager page={products} />
            </Card>
        </>
    );
}
