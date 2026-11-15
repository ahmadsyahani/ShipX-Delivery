import { useEffect, useRef, useState } from "react";
import axios from "axios";
import * as L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Section } from "@/components/admin";
import { Button } from "@/components/ui/button";
import { dateTime } from "@/lib/format";
import type { Trip } from "./types";
import type { Schedule } from "./DeparturePanel";

export type RoadPreview = {
    shapes: string[];
    baseline_shapes?: string[];
    baseline_distance_m?: number;
    baseline_duration_seconds?: number;
    points: { latitude: number; longitude: number; label: string }[];
    distance_m: number;
    duration_seconds: number;
    leg_seconds: number[];
    source_reference: string;
    road_source: {
        provider: string;
        travel_mode: string;
        calculated_at: string;
    };
    schedule: Schedule | null;
    schedule_warning: string | null;
};

function decodeShape(encoded: string): L.LatLngTuple[] {
    let index = 0,
        latitude = 0,
        longitude = 0;
    function component() {
        let result = 0,
            shift = 0;
        while (true) {
            if (index >= encoded.length || shift > 30)
                throw new Error("Bentuk rute tidak valid.");
            const value = encoded.charCodeAt(index++) - 63;
            if (value < 0 || value > 63)
                throw new Error("Bentuk rute tidak valid.");
            result |= (value & 31) << shift;
            shift += 5;
            if (value < 32) break;
        }
        return result & 1 ? ~(result >>> 1) : result >>> 1;
    }
    const points: L.LatLngTuple[] = [];
    while (index < encoded.length) {
        latitude += component();
        longitude += component();
        if (
            Math.abs(latitude) > 90000000 ||
            Math.abs(longitude) > 180000000 ||
            points.length > 100000
        )
            throw new Error("Bentuk rute tidak valid.");
        points.push([latitude / 1e6, longitude / 1e6]);
    }
    return points;
}

function RoadMap({ data }: { data: RoadPreview }) {
    const element = useRef<HTMLDivElement>(null);
    useEffect(() => {
        if (!element.current) return;
        const map = L.map(element.current, { scrollWheelZoom: false });
        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution:
                '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
            maxZoom: 19,
        }).addTo(map);
        const bounds: L.LatLngTuple[] = [];
        for (const shape of data.baseline_shapes ?? []) {
            const points = decodeShape(shape);
            L.polyline(points, {
                color: "#64748b",
                weight: 4,
                dashArray: "6 7",
            }).addTo(map);
        }
        for (const shape of data.shapes) {
            const points = decodeShape(shape);
            bounds.push(...points);
            L.polyline(points, { color: "#006241", weight: 5 }).addTo(map);
        }
        data.points.slice(0, -1).forEach((point, index) => {
            const position: L.LatLngTuple = [point.latitude, point.longitude];
            bounds.push(position);
            const popup = document.createElement("span");
            popup.textContent = point.label;
            L.circleMarker(position, {
                radius: 12,
                color: "white",
                weight: 3,
                fillColor: "#006241",
                fillOpacity: 1,
            })
                .bindTooltip(index === 0 ? "D" : String(index), {
                    permanent: true,
                    direction: "center",
                    className: "shipx-route-number",
                })
                .bindPopup(popup)
                .addTo(map);
        });
        if (bounds.length)
            map.fitBounds(L.latLngBounds(bounds), {
                padding: [28, 28],
                maxZoom: 17,
            });
        const resize = new ResizeObserver(() => map.invalidateSize());
        resize.observe(element.current);
        return () => {
            resize.disconnect();
            map.remove();
        };
    }, [data]);
    return (
        <div
            ref={element}
            className="relative z-0 h-80 w-full overflow-hidden rounded-xl border sm:h-96"
            aria-label="Peta rencana trip"
        />
    );
}

export default function RoadPreviewPanel({
    trip,
    onLoaded,
}: {
    trip: Trip;
    onLoaded: (data: RoadPreview) => void;
}) {
    const [data, setData] = useState<RoadPreview | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [busy, setBusy] = useState(false);
    const request = useRef<AbortController | null>(null);
    useEffect(() => () => request.current?.abort(), []);
    async function calculate() {
        setBusy(true);
        setError(null);
        const controller = new AbortController();
        request.current = controller;
        try {
            const result = await axios.post(
                `/admin/trips/${trip.id}/route-preview`,
                { lock_version: trip.lock_version },
                { signal: controller.signal },
            );
            if (controller.signal.aborted) return;
            setData(result.data.data);
            onLoaded(result.data.data);
        } catch (caught) {
            if (axios.isCancel(caught)) return;
            setError(
                axios.isAxiosError(caught)
                    ? (caught.response?.data.message ??
                          "Peta rute belum dapat dimuat.")
                    : "Peta rute belum dapat dimuat.",
            );
        } finally {
            setBusy(false);
        }
    }
    return (
        <Section
            title="Peta rencana perjalanan"
            description="Depot, urutan tujuan dan perjalanan kembali berdasarkan jalan yang dapat dilalui kendaraan."
        >
            <div className="space-y-4">
                <Button type="button" disabled={busy} onClick={calculate}>
                    {busy ? "Menghitung jalan…" : "Hitung peta rute"}
                </Button>
                {error && (
                    <p role="alert" className="text-sm text-destructive">
                        {error}
                    </p>
                )}
                {data && (
                    <>
                        <div className="grid gap-3 text-sm sm:grid-cols-2">
                            <p className="font-semibold">
                                Rute dipilih{" "}
                                {(data.distance_m / 1000).toLocaleString(
                                    "id-ID",
                                    { maximumFractionDigits: 2 },
                                )}{" "}
                                km · {Math.ceil(data.duration_seconds / 60)}{" "}
                                menit perjalanan
                            </p>
                            <p className="text-muted-foreground">
                                Valhalla ·{" "}
                                {data.road_source.travel_mode === "motorcycle"
                                    ? "Motor"
                                    : "Mobil"}{" "}
                                ·{" "}
                                {dateTime(
                                    data.road_source.calculated_at,
                                    trip.timezone_snapshot,
                                )}
                            </p>
                            {data.baseline_distance_m != null && (
                                <p className="text-muted-foreground">
                                    Urutan awal{" "}
                                    {(
                                        data.baseline_distance_m / 1000
                                    ).toLocaleString("id-ID", {
                                        maximumFractionDigits: 2,
                                    })}{" "}
                                    km ·{" "}
                                    {Math.ceil(
                                        (data.baseline_duration_seconds ?? 0) /
                                            60,
                                    )}{" "}
                                    menit
                                </p>
                            )}
                        </div>
                        <RoadMap data={data} />
                        {data.baseline_shapes?.length ? (
                            <p className="text-xs text-muted-foreground">
                                Garis hijau menunjukkan rute dipilih. Garis
                                abu-abu putus-putus menunjukkan urutan awal.
                            </p>
                        ) : null}
                        {data.schedule_warning && (
                            <p
                                role="alert"
                                className="text-sm text-destructive"
                            >
                                {data.schedule_warning}
                            </p>
                        )}
                        {data.schedule && (
                            <div className="space-y-2 text-sm">
                                {data.schedule.stops.map((stop, index) => (
                                    <p key={stop.order_id}>
                                        Tujuan {index + 1} · estimasi tiba{" "}
                                        {dateTime(
                                            stop.estimated_arrival_at,
                                            trip.timezone_snapshot,
                                        )}
                                    </p>
                                ))}
                            </div>
                        )}
                    </>
                )}
            </div>
        </Section>
    );
}
