import { useEffect, useState } from "react";
import { Link, router } from "@inertiajs/react";
import { Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
    NativeSelect,
    NativeSelectOption,
} from "@/components/ui/native-select";

export type MasterFilterValues = { q: string; status: string };
export function MasterFilters({
    filters,
    path,
    label,
}: {
    filters: MasterFilterValues;
    path: string;
    label: string;
}) {
    const [q, setQ] = useState(filters.q);
    const [status, setStatus] = useState(filters.status);
    useEffect(() => {
        setQ(filters.q);
        setStatus(filters.status);
    }, [filters.q, filters.status]);
    return (
        <form
            className="flex flex-wrap items-center gap-3 border-b p-4"
            onSubmit={(event) => {
                event.preventDefault();
                router.get(
                    path,
                    { q, status },
                    { preserveState: true, replace: true },
                );
            }}
        >
            <div className="relative min-w-48 flex-1 sm:max-w-sm">
                <Search className="absolute left-3 top-2.5 size-4 text-muted-foreground" />
                <Input
                    aria-label={`Cari ${label}`}
                    placeholder={`Cari ${label}…`}
                    maxLength={100}
                    className="pl-9"
                    value={q}
                    onChange={(event) => setQ(event.target.value)}
                />
            </div>
            <NativeSelect
                aria-label={`Status ${label}`}
                value={status}
                onChange={(event) => setStatus(event.target.value)}
            >
                <NativeSelectOption value="">Semua status</NativeSelectOption>
                <NativeSelectOption value="active">Aktif</NativeSelectOption>
                <NativeSelectOption value="inactive">
                    Nonaktif
                </NativeSelectOption>
            </NativeSelect>
            <Button variant="outline">Terapkan</Button>
            {(filters.q || filters.status) && (
                <Button variant="ghost" asChild>
                    <Link href={path}>Reset</Link>
                </Button>
            )}
        </form>
    );
}
