import { useEffect, useState } from "react";
import { Head, Link, router } from "@inertiajs/react";
import { Plus } from "lucide-react";
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
import { dateTime, time } from "@/lib/format";
import type { Depot, Paginated, Slot } from "@/types";

export default function Slots({
    slots,
    depot,
    filters,
    serverNow,
}: {
    slots: Paginated<Slot>;
    depot: Depot;
    filters: { date: string };
    serverNow: string;
}) {
    const [date, setDate] = useState(filters.date);
    useEffect(() => setDate(filters.date), [filters.date]);
    return (
        <>
            <Head title="Slot pengiriman" />
            <PageHeading
                title="Slot pengiriman"
                description={`Atur gelombang pengantaran. Semua waktu mengikuti ${depot.timezone}.`}
                action={
                    <Button asChild>
                        <Link href="/admin/slots/create">
                            <Plus />
                            Tambah slot
                        </Link>
                    </Button>
                }
            />
            <Card className="gap-0 overflow-hidden py-0 shadow-none">
                <form
                    className="flex flex-wrap items-center gap-3 border-b p-4"
                    onSubmit={(e) => {
                        e.preventDefault();
                        router.get(
                            "/admin/slots",
                            { date },
                            { preserveState: true, replace: true },
                        );
                    }}
                >
                    <label htmlFor="date" className="text-sm font-medium">
                        Tanggal pengiriman
                    </label>
                    <Input
                        id="date"
                        type="date"
                        className="w-auto"
                        value={date}
                        onChange={(e) => setDate(e.target.value)}
                    />
                    <Button variant="outline">Terapkan</Button>
                    {filters.date && (
                        <Button variant="ghost" asChild>
                            <Link href="/admin/slots">Semua tanggal</Link>
                        </Button>
                    )}
                </form>
                {slots.data.length ? (
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="pl-5">
                                    Tanggal layanan
                                </TableHead>
                                <TableHead>Jam pengiriman</TableHead>
                                <TableHead>Batas pemesanan</TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead className="pr-5 text-right">
                                    Aksi
                                </TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {slots.data.map((slot) => (
                                <TableRow key={slot.id}>
                                    <TableCell className="py-4 pl-5 font-medium">
                                        {new Intl.DateTimeFormat("id-ID", {
                                            dateStyle: "medium",
                                            timeZone: depot.timezone,
                                        }).format(
                                            new Date(slot.window_start_at),
                                        )}
                                    </TableCell>
                                    <TableCell className="tabular-nums">
                                        {time(
                                            slot.window_start_at,
                                            depot.timezone,
                                        )}
                                        –
                                        {time(
                                            slot.window_end_at,
                                            depot.timezone,
                                        )}
                                    </TableCell>
                                    <TableCell className="text-xs text-muted-foreground">
                                        {dateTime(
                                            slot.cutoff_at,
                                            depot.timezone,
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        <StatusBadge
                                            status={
                                                !slot.is_active
                                                    ? "inactive"
                                                    : new Date(
                                                            slot.cutoff_at,
                                                        ) <= new Date(serverNow)
                                                      ? "closed"
                                                      : "open"
                                            }
                                        />
                                    </TableCell>
                                    <TableCell className="pr-5 text-right">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            asChild
                                        >
                                            <Link
                                                href={`/admin/slots/${slot.id}/edit`}
                                            >
                                                Edit
                                                <span className="sr-only">
                                                    {" "}
                                                    slot {slot.id}
                                                </span>
                                            </Link>
                                        </Button>
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                ) : (
                    <EmptyState
                        title="Belum ada slot pengiriman"
                        description={
                            filters.date
                                ? "Tidak ada jadwal pada tanggal ini. Pilih tanggal lain atau tambahkan slot."
                                : "Buat jadwal dengan batas pemesanan yang jelas agar pelanggan dapat memilih waktu pengiriman."
                        }
                        action={
                            <Button variant="outline" asChild>
                                <Link href="/admin/slots/create">
                                    <Plus />
                                    Tambah slot
                                </Link>
                            </Button>
                        }
                    />
                )}
                <Pager page={slots} />
            </Card>
        </>
    );
}
