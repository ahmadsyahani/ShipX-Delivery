import 'dart:async';
import 'package:flutter/material.dart';

// Poll only the visible order route while the app is in the foreground.
// This is bounded polling, not a push/real-time connection.
mixin OrderRefresh<T extends StatefulWidget> on State<T> {
  Timer? _orderTimer;
  AppLifecycleListener? _orderLifecycle;

  void startOrderRefresh(Future<void> Function() refresh) {
    void check() {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      unawaited(refresh());
    }

    _orderTimer = Timer.periodic(const Duration(seconds: 15), (_) => check());
    _orderLifecycle = AppLifecycleListener(onResume: check);
  }

  @override
  void dispose() {
    _orderTimer?.cancel();
    _orderLifecycle?.dispose();
    super.dispose();
  }
}
