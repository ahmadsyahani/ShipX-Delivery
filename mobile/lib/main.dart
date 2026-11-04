import 'package:flutter/material.dart';

import 'core/api_config.dart';
import 'core/health_api.dart';
import 'core/auth_session.dart';
import 'auth_page.dart';
import 'commerce/shopping_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShipXApp());
}

class ShipXApp extends StatelessWidget {
  const ShipXApp({super.key, this.session, this.pendingStoreFactory});
  final AuthSession? session;
  final PendingStore Function(String)? pendingStoreFactory;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ShipX',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF087E8B),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F8FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F8FA),
        foregroundColor: Color(0xFF203C45),
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD9DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD9DE)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF087E8B),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    home: AuthGate(session: session,pendingStoreFactory:pendingStoreFactory),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.session,this.pendingStoreFactory});
  final AuthSession? session;
  final PendingStore Function(String)? pendingStoreFactory;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthSession session;
  bool _hadUser = false;
  void _authChanged() {
    final hadUser = _hadUser;
    _hadUser = session.user != null;
    if (hadUser && !_hadUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    session = widget.session ?? AuthSession();
    _hadUser = session.user != null;
    session.addListener(_authChanged);
    session.restore();
  }

  @override
  void dispose() {
    session.removeListener(_authChanged);
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (session.restoring) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (session.restoreError != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(session.restoreError!),
                TextButton(
                  onPressed: session.restore,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        );
      }
      if (session.user != null) return RoleHome(session: session,pendingStoreFactory:widget.pendingStoreFactory);
      return Column(
        children: [
          Expanded(child: AuthPage(session: session)),
          Material(
            child: SafeArea(
              top: false,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ConnectionPage(),
                  ),
                ),
                child: const Text('Periksa koneksi'),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool _loading = false;
  String _message =
      'Fondasi aplikasi siap. Periksa koneksi backend untuk melanjutkan.';

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _message = 'Menghubungkan…';
    });
    var message = 'Terhubung ke API ShipX v1.';
    try {
      await HealthApi().check(ApiConfig.baseUrl);
    } catch (_) {
      message =
          'Belum terhubung. Periksa alamat API, jaringan, dan server Laravel.';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ShipX')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 72),
              const SizedBox(height: 24),
              Text(
                'Barang sampai, urusan beres.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(_message, key: const Key('connection-status')),
              const SizedBox(height: 12),
              SelectableText(
                ApiConfig.baseUrl,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _check,
                icon: const Icon(Icons.link),
                label: Text(_loading ? 'Memeriksa…' : 'Periksa koneksi'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
