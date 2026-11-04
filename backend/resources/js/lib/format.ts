export const money = (value: number) =>
    `Rp${new Intl.NumberFormat("id-ID").format(value)}`;
export function dateTime(value: string, timezone = "Asia/Jakarta") {
    return new Intl.DateTimeFormat("id-ID", {
        timeZone: timezone,
        dateStyle: "medium",
        timeStyle: "short",
    }).format(new Date(value));
}
export function time(value: string, timezone: string) {
    return new Intl.DateTimeFormat("en-GB", {
        timeZone: timezone,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
    }).format(new Date(value));
}
export function localInput(value: string | undefined, timezone: string) {
    if (!value) return "";
    const parts = new Intl.DateTimeFormat("en-GB", {
        timeZone: timezone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
    }).formatToParts(new Date(value));
    const p = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}
export const orderStatus: Record<string, string> = {
    pending: "Menunggu konfirmasi",
    confirmed: "Dikonfirmasi",
    rejected: "Ditolak",
    cancelled: "Dibatalkan",
    assigned: "Ditugaskan",
    out_for_delivery: "Dalam pengantaran",
    delivered: "Terkirim",
    failed: "Gagal diantar",
};
