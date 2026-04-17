import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backend_client.dart';
import '../services/event_manager.dart';
import '../theme/app_theme.dart';

/// Konfiguracja backendu (URL + X-API-Key) dla Sesja 7.
/// Dostepne z SettingsScreen.
class BackendSetupScreen extends StatefulWidget {
  const BackendSetupScreen({super.key});

  @override
  State<BackendSetupScreen> createState() => _BackendSetupScreenState();
}

class _BackendSetupScreenState extends State<BackendSetupScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final backend = context.read<BackendClient>();
    _urlCtrl.text = backend.baseUrl;
    _keyCtrl.text = backend.apiKey;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final backend = context.read<BackendClient>();
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    final key = _keyCtrl.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testOk = false;
        _testResult = 'Wpisz URL';
      });
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });

    // Save temporarily + test.
    await backend.saveConfig(baseUrl: url, apiKey: key);
    final ok = await backend.testConnection();
    if (!mounted) return;

    // Dodatkowo sprawdz czy event active jest zwracany (pokazuje ze uploadery dzialaja).
    final event = ok ? await backend.getActiveEvent() : null;

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testResult = ok
          ? event != null
              ? 'Polaczono. Aktywny event: "${event.name}"'
              : 'Polaczono, ale brak aktywnego eventu (utworz w admin panelu backendu)'
          : 'Brak odpowiedzi. Sprawdz URL/WiFi.';
    });
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (url.isEmpty) return;
    final eventMgr = context.read<EventManager>();
    await eventMgr.reconfigure(baseUrl: url, apiKey: key);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano - trwa synchronizacja...')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendClient>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Backend'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  backend.isConfigured ? Icons.cloud_done : Icons.cloud_off,
                  size: 28,
                  color: backend.isConfigured ? AppTheme.success : AppTheme.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    backend.isConfigured ? 'URL: ${backend.baseUrl}' : 'Backend nieskonfigurowany',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'URL backendu (bez koncowego /)',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: _dec('np. http://192.168.100.2:5100 albo https://booth.akces360.pl'),
            ),
            const SizedBox(height: 14),
            const Text(
              'X-API-Key (STATION_API_KEY z .env backendu)',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _keyCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: _dec('random-key-for-station'),
            ),
            const SizedBox(height: 20),
            if (_testResult != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_testOk ? AppTheme.success : AppTheme.error)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testOk ? AppTheme.success : AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_sync_rounded),
                    label: const Text('Testuj polaczenie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Zapisz'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Wskazowki:\n'
              '• Dev: odpal backend lokalnie (python app.py) na tym samym WiFi i wpisz http://<IP-kompa>:5100\n'
              '• Produkcja: https://booth.akces360.pl\n'
              '• W admin panelu backendu utworz event, przypisz ramke+muzyke, aktywuj\n'
              '• Station synchronizuje sie co 30 sekund',
              style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 12),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
