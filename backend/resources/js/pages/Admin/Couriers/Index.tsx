import { Head, Link } from "@inertiajs/react";
import { Plus, ArrowUpRight } from "lucide-react";
import { Button } from "@/components/ui/button";
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
import {
    MasterFilters,
    type MasterFilterValues,
} from "@/components/master-filters";
import type { Courier, Paginated } from "@/types";

export default function Couriers({
    couriers,
    filters,
}: {
    couriers: Paginated<Courier>;
    filters: MasterFilterValues;
}) {
    return (
        <>
            <Head title="Kurir" />
            <PageHeading
                title="Kurir"
                description="Kelola akun dan kontak kurir yang akan menjalankan pengiriman."
                action={
                    <Button asChild>
                        <Link href="/admin/couriers/create">
                            <Plus />
                            Tambah kurir
                        </Link>
                    </Button>
                }
            />
            <Card className="gap-0 overflow-hidden py-0 shadow-none">
                <MasterFilters
                    path="/admin/couriers"
                    filters={filters}
                    label="kurir"
                />
                {couriers.data.length ? (
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="pl-5">
                                    Nama kurir
                                </TableHead>
                                <TableHead>Email</TableHead>
                                <TableHead>Telepon</TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead className="pr-5 text-right">
                                    Aksi
                                </TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {couriers.data.map((courier) => (
                                <TableRow key={courier.id}>
                                    <TableCell className="max-w-xs whitespace-normal py-4 pl-5 font-medium">
                                        {courier.name}
                                    </TableCell>
                                    <TableCell>{courier.email}</TableCell>
                                    <TableCell>
                                        {courier.phone ?? "Belum diisi"}
                                    </TableCell>
                                    <TableCell>
                                        <StatusBadge
                                            status={courier.is_active}
                                        />
                                    </TableCell>
                                    <TableCell className="pr-5 text-right">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            asChild
                                        >
                                            <Link
                                                href={`/admin/couriers/${courier.id}/edit`}
                                                aria-label={`Edit ${courier.name}`}
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
                        title="Belum ada kurir"
                        description={
                            filters.q || filters.status
                                ? "Tidak ada kurir yang sesuai filter. Coba pencarian lain."
                                : "Tambahkan akun kurir agar staf dapat masuk ke aplikasi ShipX."
                        }
                        action={
                            !filters.q &&
                            !filters.status && (
                                <Button variant="outline" asChild>
                                    <Link href="/admin/couriers/create">
                                        <Plus />
                                        Tambah kurir
                                    </Link>
                                </Button>
                            )
                        }
                    />
                )}
                <Pager page={couriers} />
            </Card>
            <p className="max-w-3xl text-xs leading-6 text-muted-foreground">
                Akun kurir dibuat oleh admin. Nonaktifkan akun yang tidak lagi
                digunakan. Penugasan perjalanan tersedia pada tahap trip
                berikutnya.
            </p>
        </>
    );
}
