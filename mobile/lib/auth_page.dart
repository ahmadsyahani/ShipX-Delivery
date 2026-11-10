import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'account/account_page.dart';
import 'core/auth_api.dart';
import 'core/auth_session.dart';
import 'catalog_page.dart';
import 'delivery/delivery_page.dart';
import 'commerce/shopping_state.dart';
import 'commerce/cart_page.dart';
import 'commerce/orders_page.dart';
import 'courier/trips_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.session});
  final AuthSession session;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, String>{};
  bool _register = false, _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.authenticate(_fields, register: _register);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Belum dapat masuk. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    bool password = false,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      enabled: !_busy,
      obscureText: password,
      autocorrect: !password,
      enableSuggestions: !password,
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : key == 'phone'
          ? TextInputType.phone
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppColors.textMuted)
            : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
        if (_register && key == 'password' && value.length < 12) {
          return 'Gunakan minimal 12 karakter.';
        }
        return null;
      },
      onSaved: (value) => _fields[key] = password ? value! : value!.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'Daftar pelanggan' : 'Masuk ShipX')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ShipX',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMain,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'Express Cargo & Commerce',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  _register
                      ? 'Mulai dari kebutuhan Anda.'
                      : 'Barang sampai,\nurusan beres.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                    letterSpacing: -1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _register
                      ? 'Buat akun untuk menjelajahi katalog ShipX.'
                      : 'Masuk dan temukan kebutuhan sehari-hari Anda.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_register)
                          _field('name', 'Nama', icon: Icons.person_outline),
                        _field('email', 'Email', icon: Icons.email_outlined),
                        if (_register)
                          _field(
                            'phone',
                            'Nomor telepon',
                            icon: Icons.phone_outlined,
                          ),
                        _field(
                          'password',
                          'Kata sandi',
                          password: true,
                          icon: Icons.lock_outline,
                        ),
                        if (_register)
                          _field(
                            'password_confirmation',
                            'Ulangi kata sandi',
                            password: true,
                            icon: Icons.lock_reset_outlined,
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _register ? 'Daftar' : 'Masuk',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _error = null;
                            _fields.clear();
                            _form.currentState?.reset();
                          }),
                    child: Text(
                      _register
                          ? 'Sudah punya akun? Masuk'
                          : 'Buat akun pelanggan',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RoleHome extends StatefulWidget {
  const RoleHome({super.key, required this.session, this.pendingStoreFactory});
  final AuthSession session;
  final PendingStore Function(String)? pendingStoreFactory;
  @override
  State<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<RoleHome> {
  ShoppingState? _shopping;
  @override
  void initState() {
    super.initState();
    if (widget.session.user?.role == 'customer') {
      _shopping = ShoppingState(
        session: widget.session,
        store: widget.pendingStoreFactory?.call(widget.session.user!.id),
      );
      _shopping!.addListener(_shoppingChanged);
      _shopping!.restore();
    }
  }

  void _shoppingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shopping?.removeListener(_shoppingChanged);
    _shopping?.dispose();
    super.dispose();
  }

  Future<void> _deliverySheet() async {
    if (_shopping == null || _shopping!.locked) return;
    final draft = ShoppingState(session: widget.session)..ready = true;
    draft.chooseAddress(_shopping!.address);
    draft.chooseSlot(_shopping!.slot);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pengiriman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup pilihan pengiriman',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DeliveryPage(
                session: widget.session,
                shopping: draft,
                continueLabel: 'Gunakan alamat & jadwal',
                openCart: () => Navigator.pop(sheetContext, true),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted && confirmed == true && !_shopping!.locked) {
      _shopping!.chooseAddress(draft.address);
      _shopping!.chooseSlot(draft.slot);
    }
    draft.dispose();
  }

  int _tab = 0;
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Koneksi gagal. Coba lagi; sesi tetap tersimpan.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user!;
    final title = switch (user.role) {
      'courier' => 'Beranda kurir',
      'admin' => 'Akun admin',
      _ => 'Beranda pelanggan',
    };

    final account = AccountPage(
      user: user,
      busy: _busy,
      error: _error,
      refresh: () => _run(widget.session.refresh),
      logout: () => _run(widget.session.logout),
      orders: _shopping == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OrdersPage(session: widget.session, shopping: _shopping!),
              ),
            ),
      delivery: _shopping == null ? null : () => setState(() => _tab = 1),
      trips: user.role == 'courier' ? () => setState(() => _tab = 0) : null,
    );

    final cartBadgeCount = _shopping?.count ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user.role == 'customer'
              ? ['ShipX', 'Pengiriman', 'Checkout', 'Akun'][_tab]
              : user.role == 'courier'
              ? ['Trip pengiriman', 'Akun'][_tab]
              : title,
          style: TextStyle(
            fontSize: user.role == 'customer' && _tab == 0 ? 25 : 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: _tab == 0 && user.role == 'customer'
                ? AppColors.primaryDark
                : AppColors.textMain,
          ),
        ),
        centerTitle: user.role == 'customer' && _tab != 0,
        toolbarHeight: 58,
        actions: [
          if (user.role == 'customer')
            IconButton(
              icon: Badge(
                isLabelVisible: cartBadgeCount > 0,
                label: Text('$cartBadgeCount'),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              tooltip: 'Keranjang',
              onPressed: () => setState(() => _tab = 2),
            ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: user.role == 'customer'
            ? NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (value) => setState(() => _tab = value),
                backgroundColor: Colors.white,
                elevation: 0,
                indicatorColor: Colors.transparent,
                height: 68,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon: Icon(
                      Icons.storefront,
                      color: AppColors.primary,
                    ),
                    label: 'Katalog',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(
                      Icons.local_shipping,
                      color: AppColors.primary,
                    ),
                    label: 'Pengiriman',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: cartBadgeCount > 0,
                      label: Text('$cartBadgeCount'),
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: cartBadgeCount > 0,
                      label: Text('$cartBadgeCount'),
                      backgroundColor: AppColors.primary,
                      child: const Icon(
                        Icons.shopping_bag,
                        color: AppColors.primary,
                      ),
                    ),
                    label: 'Keranjang',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: AppColors.primary),
                    label: 'Akun',
                  ),
                ],
              )
            : user.role == 'courier'
            ? NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (value) => setState(() => _tab = value),
                backgroundColor: Colors.white,
                elevation: 0,
                indicatorColor: AppColors.primaryLight,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.route_outlined),
                    selectedIcon: Icon(Icons.route, color: AppColors.primary),
                    label: 'Trip',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: AppColors.primary),
                    label: 'Akun',
                  ),
                ],
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 760,
            child: user.role == 'customer'
                ? IndexedStack(
                    index: _tab,
                    children: [
                      CatalogPage(
                        session: widget.session,
                        shopping: _shopping,
                        openCart: () => setState(() => _tab = 2),
                        chooseDelivery: _deliverySheet,
                        keyboardVisible:
                            MediaQuery.viewInsetsOf(context).bottom > 0,
                      ),
                      _tab != 1
                          ? const SizedBox.shrink()
                          : DeliveryPage(
                              session: widget.session,
                              shopping: _shopping,
                              openCart: () => setState(() => _tab = 2),
                            ),
                      CartPage(
                        session: widget.session,
                        shopping: _shopping!,
                        chooseDelivery: _deliverySheet,
                        browse: () => setState(() => _tab = 0),
                      ),
                      account,
                    ],
                  )
                : user.role == 'courier'
                ? IndexedStack(
                    index: _tab,
                    children: [
                      CourierTripsPage(
                        session: widget.session,
                        active: _tab == 0,
                      ),
                      account,
                    ],
                  )
                : account,
          ),
        ),
      ),
    );
  }
}
