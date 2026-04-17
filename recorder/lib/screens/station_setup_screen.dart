import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/station_client.dart';
import '../theme/app_theme.dart';

/// Konfiguracja adresu Station (IP + port) + test polaczenia.
class StationSetupScreen extends StatefulWidget {
  const StationSetupScreen({super.key});

  @override
  State<StationSetupScreen> createState() => _StationSetupScreenState();
}

class _StationSetupScreenState extends State<StationSetupScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final client = context.read<StationClient>();
    _ipCtrl.text = client.ip ?? '';
    _portCtrl.text = client.port.toString();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;
    if (ip.isEmpty) {
      setState(() {
        _testOk = false;
        _testResult = 'Wpisz IP';
      });
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final client = context.read<StationClient>();
    final ok = await client.testConnection(ip, port);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testResult = ok
          ? 'Polaczono: Station dziala'
          : 'Brak odpowiedzi (${client.lastError ?? "timeout"})';
    });
  }

  Future<void> _save() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;
    if (ip.isEmpty) return;
    final client = context.read<StationClient>();
    await client.configure(ip, port);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Zapisano: $ip:$port')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<StationClient>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Polaczenie ze Station'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  client.isConnected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  size: 28,
                  color: client.isConnected
                      ? AppTheme.success
                      : AppTheme.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    client.isConnected
                        ? 'Polaczono: ${client.httpBaseUrl}'
                        : 'Brak polaczenia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'IP Station',
              style: TextStyle(color: AppTheme.muted, fontSize: 12, letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _ipCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: _dec('np. 192.168.1.45'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Port',
              style: TextStyle(color: AppTheme.muted, fontSize: 12, letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: _dec('8080'),
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
                child: Row(
                  children: [
                    Icon(
                      _testOk
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _testOk ? AppTheme.success : AppTheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testOk ? AppTheme.success : AppTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                        : const Icon(Icons.wifi_find_rounded),
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
            const SizedBox(height: 20),
            const Text(
              'Wskazowki:\n'
              '• Station (Tab A11+) i Recorder (ten telefon) musza byc na tej samej sieci WiFi.\n'
              '• IP znajdziesz w Station -> Ustawienia -> Adres Station.\n'
              '• Port standardowy: 8080.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.muted),
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
