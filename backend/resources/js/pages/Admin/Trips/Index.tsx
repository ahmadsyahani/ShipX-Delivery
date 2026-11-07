import { Head, Link, router } from "@inertiajs/react";
import { Plus } from "lucide-react";
import { PageHeading, EmptyState, Pager, Section } from "@/components/admin";
import { Button } from "@/components/ui/button";
import { NativeSelect } from "@/components/ui/native-select";
import { dateTime } from "@/lib/format";
import type { Paginated } from "@/types";
import { type Trip, tripStatus } from "./types";

export default function Trips({
    trips,
    filters,
}: {
    trips: Paginated<Trip>;
    filters: { status: string };
}) {
    return (
        <>
            <Head title="Trip pengiriman" />
            <PageHeading
                title="Trip pengiriman"
                description="Susun tujuan, pilih armada, dan tetapkan penugasan dari depot."
                action={
                    <Button asChild>
                        <Link href="/admin/trips/create">
                            <Plus />
                            Buat trip
                        </Link>
                    </Button>
                }
            />
            <label className="flex items-center gap-3 text-sm">
                Status trip
                <NativeSelect
                    className="w-48"
                    value={filters.status}
                    onChange={(e) =>
                        router.get("/admin/trips", { status: e.target.value })
                    }
                >
                    <option value="">Semua status</option>
                    {Object.entries(tripStatus).map(([k, v]) => (
                        <option key={k} value={k}>
                            {v}
                        </option>
                    ))}
                </NativeSelect>
            </label>
            <Section title="Rencana penugasan">
                <div className="divide-y">
                    {trips.data.map((t) => (
                        <Link
                            key={t.id}
                            href={`/admin/trips/${t.id}`}
                            className="flex flex-wrap items-center justify-between gap-3 py-5 text-sm hover:text-primary"
                        >
                            <div className="min-w-0">
                                <p className="break-all font-semibold">
                                    {t.trip_number}
                                </p>
                                <p className="mt-2 text-muted-foreground">
                                    {
                                        t.selected_route.input_snapshot.courier
                                            .name
                                    }{" "}
                                    ·{" "}
                                    {
                                        t.selected_route.input_snapshot.vehicle
                                            .plate_number
                                    }
                                </p>
                                <p className="mt-1 text-muted-foreground">
                                    {dateTime(
                                        t.planned_departure_at,
                                        t.timezone_snapshot,
                                    )}
                                </p>
                            </div>
                            <span className="rounded-full border px-3 py-1">
                                {tripStatus[t.status]}
                            </span>
                        </Link>
                    ))}
                </div>
                {!trips.data.length && (
                    <EmptyState
                        title="Belum ada trip"
                        description="Konfirmasikan pesanan, lalu buat rencana penugasan manual."
                    />
                )}
                <Pager page={trips} />
            </Section>
        </>
    );
}
