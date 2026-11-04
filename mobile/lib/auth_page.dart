import 'package:flutter/material.dart';

import 'core/auth_api.dart';
import 'core/auth_session.dart';
import 'catalog_page.dart';
import 'delivery/delivery_page.dart';
import 'commerce/shopping_state.dart';
import 'commerce/cart_page.dart';
import 'commerce/orders_page.dart';

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

  Widget _field(String key, String label, {bool password = false}) => Padding(
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
      decoration: InputDecoration(labelText: label),
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
        padding: const EdgeInsets.all(24),
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF087E8B),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Text(
                      'ShipX',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _register
                      ? 'Buat akun untuk menjelajahi katalog ShipX.'
                      : 'Masuk dan temukan kebutuhan sehari-hari Anda.',
                  style: const TextStyle(color: Color(0xFF657B83)),
                ),
                const SizedBox(height: 28),
                if (_register) _field('name', 'Nama'),
                _field('email', 'Email'),
                if (_register) _field('phone', 'Nomor telepon'),
                _field('password', 'Kata sandi', password: true),
                if (_register)
                  _field(
                    'password_confirmation',
                    'Ulangi kata sandi',
                    password: true,
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _busy
                        ? 'Memproses...'
                        : _register
                        ? 'Daftar'
                        : 'Masuk',
                  ),
                ),
                TextButton(
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
  const RoleHome({super.key, required this.session,this.pendingStoreFactory});
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
      _shopping = ShoppingState(session: widget.session,store:widget.pendingStoreFactory?.call(widget.session.user!.id));
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
    final account = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const CircleAvatar(
          radius: 38,
          backgroundColor: Color(0xFFDCEFF0),
          child: Icon(Icons.person_outline, size: 40, color: Color(0xFF087E8B)),
        ),
        const SizedBox(height: 24),
        Text(
          'Halo, ${user.name}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(user.email),
        const SizedBox(height: 16),
        Text(switch (user.role) {
          'courier' => 'Modul perjalanan akan tersedia pada tahap berikutnya.',
          'admin' => 'Buka /admin di web ShipX untuk masuk sebagai admin.',
          _ => 'Akun pelanggan ShipX. Jelajahi barang melalui tab Katalog.',
        }),
        if (_shopping != null)
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Pesanan saya'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OrdersPage(session: widget.session, shopping: _shopping!),
              ),
            ),
          ),
        if (_error != null) Text(_error!),
        TextButton(
          onPressed: _busy ? null : () => _run(widget.session.refresh),
          child: const Text('Periksa sesi'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _run(widget.session.logout),
          child: const Text('Keluar'),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      bottomNavigationBar: user.role == 'customer'
          ? NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() => _tab = value),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFDCEFF0),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Katalog',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(Icons.local_shipping),
                  label: 'Pengiriman',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag),
                  label: 'Keranjang',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Akun',
                ),
              ],
            )
          : null,
      body: user.role == 'customer'
          ? IndexedStack(
              index: _tab,
              children: [
                CatalogPage(
                  session: widget.session,
                  shopping: _shopping,
                  openCart: () => setState(() => _tab = 2),
                ),
                DeliveryPage(session: widget.session, shopping: _shopping),
                CartPage(
                  session: widget.session,
                  shopping: _shopping!,
                  chooseDelivery: () => setState(() => _tab = 1),
                  browse: () => setState(() => _tab = 0),
                ),
                account,
              ],
            )
          : account,
    );
  }
}
