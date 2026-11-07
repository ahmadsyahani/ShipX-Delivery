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
import type { Vehicle, Paginated } from "@/types";

export default function Vehicles({
    vehicles,
    filters,
}: {
    vehicles: Paginated<Vehicle>;
    filters: MasterFilterValues;
}) {
    return (
        <>
            <Head title="Kendaraan" />
            <PageHeading
                title="Kendaraan"
                description="Catat kapasitas aman setiap kendaraan sebelum menyiapkan pengiriman."
                action={
                    <Button asChild>
                        <Link href="/admin/vehicles/create">
                            <Plus />
                            Tambah kendaraan
                        </Link>
                    </Button>
                }
            />
            <Card className="gap-0 overflow-hidden py-0 shadow-none">
                <MasterFilters
                    path="/admin/vehicles"
                    filters={filters}
                    label="kendaraan"
                />
                {vehicles.data.length ? (
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="pl-5">
                                    Kendaraan
                                </TableHead>
                                <TableHead>Pelat / jenis</TableHead>
                                <TableHead className="text-right">
                                    Beban
                                </TableHead>
                                <TableHead className="text-right">
                                    Ruang barang
                                </TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead className="pr-5 text-right">
                                    Aksi
                                </TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {vehicles.data.map((vehicle) => (
                                <TableRow key={vehicle.id}>
                                    <TableCell className="max-w-xs whitespace-normal py-4 pl-5">
                                        <p className="font-medium">
                                            {vehicle.name}
                                        </p>
                                        <p className="mt-1 text-xs text-muted-foreground">
                                            {vehicle.code}
                                        </p>
                                    </TableCell>
                                    <TableCell>
                                        <p>{vehicle.plate_number}</p>
                                        <p className="mt-1 text-xs text-muted-foreground">
                                            {vehicle.travel_mode ===
                                            "motorcycle"
                                                ? "Sepeda motor"
                                                : "Mobil"}
                                        </p>
                                    </TableCell>
                                    <TableCell className="text-right tabular-nums">
                                        Terukur
                                    </TableCell>
                                    <TableCell className="text-right tabular-nums">
                                        Terukur�
                                    </TableCell>
                                    <TableCell>
                                        <StatusBadge
                                            status={vehicle.is_active}
                                        />
                                    </TableCell>
                                    <TableCell className="pr-5 text-right">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            asChild
                                        >
                                            <Link
                                                href={`/admin/vehicles/${vehicle.id}/edit`}
                                                aria-label={`Edit ${vehicle.name}`}
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
                        title="Belum ada kendaraan"
                        description={
                            filters.q || filters.status
                                ? "Tidak ada kendaraan yang sesuai filter. Coba pencarian lain."
                                : "Tambahkan kendaraan dengan kapasitas muatan yang sudah diperiksa."
                        }
                        action={
                            !filters.q &&
                            !filters.status && (
                                <Button variant="outline" asChild>
                                    <Link href="/admin/vehicles/create">
                                        <Plus />
                                        Tambah kendaraan
                                    </Link>
                                </Button>
                            )
                        }
                    />
                )}
                <Pager page={vehicles} />
            </Card>
            <p className="max-w-3xl text-xs leading-6 text-muted-foreground">
                Kapasitas adalah batas muatan aman untuk barang. Perhitungan
                belum menjamin susunan barang muat secara fisik. Admin tetap
                memeriksa bentuk dan penanganan barang.
            </p>
        </>
    );
}
