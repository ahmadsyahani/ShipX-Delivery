import { useState } from "react";
import { useForm } from "@inertiajs/react";
import { Check, X } from "lucide-react";
import {
    AlertDialog,
    AlertDialogContent,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogCancel,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Field, FormErrors, SaveButton, Section } from "@/components/admin";
import type { Order } from "@/types";

export type DecisionKeys = { confirm: string; reject: string };
export default function OrderDecision({
    order,
    keys,
}: {
    order: Order;
    keys: DecisionKeys;
}) {
    const [mode, setMode] = useState<"confirm" | "reject" | null>(null);
    const confirm = useForm({
        idempotency_key: keys.confirm,
        lock_version: order.lock_version,
    });
    const reject = useForm({
        idempotency_key: keys.reject,
        lock_version: order.lock_version,
        reason: "",
    });
    const busy = confirm.processing || reject.processing;
    if (order.status !== "pending") return null;
    const form = mode === "reject" ? reject : confirm;
    return (
        <Section
            title="Tinjau pesanan"
            description="Periksa barang, tujuan, dan jadwal sebelum mengambil keputusan."
        >
            <div className="flex flex-wrap items-center justify-between gap-4">
                <p className="max-w-2xl text-sm leading-6 text-muted-foreground">
                    Konfirmasi mempertahankan reservasi stok. Pesanan yang
                    ditolak tidak dapat diproses kembali dan stoknya dilepas.
                </p>
                <div className="flex flex-wrap gap-2">
                    <Button
                        variant="outline"
                        disabled={busy}
                        onClick={() => setMode("reject")}
                    >
                        <X />
                        Tolak pesanan
                    </Button>
                    <Button disabled={busy} onClick={() => setMode("confirm")}>
                        <Check />
                        Konfirmasi pesanan
                    </Button>
                </div>
            </div>
            <AlertDialog
                open={mode !== null}
                onOpenChange={(open) => {
                    if (!open && !busy) setMode(null);
                }}
            >
                <AlertDialogContent>
                    <form
                        className="space-y-5"
                        onSubmit={(event) => {
                            event.preventDefault();
                            if (!mode || busy) return;
                            form.post(`/admin/orders/${order.id}/${mode}`, {
                                preserveScroll: true,
                                onSuccess: () => setMode(null),
                            });
                        }}
                    >
                        <AlertDialogHeader>
                            <AlertDialogTitle>
                                {mode === "reject"
                                    ? "Tolak pesanan ini?"
                                    : "Konfirmasi pesanan ini?"}
                            </AlertDialogTitle>
                            <AlertDialogDescription>
                                {mode === "reject"
                                    ? "Alasan akan terlihat oleh pelanggan. Seluruh reservasi barang pada pesanan ini akan dilepas."
                                    : "Pastikan pesanan dapat dilayani sesuai jadwal. Barang tetap direservasi untuk pesanan ini; belum ada pengurangan stok fisik."}
                            </AlertDialogDescription>
                        </AlertDialogHeader>
                        <FormErrors errors={form.errors} />
                        {mode === "reject" && (
                            <Field
                                id="reason"
                                label="Alasan penolakan"
                                error={reject.errors.reason}
                            >
                                <Textarea
                                    id="reason"
                                    required
                                    maxLength={500}
                                    rows={3}
                                    disabled={busy}
                                    value={reject.data.reason}
                                    onChange={(event) =>
                                        reject.setData(
                                            "reason",
                                            event.target.value,
                                        )
                                    }
                                    aria-invalid={!!reject.errors.reason}
                                />
                            </Field>
                        )}
                        <AlertDialogFooter>
                            <AlertDialogCancel disabled={busy}>
                                Kembali
                            </AlertDialogCancel>
                            <SaveButton processing={busy}>
                                {mode === "reject"
                                    ? "Ya, tolak pesanan"
                                    : "Ya, konfirmasi pesanan"}
                            </SaveButton>
                        </AlertDialogFooter>
                    </form>
                </AlertDialogContent>
            </AlertDialog>
        </Section>
    );
}
