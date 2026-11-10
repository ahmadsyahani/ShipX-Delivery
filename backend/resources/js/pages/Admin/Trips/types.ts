import type { Order, Vehicle } from "@/types";
export type SnapshotOrder = {
    id: string;
    order_number: string;
    total_weight_g: number;
    total_volume_cm3: number;
    window_start_at: string;
    window_end_at: string;
    total_rp: number;
    address: {
        recipient_name: string;
        phone: string;
        address_text: string;
        directions: string | null;
    };
    items: {
        id: string;
        name: string;
        quantity: number;
        unit_label: string;
        length_mm: number;
        width_mm: number;
        height_mm: number;
        handling_notes: string | null;
    }[];
};
export type Plan = {
    courier_id: number;
    vehicle_id: number;
    departure_local: string;
    orders: { id: number; lock_version: number }[];
};
export type Route = {
    id: number;
    version_number: number;
    feasibility_status: string;
    input_snapshot: {
        plan: Plan;
        courier: { name: string };
        vehicle: Vehicle;
        depot: { name: string; address_text: string };
        orders: SnapshotOrder[];
    };
};
export type Trip = {
    id: number;
    trip_number: string;
    status: string;
    lock_version: number;
    planned_departure_at: string;
    actual_departure_at: string | null;
    loaded_weight_g: number;
    loaded_volume_cm3: number;
    timezone_snapshot: string;
    planned_weight_g: number;
    planned_volume_cm3: number;
    capacity_weight_g_snapshot: number;
    capacity_volume_cm3_snapshot: number;
    selected_route: Route;
    routes?: Route[];
};
export type CandidateOrder = Order & { delivery_slot_id: number };
export const tripStatus: Record<string, string> = {
    draft: "Draft",
    assigned: "Ditetapkan",
    in_progress: "Dalam perjalanan",
    awaiting_reconciliation: "Menunggu rekonsiliasi",
    completed: "Selesai",
    cancelled: "Dibatalkan",
};
