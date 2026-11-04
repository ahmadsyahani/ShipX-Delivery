import "../css/app.css";
import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";
import type { ComponentType, ReactNode } from "react";
import AdminLayout from "@/layouts/admin-layout";

type Page = ComponentType & { layout?: (page: ReactNode) => ReactNode };
const pages = import.meta.glob<{ default: Page }>("./pages/**/*.tsx");

createInertiaApp({
    title: (title) => (title ? `${title} · ShipX` : "ShipX"),
    resolve: async (name) => {
        const load = pages[`./pages/${name}.tsx`];
        if (!load) throw new Error(`Unknown page: ${name}`);
        const page = await load();
        if (name !== "Admin/Login")
            page.default.layout = (content) => (
                <AdminLayout>{content}</AdminLayout>
            );
        return page;
    },
    setup({ el, App, props }) {
        createRoot(el).render(<App {...props} />);
    },
    progress: { color: "#11675d" },
});
