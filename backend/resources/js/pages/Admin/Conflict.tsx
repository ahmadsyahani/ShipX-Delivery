import { Head, Link } from "@inertiajs/react";
import { RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export default function Conflict({
    message,
    reloadUrl,
}: {
    message: string;
    reloadUrl: string;
}) {
    return (
        <>
            <Head title="Perubahan belum disimpan" />
            <Card className="mx-auto max-w-xl shadow-none">
                <CardContent className="py-5">
                    <span className="mb-5 grid size-12 place-items-center rounded-xl bg-amber-50 text-amber-800">
                        <RefreshCw />
                    </span>
                    <h1 className="text-2xl font-semibold tracking-tight">
                        Perubahan belum disimpan
                    </h1>
                    <p className="mb-6 mt-3 text-sm leading-7 text-muted-foreground">
                        {message}
                    </p>
                    <Button asChild>
                        <Link href={reloadUrl}>Muat data terbaru</Link>
                    </Button>
                </CardContent>
            </Card>
        </>
    );
}
