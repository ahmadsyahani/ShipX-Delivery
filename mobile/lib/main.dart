import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'core/api_config.dart';
import 'core/app_theme.dart';
import 'core/app_widgets.dart';
import 'core/health_api.dart';
import 'core/auth_session.dart';
import 'auth_page.dart';
import 'commerce/shopping_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Plus Jakarta Sans',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
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
    theme: AppTheme.theme,
    home: AuthGate(session: session, pendingStoreFactory: pendingStoreFactory),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.session, this.pendingStoreFactory});
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
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        );
      }
      if (session.restoreError != null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        session.restoreError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: session.restore,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (session.user != null) {
        return RoleHome(
          session: session,
          pendingStoreFactory: widget.pendingStoreFactory,
        );
      }
      return Column(
        children: [
          Expanded(child: AuthPage(session: session)),
          Material(
            color: AppColors.background,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    icon: const Icon(Icons.wifi_tethering, size: 16),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ConnectionPage(),
                      ),
                    ),
                    label: const Text('Periksa koneksi'),
                  ),
                ),
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
  bool? _success;

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _message = 'Menghubungkan…';
      _success = null;
    });
    var message = 'Terhubung ke API ShipX v1.';
    bool ok = true;
    try {
      await HealthApi().check(ApiConfig.baseUrl);
    } catch (_) {
      ok = false;
      message =
          'Belum terhubung. Periksa alamat API, jaringan, dan server Laravel.';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = message;
      _success = ok;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Koneksi ShipX')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageIntro(
                title: 'Barang sampai, urusan beres.',
                description: 'Periksa koneksi perangkat ini ke layanan ShipX.',
              ),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionTitle(
                      title: 'Status koneksi',
                      icon: Icons.wifi_tethering_rounded,
                    ),
                    InfoBanner(
                      message: _message,
                      color: _success == true
                          ? AppColors.success
                          : _success == false
                          ? AppColors.error
                          : AppColors.textBody,
                      backgroundColor: _success == true
                          ? AppColors.successBg
                          : _success == false
                          ? AppColors.errorBg
                          : AppColors.background,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Alamat layanan',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      ApiConfig.baseUrl,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loading ? null : _check,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _loading ? 'Memeriksa...' : 'Periksa koneksi',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
