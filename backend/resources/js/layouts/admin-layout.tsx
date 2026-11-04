import { useState, type ReactNode } from "react";
import { Link, useForm, usePage } from "@inertiajs/react";
import {
    ArrowUpRight,
    Boxes,
    CalendarClock,
    ChevronDown,
    ClipboardList,
    LayoutDashboard,
    LogOut,
    MapPin,
    Menu,
    Package,
    Truck,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
    SheetTrigger,
} from "@/components/ui/sheet";
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { cn } from "@/lib/utils";
import type { Shared } from "@/types";

const navigation = [
    { href: "/admin", label: "Ringkasan", icon: LayoutDashboard },
    { href: "/admin/orders", label: "Pesanan", icon: ClipboardList },
    { href: "/admin/products", label: "Produk", icon: Package },
    { href: "/admin/stock", label: "Stok", icon: Boxes },
    { href: "/admin/slots", label: "Slot pengiriman", icon: CalendarClock },
    { href: "/admin/depot", label: "Depot", icon: MapPin },
];

export function Brand() {
    return (
        <span className="flex items-center gap-2.5 text-xl font-bold tracking-tight">
            <span className="grid size-9 place-items-center rounded-lg bg-primary text-white">
                <Truck className="size-5" />
            </span>
            ShipX
            <span className="mb-2 size-1.5 rounded-full bg-primary" />
        </span>
    );
}

export default function AdminLayout({ children }: { children: ReactNode }) {
    const { auth, flash } = usePage<Shared>().props;
    const { url } = usePage();
    const [open, setOpen] = useState(false);
    const logout = useForm({});
    const current = navigation.find((item) =>
        item.href === "/admin"
            ? url.split("?")[0] === item.href
            : url.startsWith(item.href),
    );
    const nav = (
        <nav aria-label="Navigasi utama" className="space-y-1">
            {navigation.map(({ href, label, icon: Icon }) => {
                const active = href === current?.href;
                return (
                    <Link
                        key={href}
                        href={href}
                        onClick={() => setOpen(false)}
                        aria-current={active ? "page" : undefined}
                        className={cn(
                            "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring",
                            active
                                ? "bg-primary/10 text-primary"
                                : "text-muted-foreground",
                        )}
                    >
                        <Icon className="size-[18px]" />
                        {label}
                    </Link>
                );
            })}
        </nav>
    );
    return (
        <div className="min-h-dvh">
            <a
                href="#main-content"
                className="sr-only z-50 rounded bg-card p-3 focus:not-sr-only focus:fixed focus:left-4 focus:top-4"
            >
                Lewati ke konten
            </a>
            <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 flex-col border-r bg-card px-5 py-7 lg:flex">
                <Link href="/admin" aria-label="ShipX beranda">
                    <Brand />
                </Link>
                <p className="mb-4 mt-10 px-3 text-xs text-muted-foreground">
                    Ruang operasional
                </p>
                {nav}
                <div className="mt-auto rounded-xl border bg-background p-4">
                    <div className="flex items-center gap-2 text-sm font-medium">
                        <span className="size-2 rounded-full bg-primary" />
                        Pusat pemenuhan
                    </div>
                    <p className="mt-2 text-xs leading-5 text-muted-foreground">
                        Kelola barang dan jadwal dari satu depot.
                    </p>
                    <Link
                        href="/admin/depot"
                        className="mt-3 inline-flex items-center gap-1 text-xs font-medium text-primary"
                    >
                        Pengaturan depot <ArrowUpRight className="size-3.5" />
                    </Link>
                </div>
            </aside>
            <div className="lg:pl-60">
                <header className="sticky top-0 z-20 flex h-[72px] items-center justify-between gap-3 border-b bg-card/95 px-4 backdrop-blur sm:px-8">
                    <div className="flex items-center gap-3">
                        <Sheet open={open} onOpenChange={setOpen}>
                            <SheetTrigger asChild>
                                <Button
                                    variant="outline"
                                    size="icon"
                                    className="lg:hidden"
                                    aria-label="Buka navigasi"
                                >
                                    <Menu />
                                </Button>
                            </SheetTrigger>
                            <SheetContent side="left" className="w-72 p-5">
                                <SheetHeader className="p-0 pb-8">
                                    <SheetTitle>
                                        <Brand />
                                    </SheetTitle>
                                </SheetHeader>
                                {nav}
                            </SheetContent>
                        </Sheet>
                        <span className="text-sm text-muted-foreground">
                            Operasional{" "}
                            <span className="px-2 text-border">/</span>
                            <span className="font-medium text-foreground">
                                {current?.label ?? "ShipX"}
                            </span>
                        </span>
                    </div>
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button
                                variant="ghost"
                                className="h-auto gap-2 py-2"
                                aria-label="Menu akun"
                            >
                                <span className="grid size-8 place-items-center rounded-full bg-secondary text-xs font-semibold text-primary">
                                    {auth.user?.name.slice(0, 1).toUpperCase()}
                                </span>
                                <span className="hidden text-left sm:block">
                                    <span className="block text-xs font-semibold">
                                        {auth.user?.name}
                                    </span>
                                    <span className="block text-[11px] text-muted-foreground">
                                        Administrator
                                    </span>
                                </span>
                                <ChevronDown className="size-3.5 text-muted-foreground" />
                            </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-60">
                            <DropdownMenuLabel className="truncate text-xs font-normal text-muted-foreground">
                                {auth.user?.email}
                            </DropdownMenuLabel>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem
                                disabled={logout.processing}
                                onSelect={() => logout.post("/admin/logout")}
                            >
                                <LogOut />
                                Keluar
                            </DropdownMenuItem>
                        </DropdownMenuContent>
                    </DropdownMenu>
                </header>
                <main
                    id="main-content"
                    className="mx-auto max-w-[1440px] space-y-7 p-4 pb-12 sm:p-8 lg:p-10"
                    tabIndex={-1}
                >
                    {flash.status && (
                        <Alert
                            className="border-primary/25 bg-primary/5"
                            role="status"
                        >
                            <AlertDescription className="text-primary">
                                {flash.status}
                            </AlertDescription>
                        </Alert>
                    )}
                    {children}
                </main>
                <footer className="mx-auto flex max-w-[1440px] justify-between gap-4 px-4 pb-7 text-xs text-muted-foreground sm:px-8 lg:px-10">
                    <span>ShipX · Ruang operasional</span>
                    <span>Barang sampai, urusan beres.</span>
                </footer>
            </div>
        </div>
    );
}
