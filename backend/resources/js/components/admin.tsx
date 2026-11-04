import { useEffect, useRef, type ReactNode } from "react";
import { Link } from "@inertiajs/react";
import {
    ArrowLeft,
    ChevronLeft,
    ChevronRight,
    Inbox,
    LoaderCircle,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
} from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { orderStatus } from "@/lib/format";
import type { Paginated } from "@/types";

export function PageHeading({
    title,
    description,
    action,
    back,
}: {
    title: string;
    description?: string;
    action?: ReactNode;
    back?: { href: string; label: string };
}) {
    return (
        <div className="flex flex-wrap items-end justify-between gap-4">
            <div className="min-w-0 flex-1 space-y-2">
                {back && (
                    <Link
                        href={back.href}
                        className="mb-3 inline-flex items-center gap-1.5 text-xs text-muted-foreground hover:text-primary"
                    >
                        <ArrowLeft className="size-3.5" />
                        {back.label}
                    </Link>
                )}
                <h1 className="break-words text-2xl font-semibold tracking-tight sm:text-3xl">
                    {title}
                </h1>
                {description && (
                    <p className="max-w-2xl text-sm leading-6 text-muted-foreground">
                        {description}
                    </p>
                )}
            </div>
            {action}
        </div>
    );
}
export function Section({
    title,
    description,
    children,
    className,
}: {
    title: string;
    description?: string;
    children: ReactNode;
    className?: string;
}) {
    return (
        <Card className={className}>
            <CardHeader>
                <CardTitle>{title}</CardTitle>
                {description && (
                    <CardDescription className="leading-6">
                        {description}
                    </CardDescription>
                )}
            </CardHeader>
            <CardContent>{children}</CardContent>
        </Card>
    );
}
export function Field({
    id,
    label,
    error,
    hint,
    children,
    className,
}: {
    id: string;
    label: string;
    error?: string;
    hint?: string;
    children: ReactNode;
    className?: string;
}) {
    return (
        <div className={`space-y-2 ${className ?? ""}`}>
            <Label htmlFor={id}>{label}</Label>
            {children}
            {hint && (
                <p
                    id={`${id}-hint`}
                    className="text-xs leading-5 text-muted-foreground"
                >
                    {hint}
                </p>
            )}
            {error && (
                <p id={`${id}-error`} className="text-xs text-destructive">
                    {error}
                </p>
            )}
        </div>
    );
}
export function FormErrors({ errors }: { errors: Record<string, string> }) {
    const ref = useRef<HTMLDivElement>(null);
    const text = Object.values(errors).join("|");
    useEffect(() => {
        if (text) ref.current?.focus();
    }, [text]);
    if (!text) return null;
    return (
        <Alert variant="destructive" role="alert" ref={ref} tabIndex={-1}>
            <AlertTitle>Periksa kembali isian</AlertTitle>
            <AlertDescription>
                <ul className="list-disc pl-4">
                    {Object.entries(errors).map(([field, error]) => (
                        <li key={field}>
                            <a
                                href={`#${field}`}
                                className="underline underline-offset-2"
                            >
                                {error}
                            </a>
                        </li>
                    ))}
                </ul>
            </AlertDescription>
        </Alert>
    );
}
export function SaveButton({
    processing,
    children = "Simpan perubahan",
}: {
    processing: boolean;
    children?: ReactNode;
}) {
    return (
        <Button type="submit" disabled={processing}>
            {processing && <LoaderCircle className="animate-spin" />}
            {processing ? "Menyimpan…" : children}
        </Button>
    );
}
export function EmptyState({
    title,
    description,
    action,
}: {
    title: string;
    description: string;
    action?: ReactNode;
}) {
    return (
        <div className="flex flex-col items-center px-6 py-16 text-center">
            <span className="mb-4 grid size-12 place-items-center rounded-xl border bg-muted/50">
                <Inbox className="size-5 text-muted-foreground" />
            </span>
            <h2 className="font-semibold">{title}</h2>
            <p className="mb-5 mt-2 max-w-sm text-sm leading-6 text-muted-foreground">
                {description}
            </p>
            {action}
        </div>
    );
}
export function Pager({ page }: { page: Omit<Paginated<unknown>, "data"> }) {
    if (page.total === 0) return null;
    return (
        <div className="flex flex-wrap items-center justify-between gap-3 border-t px-5 py-4 text-xs text-muted-foreground">
            <p>
                {page.from}–{page.to} dari {page.total} data
            </p>
            <div className="flex items-center gap-2">
                <Button
                    variant="outline"
                    size="icon"
                    disabled={!page.prev_page_url}
                    asChild={!!page.prev_page_url}
                >
                    {page.prev_page_url ? (
                        <Link
                            href={page.prev_page_url}
                            aria-label="Halaman sebelumnya"
                            preserveScroll
                        >
                            <ChevronLeft />
                        </Link>
                    ) : (
                        <span aria-label="Halaman sebelumnya">
                            <ChevronLeft />
                        </span>
                    )}
                </Button>
                <span>
                    {page.current_page} / {page.last_page}
                </span>
                <Button
                    variant="outline"
                    size="icon"
                    disabled={!page.next_page_url}
                    asChild={!!page.next_page_url}
                >
                    {page.next_page_url ? (
                        <Link
                            href={page.next_page_url}
                            aria-label="Halaman berikutnya"
                            preserveScroll
                        >
                            <ChevronRight />
                        </Link>
                    ) : (
                        <span aria-label="Halaman berikutnya">
                            <ChevronRight />
                        </span>
                    )}
                </Button>
            </div>
        </div>
    );
}
export function StatusBadge({ status }: { status: string | boolean }) {
    const value =
        typeof status === "boolean" ? (status ? "active" : "inactive") : status;
    const green = ["active", "confirmed", "delivered", "open"].includes(value);
    const amber = value === "pending";
    return (
        <Badge
            variant="outline"
            className={
                green
                    ? "border-primary/20 bg-primary/5 text-primary"
                    : amber
                      ? "border-amber-300/60 bg-amber-50 text-amber-800"
                      : "bg-muted/50 text-muted-foreground"
            }
        >
            {value === "active"
                ? "Aktif"
                : value === "inactive"
                  ? "Nonaktif"
                  : value === "open"
                    ? "Terbuka"
                    : value === "closed"
                      ? "Ditutup"
                      : (orderStatus[value] ?? value)}
        </Badge>
    );
}
