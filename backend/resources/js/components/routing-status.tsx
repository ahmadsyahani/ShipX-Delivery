import { useEffect, useState } from "react";
import axios from "axios";
import { Section } from "@/components/admin";
import { Button } from "@/components/ui/button";

export default function RoutingStatus() {
    const [status, setStatus] = useState<{
        available: boolean;
        service_area_covered: boolean;
        message?: string;
    } | null>(null);
    const [busy, setBusy] = useState(false);
    async function refresh() {
        setBusy(true);
        try {
            setStatus((await axios.get("/admin/routing/status")).data.data);
        } catch {
            setStatus({
                available: false,
                service_area_covered: false,
                message: "Status routing belum dapat diperiksa.",
            });
        } finally {
            setBusy(false);
        }
    }
    useEffect(() => {
        void refresh();
    }, []);
    return (
        <Section title="Peta dan mesin rute demo">
            <div className="flex flex-wrap items-center justify-between gap-4">
                <div className="space-y-1 text-sm">
                    <p className="font-semibold">
                        {busy
                            ? "Memeriksa routing…"
                            : status?.available
                              ? "Valhalla lokal aktif"
                              : "Routing belum siap"}
                    </p>
                    {status && (
                        <p
                            className={
                                status.available && status.service_area_covered
                                    ? "text-muted-foreground"
                                    : "text-destructive"
                            }
                        >
                            {status.available
                                ? status.service_area_covered
                                    ? "Radius layanan depot tercakup peta demo."
                                    : "Sebagian radius depot berada di luar peta demo. Periksa alamat sebelum checkout."
                                : status.message}
                        </p>
                    )}
                </div>
                <Button
                    type="button"
                    variant="outline"
                    disabled={busy}
                    onClick={refresh}
                >
                    Periksa kembali
                </Button>
            </div>
        </Section>
    );
}
