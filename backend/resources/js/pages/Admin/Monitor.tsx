import { useEffect, useRef, useState } from "react";
import { Head, Link } from "@inertiajs/react";
import axios from "axios";
import * as L from "leaflet";
import "leaflet/dist/leaflet.css";
import {
    PageHeading,
    Section,
    EmptyState,
    StatusBadge,
} from "@/components/admin";
import { Button } from "@/components/ui/button";

type Location = { latitude: number; longitude: number; recorded_at: string };
type Trip = {
    id: string;
    trip_number: string;
    status: string;
    courier_name: string;
    courier_active: boolean;
    plate_number: string;
    total_stops: number;
    finished_stops: number;
    tracking_status: string;
    location: Location | null;
    next_stop: {
        recipient_name: string;
        address_text: string;
        sequence_no: number;
    } | null;
};
type Depot = {
    name: string;
    latitude: number | null;
    longitude: number | null;
};

function MonitorMap({
    depot,
    trips,
    offline,
}: {
    depot: Depot;
    trips: Trip[];
    offline: boolean;
}) {
    const element = useRef<HTMLDivElement>(null);
    const map = useRef<L.Map | null>(null);
    const layer = useRef<L.LayerGroup | null>(null);
    const fitted = useRef(false);
    useEffect(() => {
        if (!element.current) return;
        const instance = L.map(element.current, { scrollWheelZoom: false });
        map.current = instance;
        layer.current = L.layerGroup().addTo(instance);
        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution:
                '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
            maxZoom: 19,
        }).addTo(instance);
        const resize = new ResizeObserver(() => instance.invalidateSize());
        resize.observe(element.current);
        return () => {
            resize.disconnect();
            instance.remove();
            map.current = null;
        };
    }, []);
    useEffect(() => {
        if (!map.current || !layer.current) return;
        layer.current.clearLayers();
        const points: L.LatLngTuple[] = [];
        function marker(point: L.LatLngTuple, label: string, color: string) {
            points.push(point);
            const text = document.createElement("span");
            text.textContent = label;
            L.circleMarker(point, {
                radius: 10,
                color: "white",
                weight: 3,
                fillColor: color,
                fillOpacity: 1,
            })
                .bindPopup(text)
                .addTo(layer.current!);
        }
        if (depot.latitude != null && depot.longitude != null)
            marker(
                [Number(depot.latitude), Number(depot.longitude)],
                depot.name,
                "#182e40",
            );
        trips.forEach((trip) => {
            if (trip.location)
                marker(
                    [trip.location.latitude, trip.location.longitude],
                    `${trip.courier_name} · ${trip.plate_number}`,
                    !offline && trip.tracking_status === "live"
                        ? "#006241"
                        : "#64748b",
                );
        });
        if (!fitted.current && points.length) {
            map.current.fitBounds(L.latLngBounds(points), {
                padding: [35, 35],
                maxZoom: 16,
            });
            fitted.current = true;
        }
    }, [depot, trips, offline]);
    return (
        <div
            ref={element}
            aria-label="Peta monitor kurir"
            className="relative z-0 h-[420px] overflow-hidden rounded-xl sm:h-[520px]"
        />
    );
}

export default function Monitor({ depot }: { depot: Depot }) {
    const [trips, setTrips] = useState<Trip[]>([]);
    const [error, setError] = useState<string | null>(null);
    const [busy, setBusy] = useState(false);
    const request = useRef<AbortController | null>(null);
    const loading = useRef(false);
    async function refresh() {
        if (loading.current) return;
        loading.current = true;
        const controller = new AbortController();
        request.current = controller;
        setBusy(true);
        try {
            const response = await axios.get("/admin/monitor/positions", {
                signal: controller.signal,
                headers: { Accept: "application/json" },
            });
            if (!controller.signal.aborted) {
                setTrips(response.data.data);
                setError(null);
            }
        } catch (caught) {
            if (!controller.signal.aborted) {
                if (
                    axios.isAxiosError(caught) &&
                    [401, 403].includes(caught.response?.status ?? 0)
                )
                    setTrips([]);
                setError(
                    "Monitor belum dapat diperbarui. Periksa koneksi dan akses admin.",
                );
            }
        } finally {
            loading.current = false;
            if (!controller.signal.aborted) setBusy(false);
        }
    }
    useEffect(() => {
        void refresh();
        const timer = window.setInterval(() => {
            if (!document.hidden) void refresh();
        }, 10000);
        const resume = () => {
            if (!document.hidden) void refresh();
        };
        document.addEventListener("visibilitychange", resume);
        return () => {
            window.clearInterval(timer);
            document.removeEventListener("visibilitychange", resume);
            request.current?.abort();
        };
    }, []);
    const hasMap =
        (depot.latitude != null && depot.longitude != null) ||
        trips.some((trip) => trip.location);
    return (
        <>
            <Head title="Monitor kurir" />
            <PageHeading
                title="Monitor kurir"
                description="Posisi pengiriman dan progres trip aktif, diperbarui setiap 10 detik."
                action={
                    <Button variant="outline" disabled={busy} onClick={refresh}>
                        {busy ? "Memperbarui…" : "Perbarui monitor"}
                    </Button>
                }
            />
            {error && (
                <p
                    role="alert"
                    className="mb-5 rounded-xl bg-destructive/5 p-4 text-sm text-destructive"
                >
                    {error} Posisi yang tersimpan ditandai sebagai lokasi
                    terakhir.
                </p>
            )}
            <div className="mb-5 flex flex-wrap gap-3 text-sm">
                <span>{trips.length} trip aktif</span>
                <span>
                    {error
                        ? 0
                        : trips.filter(
                              (trip) => trip.tracking_status === "live",
                          ).length}{" "}
                    lokasi terkini
                </span>
            </div>
            <Section
                title="Peta operasional"
                description="Penanda hijau menunjukkan posisi terkini. Abu-abu menunjukkan lokasi terakhir."
            >
                {hasMap ? (
                    <MonitorMap depot={depot} trips={trips} offline={!!error} />
                ) : (
                    <EmptyState
                        title="Posisi belum tersedia"
                        description="Atur lokasi depot atau tunggu kurir memulai navigasi."
                    />
                )}
            </Section>
            <div className="mt-5 grid gap-4 lg:grid-cols-2">
                {!busy && trips.length === 0 && (
                    <EmptyState
                        title="Belum ada trip aktif"
                        description="Trip yang ditetapkan admin akan muncul di sini."
                    />
                )}
                {trips.map((trip) => (
                    <Section
                        key={trip.id}
                        title={trip.courier_name}
                        description={`${trip.plate_number} · ${trip.trip_number}`}
                    >
                        <div className="space-y-3 text-sm">
                            <StatusBadge status={trip.status} />
                            {!trip.courier_active && (
                                <p className="text-destructive">
                                    Akses kurir dinonaktifkan. Tinjau penugasan.
                                </p>
                            )}
                            <p>
                                {trip.finished_stops} dari {trip.total_stops}{" "}
                                tujuan ditangani
                            </p>
                            <p
                                className={
                                    !error && trip.tracking_status === "live"
                                        ? "text-primary"
                                        : "text-muted-foreground"
                                }
                            >
                                {trip.location
                                    ? `${!error && trip.tracking_status === "live" ? "Lokasi terkini" : "Lokasi terakhir"} · ${new Date(trip.location.recorded_at).toLocaleTimeString("id-ID", { hour: "2-digit", minute: "2-digit" })}`
                                    : trip.status === "awaiting_reconciliation"
                                      ? "Menunggu barang kembali dan setoran"
                                      : "Menunggu lokasi navigasi"}
                            </p>
                            {trip.next_stop && (
                                <p>
                                    Tujuan {trip.next_stop.sequence_no} ·{" "}
                                    {trip.next_stop.recipient_name}
                                    <br />
                                    <span className="text-muted-foreground">
                                        {trip.next_stop.address_text}
                                    </span>
                                </p>
                            )}
                            <Button variant="outline" asChild>
                                <Link href={`/admin/trips/${trip.id}`}>
                                    Lihat trip
                                </Link>
                            </Button>
                        </div>
                    </Section>
                ))}
            </div>
        </>
    );
}
