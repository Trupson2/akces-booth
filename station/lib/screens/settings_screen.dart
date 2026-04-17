import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../services/mock_services.dart';
import '../theme/app_theme.dart';
import 'bt_setup_screen.dart';

/// Placeholder Settings - PIN protection dorzucimy w Sesji 9.
/// Na razie otwiera sie bezposrednio po long-press na "Ustawienia" w footerze.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityStatus>();
    final sm = context.watch<AppStateMachine>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Ustawienia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Section(
            title: '🎬 BIEZACY EVENT',
            children: [
              _Row('Nazwa', 'Wesele Demo (placeholder)'),
              _Row('Data', '17.04.2026'),
              _Row('Nagrano filmow', '${sm.videoCount}'),
            ],
          ),
          _Section(
            title: '⚙️ PARAMETRY NAGRYWANIA',
            children: const [
              _Row('Dlugosc filmu', '8 sekund'),
              _Row('Slow-motion', '2x (post-process)'),
              _Row('Predkosc obrotu', '7/10'),
              _Row('Kierunek', 'Zmienny'),
            ],
          ),
          _Section(
            title: '🔗 POLACZENIA',
            children: [
              _StatusRow(
                label: 'Fotobudka BT',
                ok: conn.bluetoothReady,
                okText: 'YCKJNB-MOCK',
                failText: 'Brak pary',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BtSetupScreen(),
                  ),
                ),
              ),
              _StatusRow(
                label: 'OnePlus 13',
                ok: conn.recorderOnline,
                okText: '192.168.1.45 (mock)',
                failText: 'Offline',
              ),
              _StatusRow(
                label: 'Internet',
                ok: conn.internetOnline,
                okText: 'booth.akces360.pl (mock)',
                failText: 'Offline',
              ),
            ],
          ),
          _Section(
            title: '🛠 DEV',
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded,
                    color: AppTheme.muted),
                title: const Text('Reset state machine (IDLE)'),
                onTap: () {
                  sm.debugReset();
                  Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'TODO (Sesja 9): PIN protection, event management, music picker, '
            'statystyki online.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ok,
    required this.okText,
    required this.failText,
    this.onTap,
  });

  final String label;
  final bool ok;
  final String okText;
  final String failText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: ok ? AppTheme.success : AppTheme.error,
      ),
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(
        ok ? okText : failText,
        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
    );
  }
}
