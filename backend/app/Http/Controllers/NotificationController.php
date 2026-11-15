<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(['data' => $request->user()->notifications()->orderByDesc('created_at')->orderByDesc('id')->paginate(20)->withQueryString(),
            'unread_count' => $request->user()->unreadNotifications()->count()]);
    }

    public function read(Request $request, string $id)
    {
        $notification = $request->user()->notifications()->findOrFail($id);
        $notification->markAsRead();

        return response()->json(['data' => ['id' => $notification->id, 'read_at' => $notification->fresh()->read_at?->toISOString()]]);
    }

    public function readAll(Request $request)
    {
        $request->user()->unreadNotifications()->update(['read_at' => now()]);

        return response()->json(['data' => ['read' => true]]);
    }
}
