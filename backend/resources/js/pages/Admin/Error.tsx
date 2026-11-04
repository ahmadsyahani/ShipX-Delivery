import { Head, Link } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

const messages: Record<number, [string, string]> = {
    403: [
        "Akses dibatasi",
        "Halaman ini hanya dapat diakses administrator aktif.",
    ],
    404: [
        "Halaman tidak ditemukan",
        "Data mungkin sudah berubah. Kembali ke ringkasan untuk melanjutkan.",
    ],
    419: [
        "Sesi formulir berakhir",
        "Muat ulang halaman dan masuk kembali sebelum menyimpan perubahan.",
    ],
    429: [
        "Terlalu banyak percobaan",
        "Tunggu sebentar sebelum mencoba kembali.",
    ],
    500: [
        "Halaman belum dapat dimuat",
        "Terjadi kendala pada server. Coba muat ulang beberapa saat lagi.",
    ],
    503: ["Layanan sedang dirawat", "Silakan kembali beberapa saat lagi."],
};
export default function ErrorPage({ status }: { status: number }) {
    const [title, message] = messages[status] ?? messages[500];
    return (
        <>
            <Head title={title} />
            <Card className="mx-auto max-w-xl shadow-none">
                <CardContent className="py-5">
                    <p className="mb-5 text-sm text-muted-foreground">
                        {status}
                    </p>
                    <h1 className="text-2xl font-semibold tracking-tight">
                        {title}
                    </h1>
                    <p className="mb-6 mt-3 text-sm leading-7 text-muted-foreground">
                        {message}
                    </p>
                    {status === 419 ? (
                        <Button asChild>
                            <a href="/admin/login">Masuk kembali</a>
                        </Button>
                    ) : (
                        <Button asChild>
                            <Link href="/admin">Kembali ke ringkasan</Link>
                        </Button>
                    )}
                </CardContent>
            </Card>
        </>
    );
}
