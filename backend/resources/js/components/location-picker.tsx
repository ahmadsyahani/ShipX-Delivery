import { useEffect, useRef, useState } from "react";
import * as L from "leaflet";
import "leaflet/dist/leaflet.css";
import { LocateFixed, MapPin } from "lucide-react";
import { Button } from "@/components/ui/button";

type Props = {
    latitude: number | string;
    longitude: number | string;
    radius: number;
    disabled?: boolean;
    onChange: (latitude: number, longitude: number) => void;
};

export function LocationPicker(props: Props) {
    const element = useRef<HTMLDivElement>(null);
    const map = useRef<L.Map | null>(null);
    const marker = useRef<L.CircleMarker | null>(null);
    const area = useRef<L.Circle | null>(null);
    const current = useRef(props);
    current.current = props;
    const request = useRef(0);
    const [locating, setLocating] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const valid =
        props.latitude !== "" &&
        props.longitude !== "" &&
        Number.isFinite(Number(props.latitude)) &&
        Number.isFinite(Number(props.longitude)) &&
        Math.abs(Number(props.latitude)) <= 90 &&
        Math.abs(Number(props.longitude)) <= 180;

    useEffect(() => {
        if (!element.current) return;
        const lat = current.current.latitude,
            lng = current.current.longitude;
        const hasPoint =
            lat !== "" &&
            lng !== "" &&
            Number.isFinite(Number(lat)) &&
            Number.isFinite(Number(lng));
        const view = L.map(element.current, {
            center: hasPoint ? [Number(lat), Number(lng)] : [-2.5, 118],
            zoom: hasPoint ? 14 : 4,
            scrollWheelZoom: false,
        });
        map.current = view;
        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution:
                '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            maxZoom: 19,
        }).addTo(view);
        view.on("click", (event: L.LeafletMouseEvent) => {
            if (current.current.disabled) return;
            request.current++;
            setLocating(false);
            setError(null);
            current.current.onChange(
                Number(event.latlng.lat.toFixed(7)),
                Number(event.latlng.lng.toFixed(7)),
            );
        });
        return () => {
            request.current++;
            view.remove();
            map.current = null;
            marker.current = null;
            area.current = null;
        };
    }, []);

    useEffect(() => {
        const view = map.current;
        if (!view || !valid) return;
        const point: L.LatLngTuple = [
            Number(props.latitude),
            Number(props.longitude),
        ];
        if (!marker.current)
            marker.current = L.circleMarker(point, {
                radius: 9,
                color: "#ffffff",
                weight: 3,
                fillColor: "#087e8b",
                fillOpacity: 1,
            }).addTo(view);
        else marker.current.setLatLng(point);
        const radius =
            Number.isFinite(props.radius) && props.radius > 0
                ? props.radius
                : 0;
        if (!area.current)
            area.current = L.circle(point, {
                radius,
                color: "#087e8b",
                weight: 1,
                fillOpacity: 0.08,
            }).addTo(view);
        else area.current.setLatLng(point).setRadius(radius);
        view.panTo(point, { animate: false });
    }, [props.latitude, props.longitude, props.radius, valid]);

    useEffect(() => {
        if (props.disabled) {
            request.current++;
            setLocating(false);
        }
    }, [props.disabled]);

    function locate() {
        if (!navigator.geolocation) {
            setError("Lokasi perangkat tidak tersedia. Pilih titik di peta.");
            return;
        }
        const id = ++request.current;
        setLocating(true);
        setError(null);
        navigator.geolocation.getCurrentPosition(
            (position) => {
                if (id !== request.current || current.current.disabled) return;
                setLocating(false);
                const { latitude, longitude } = position.coords;
                if (
                    !Number.isFinite(latitude) ||
                    !Number.isFinite(longitude) ||
                    Math.abs(latitude) > 90 ||
                    Math.abs(longitude) > 180
                ) {
                    setError("Lokasi belum dapat dibaca. Pilih titik di peta.");
                    return;
                }
                current.current.onChange(
                    Number(position.coords.latitude.toFixed(7)),
                    Number(position.coords.longitude.toFixed(7)),
                );
                map.current?.setView(
                    [position.coords.latitude, position.coords.longitude],
                    16,
                );
            },
            () => {
                if (id !== request.current) return;
                setLocating(false);
                setError(
                    "Lokasi belum dapat dibaca. Periksa izin lokasi atau pilih titik di peta.",
                );
            },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 },
        );
    }

    return (
        <div className="space-y-3">
            <div className="flex flex-wrap gap-2">
                <Button
                    type="button"
                    variant="outline"
                    disabled={props.disabled || locating}
                    onClick={locate}
                >
                    <LocateFixed />
                    {locating ? "Mencari lokasi…" : "Gunakan lokasi perangkat"}
                </Button>
                <Button
                    type="button"
                    variant="ghost"
                    disabled={props.disabled}
                    onClick={() => {
                        const point = map.current?.getCenter();
                        if (point) {
                            request.current++;
                            setLocating(false);
                            setError(null);
                            props.onChange(
                                Number(point.lat.toFixed(7)),
                                Number(point.lng.toFixed(7)),
                            );
                        }
                    }}
                >
                    <MapPin />
                    Gunakan titik tengah peta
                </Button>
            </div>
            <div
                ref={element}
                className="isolate z-0 h-80 w-full rounded-xl border"
                aria-label="Peta lokasi depot"
            />
            <p
                className="text-xs leading-6 text-muted-foreground"
                role="status"
            >
                {valid
                    ? "Titik depot sudah dipilih. Pastikan pin sesuai alamat depot."
                    : "Pilih lokasi perangkat atau klik peta untuk menaruh pin depot."}
            </p>
            {error && (
                <p role="alert" className="text-sm text-destructive">
                    {error}
                </p>
            )}
        </div>
    );
}
