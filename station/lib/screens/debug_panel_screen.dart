import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/backend_client.dart';
import '../services/event_manager.dart';
import '../services/local_server.dart';
import '../services/logger.dart';
import '../services/mock_services.dart';
import '../services/nearby_server.dart';
import '../services/pending_uploads.dart';
import '../theme/app_theme.dart';

/// Sesja 8a Block 3: rozszerzony debug panel z logami, pending uploads,
/// statusami polaczen i szybkimi akcjami.
class DebugPanelScreen extends StatelessWidget {
  const DebugPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final server = context.watch<LocalServer>();
    final nearby = context.watch<NearbyServer>();
    final backend = context.watch<BackendClient>();
    final events = context.watch<EventManager>();
    final conn = context.watch<ConnectivityStatus>();
    final pending = context.watch<PendingUploadsService>();
    final logger = context.watch<BoothLogger>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Debug Panel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '📡 POLACZENIA',
            children: [
              _KV('BT (fotobudka)', conn.bluetoothReady ? '✅ OK' : '❌ offline'),
              _KV('Recorder Nearby',
                  nearby.isRecorderConnected
                      ? '✅ connected'
                      : '⏳ ${nearby.state.name}'),
              _KV('Internet',
                  conn.internetOnline ? '✅ online' : '❌ offline'),
              _KV('Backend',
                  backend.isConfigured ? '✅ skonfigurowany' : '❌ brak'),
              if (backend.isConfigured)
                _KV('  URL', backend.baseUrl, copyable: true),
              _KV('Station IP (local HTTP)',
                  server.localIp ?? '-', copyable: server.localIp != null),
              _KV('Local HTTP port', '${server.port}'),
              _KV('Local HTTP running',
                  server.isRunning ? '✅' : '❌ (restart apki?)'),
            ],
          ),

          _Section(
            title: '📱 RECORDER (status push co 30s)',
            children: [
              _KV('Bateria',
                  nearby.lastRecorderBattery != null
                      ? '${nearby.lastRecorderBattery}%'
                      : '-'),
              _KV('Wolny dysk',
                  nearby.lastRecorderDiskFreeGb != null
                      ? '${nearby.lastRecorderDiskFreeGb!.toStringAsFixed(1)} GB'
                      : '-'),
            ],
          ),

          _Section(
            title: '🎬 EVENT',
            children: [
              _KV('Aktywny',
                  events.hasActiveEvent ? events.activeEvent!.name : '-'),
              if (events.hasActiveEvent)
                _KV('  ID', '${events.activeEvent!.id}'),
              _KV('Licznik filmow', '${events.videoCount}'),
              if (events.lastError != null)
                _KV('Ostatni blad', events.lastError!),
            ],
          ),

          _PendingUploadsSection(pending: pending),

          _LogsSection(logger: logger),

          const SizedBox(height: 32),
          const Text(
            'Tip: logi sa takze zapisywane do pliku '
            'docs/logs/booth_YYYY-MM-DD.log (rotacja 7 dni).',
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.label, this.value, {this.copyable = false});
  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          ),
          Expanded(
            flex: 5,
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text('Skopiowano: $value'),
                    duration: const Duration(seconds: 2),
                  ));
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.copy_rounded,
                    size: 14, color: AppTheme.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingUploadsSection extends StatelessWidget {
  const _PendingUploadsSection({required this.pending});
  final PendingUploadsService pending;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '📤 PENDING UPLOADS (${pending.length})',
      children: [
        if (!pending.hasAny)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Kolejka pusta - wszystkie filmy zsynchronizowane.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          )
        else ...[
          for (final p in pending.queue)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.remoteShortId != null
                      ? AppTheme.success.withValues(alpha: 0.08)
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: p.remoteShortId != null
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.localShortId,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (p.remoteShortId != null)
                          Text(
                            '→ ${p.remoteShortId}',
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          )
                        else
                          Text(
                            'proby: ${p.attemptCount}',
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    if (p.lastError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          p.lastError!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => pending.retryAll(),
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Spróbuj ponownie wszystkie'),
          ),
        ],
      ],
    );
  }
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({required this.logger});
  final BoothLogger logger;

  @override
  Widget build(BuildContext context) {
    final recent = logger.recent.reversed.take(40).toList();
    return _Section(
      title: '📋 LOGI (ostatnie 40)',
      children: [
        if (recent.isEmpty)
          const Text('Brak wpisow.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12))
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView(
              children: [
                for (final e in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      e.toLine(),
                      style: TextStyle(
                        color: _colorForLevel(e.level),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final txt = await logger.dumpRecentToString();
                if (txt != null) {
                  Clipboard.setData(ClipboardData(text: txt));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(
                        content: Text('Logi skopiowane do schowka'),
                        duration: Duration(seconds: 2),
                      ));
                  }
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Kopiuj logi'),
            ),
          ],
        ),
      ],
    );
  }

  Color _colorForLevel(LogLevel l) {
    switch (l) {
      case LogLevel.debug:
        return AppTheme.muted;
      case LogLevel.info:
        return Colors.white70;
      case LogLevel.warn:
        return AppTheme.warning;
      case LogLevel.error:
        return AppTheme.error;
    }
  }
}
