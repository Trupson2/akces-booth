import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../services/backend_client.dart';
import '../services/event_manager.dart';
import '../services/local_server.dart';
import '../services/mock_services.dart';
import '../services/pin_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import 'backend_setup_screen.dart';
import 'bt_setup_screen.dart';
import 'debug_panel_screen.dart';
import 'pin_entry_screen.dart';
import 'pin_setup_screen.dart';

/// Settings chroniony PIN-em (brama w IdleScreen). Zgodne z WORKFLOW.md:
/// biezacy event, muzyka fallback, parametry nagrywania, polaczenia,
/// statystyki, zmiana PIN, wylogowanie.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityStatus>();
    final sm = context.watch<AppStateMachine>();
    final server = context.watch<LocalServer>();
    final backend = context.watch<BackendClient>();
    final events = context.watch<EventManager>();
    final settings = context.watch<SettingsStore>();

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
              _Row(
                'Nazwa',
                events.hasActiveEvent
                    ? events.activeEvent!.name
                    : 'Brak aktywnego eventu',
              ),
              _Row(
                'Data',
                events.hasActiveEvent
                    ? (events.activeEvent!.eventDate ?? '-')
                    : '-',
              ),
              _Row('Nagrano filmow',
                  '${events.hasActiveEvent ? events.videoCount : sm.videoCount}'),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => events.syncNow(),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sync teraz'),
                  ),
                ],
              ),
            ],
          ),
          _MusicSection(settings: settings, events: events),
          _RecordingParamsSection(settings: settings),
          _Section(
            title: '☁️ BACKEND (Akces Booth API)',
            children: [
              _BackendRow(backend: backend, events: events),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BackendSetupScreen(),
                  ),
                ),
                icon: const Icon(Icons.settings_rounded),
                label: Text(backend.isConfigured
                    ? 'Zmien URL / klucz API'
                    : 'Skonfiguruj backend'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          _Section(
            title: '📡 ADRES STATION (dla Recorder)',
            children: [
              _ServerInfoRow(server: server),
            ],
          ),
          _ConnectionsSection(
            conn: conn,
            backend: backend,
            server: server,
          ),
          _StatsSection(
            sm: sm,
            server: server,
            events: events,
          ),
          _SecuritySection(),
          _Section(
            title: '🛠 DEV',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bug_report_rounded,
                    color: AppTheme.muted),
                title: const Text('Debug panel',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text(
                  'logi, pending uploads, statusy polaczen, IP',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.muted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DebugPanelScreen(),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.refresh_rounded,
                    color: AppTheme.muted),
                title: const Text('Reset state machine (IDLE)',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () {
                  sm.debugReset();
                  Navigator.of(context).maybePop();
                },
              ),
            ],
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

class _ServerInfoRow extends StatelessWidget {
  const _ServerInfoRow({required this.server});
  final LocalServer server;

  @override
  Widget build(BuildContext context) {
    final ip = server.localIp ?? '?';
    final running = server.isRunning;
    final connected = server.isRecorderConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              running ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: running ? AppTheme.success : AppTheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    running ? 'Serwer dziala' : 'Serwer wylaczony',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    connected
                        ? 'Recorder polaczony'
                        : 'Recorder nie jest polaczony',
                    style: TextStyle(
                      color: connected ? AppTheme.success : AppTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CopyableValue(label: 'IP', value: ip),
        const SizedBox(height: 6),
        _CopyableValue(label: 'Port', value: '${server.port}'),
        const SizedBox(height: 6),
        _CopyableValue(label: 'WebSocket', value: server.webSocketUrl),
        const SizedBox(height: 10),
        Text(
          'W Recorder -> Ustawienia polacz -> wpisz IP: $ip (port ${server.port}).',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _CopyableValue extends StatelessWidget {
  const _CopyableValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Skopiuj',
          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.muted),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('Skopiowano: $value'),
                duration: const Duration(seconds: 2),
              ));
          },
        ),
      ],
    );
  }
}

class _BackendRow extends StatelessWidget {
  const _BackendRow({required this.backend, required this.events});
  final BackendClient backend;
  final EventManager events;

  @override
  Widget build(BuildContext context) {
    final ok = backend.isConfigured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: ok ? AppTheme.success : AppTheme.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ok ? backend.baseUrl : 'Brak konfiguracji',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    events.hasActiveEvent
                        ? 'Aktywny event: ${events.activeEvent!.name} '
                            '(${events.videoCount} filmow)'
                        : (events.lastError ?? 'Brak aktywnego eventu'),
                    style: TextStyle(
                      color: events.hasActiveEvent
                          ? AppTheme.success
                          : AppTheme.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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

class _MusicSection extends StatelessWidget {
  const _MusicSection({required this.settings, required this.events});
  final SettingsStore settings;
  final EventManager events;

  static const _options = [
    'Wesele Classical',
    'Energetic Party',
    'Chill Vibe',
    'Random',
  ];

  @override
  Widget build(BuildContext context) {
    final activeFromEvent = events.hasActiveEvent &&
        events.activeEvent!.musicId != null;
    return _Section(
      title: '🎵 MUZYKA (FALLBACK)',
      children: [
        if (activeFromEvent)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Event ma przypisana muzyke - fallback uzywany tylko '
              'gdy event zniknie.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
        for (final opt in _options)
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: opt,
            groupValue: settings.fallbackMusic,
            onChanged: (v) {
              if (v != null) settings.setFallbackMusic(v);
            },
            title: Text(opt,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            activeColor: AppTheme.primary,
          ),
      ],
    );
  }
}

class _RecordingParamsSection extends StatelessWidget {
  const _RecordingParamsSection({required this.settings});
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    // Push nowej konfiguracji do Recordera po kazdej zmianie - bez tego
    // Recorder widzi stara wartosc az do nastepnego syncNow (30s).
    void pushConfig() {
      try {
        context.read<EventManager>().pushRecorderConfig();
      } catch (e) {
        debugPrint('[Settings] pushRecorderConfig fail: $e');
      }
    }
    Future<void> setDuration(int s) async {
      await settings.setVideoDuration(s);
      pushConfig();
    }
    Future<void> setResolution(String v) async {
      await settings.setResolution(v);
      pushConfig();
    }
    Future<void> setZoom(double v) async {
      await settings.setZoomLevel(v);
      pushConfig();
    }
    Future<void> setStabilize(bool v) async {
      await settings.setStabilize(v);
      pushConfig();
    }
    Future<void> setSlowmo(double v) async {
      await settings.setSlowMoFactor(v);
      pushConfig();
    }
    Future<void> setRotDir(String v) async {
      await settings.setRotationDir(v);
      pushConfig();
    }
    Future<void> setRotSpeed(int v) async {
      await settings.setRotationSpeed(v);
      pushConfig();
    }

    return _Section(
      title: '⚙️ PARAMETRY NAGRYWANIA',
      children: [
        _StepperRow(
          label: 'Dlugosc filmu',
          value: '${settings.videoDurationSec}s',
          onMinus: () => setDuration(settings.videoDurationSec - 1),
          onPlus: () => setDuration(settings.videoDurationSec + 1),
        ),
        _DropdownRow<String>(
          label: 'Rozdzielczosc',
          value: settings.resolution,
          items: const [
            ('fullHd', 'Full HD 1080p (szybko)'),
            ('uhd4k', '4K (wolniej, premium)'),
          ],
          onChanged: setResolution,
        ),
        _DropdownRow<double>(
          label: 'Zoom',
          value: settings.zoomLevel,
          items: const [
            (0.6, '0.6x (ultrawide, wiecej kadru)'),
            (1.0, '1.0x (normalny)'),
            (2.0, '2.0x (tele, blizej)'),
          ],
          onChanged: setZoom,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: settings.stabilize,
          onChanged: setStabilize,
          activeThumbColor: AppTheme.primary,
          title: const Text('Stabilizacja wideo (post-process)',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text(
            'FFmpeg deshake - kompensacja drgan motoru. +15-25% czasu renderu.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ),
        _DropdownRow<double>(
          label: 'Slow-motion',
          value: settings.slowMoFactor,
          items: const [
            (1.0, '1x (bez)'),
            (2.0, '2x'),
            (4.0, '4x'),
          ],
          onChanged: setSlowmo,
        ),
        _DropdownRow<String>(
          label: 'Kierunek obrotu',
          value: settings.rotationDir,
          items: const [
            ('cw', 'W prawo'),
            ('ccw', 'W lewo'),
            ('mixed', 'Zmienny'),
          ],
          onChanged: setRotDir,
        ),
        _StepperRow(
          label: 'Predkosc obrotu',
          value: '${settings.rotationSpeed}/10',
          onMinus: () => setRotSpeed(settings.rotationSpeed - 1),
          onPlus: () => setRotSpeed(settings.rotationSpeed + 1),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: settings.fbDefaultOn,
          onChanged: (v) => settings.setFbDefault(v),
          activeThumbColor: AppTheme.primary,
          title: const Text('Domyslnie zgoda na FB',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text(
            'Checkbox na QR screen bedzie wstepnie zaznaczony',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 14)),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline,
                color: AppTheme.muted),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 64,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.muted),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 14)),
          ),
          DropdownButton<T>(
            value: value,
            dropdownColor: AppTheme.surface,
            underline: const SizedBox.shrink(),
            iconEnabledColor: AppTheme.muted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            items: [
              for (final (v, label) in items)
                DropdownMenuItem<T>(value: v, child: Text(label)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ConnectionsSection extends StatefulWidget {
  const _ConnectionsSection({
    required this.conn,
    required this.backend,
    required this.server,
  });
  final ConnectivityStatus conn;
  final BackendClient backend;
  final LocalServer server;

  @override
  State<_ConnectionsSection> createState() => _ConnectionsSectionState();
}

class _ConnectionsSectionState extends State<_ConnectionsSection> {
  bool _testing = false;
  String? _testResult;

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final ok = await widget.backend.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok
          ? '✅ Backend online (healthz 200)'
          : '❌ Brak odpowiedzi backendu';
    });
  }

  @override
  Widget build(BuildContext context) {
    final conn = widget.conn;
    return _Section(
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
          label: 'OnePlus 13 (Recorder)',
          ok: widget.server.isRecorderConnected || conn.recorderOnline,
          okText: widget.server.isRecorderConnected
              ? 'WS polaczony'
              : '192.168.1.45 (mock)',
          failText: 'Offline',
        ),
        _StatusRow(
          label: 'Internet',
          ok: conn.internetOnline,
          okText: widget.backend.isConfigured
              ? widget.backend.baseUrl
              : 'booth.akces360.pl (mock)',
          failText: 'Offline',
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check_rounded, size: 16),
              label: Text(_testing ? 'Testuje...' : 'Test polaczenia'),
            ),
            const SizedBox(width: 12),
            if (_testResult != null)
              Expanded(
                child: Text(
                  _testResult!,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.sm,
    required this.server,
    required this.events,
  });
  final AppStateMachine sm;
  final LocalServer server;
  final EventManager events;

  @override
  Widget build(BuildContext context) {
    final videos = events.hasActiveEvent ? events.videoCount : sm.videoCount;
    final recorderBattery = server.lastRecorderBattery;
    final recorderDiskGb = server.lastRecorderDiskFreeGb;
    return _Section(
      title: '📊 DZISIEJSZE STATYSTYKI',
      children: [
        _Row('Nagrano filmow', '$videos'),
        _StationBatteryRow(),
        _Row('Bateria OnePlus',
            recorderBattery != null ? '$recorderBattery%' : '-'),
        _Row('Wolny dysk',
            recorderDiskGb != null ? '${recorderDiskGb.toStringAsFixed(1)} GB' : '-'),
        _Row(
          'Aktywna sesja',
          server.isRecorderConnected ? 'Recorder online' : 'Recorder offline',
        ),
      ],
    );
  }
}

/// Bateria samego Stationa (tableta/S21) - battery_plus, refresh co 30s.
class _StationBatteryRow extends StatefulWidget {
  @override
  State<_StationBatteryRow> createState() => _StationBatteryRowState();
}

class _StationBatteryRowState extends State<_StationBatteryRow> {
  final Battery _battery = Battery();
  int? _level;
  BatteryState _state = BatteryState.unknown;
  Timer? _timer;
  StreamSubscription<BatteryState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    _stateSub = _battery.onBatteryStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      _refresh();
    });
  }

  Future<void> _refresh() async {
    try {
      final lvl = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() => _level = lvl.clamp(0, 100));
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_level == null) return _Row('Bateria Station', '...');
    final charging = _state == BatteryState.charging ? ' (ladowanie)' : '';
    return _Row('Bateria Station', '$_level%$charging');
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '🔒 PIN & SESJA',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.vpn_key_rounded, color: AppTheme.muted),
          title: const Text('Zmien PIN',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text('Najpierw wpisz obecny PIN',
              style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppTheme.muted),
          onTap: () => _changePin(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
          title: const Text('Wyloguj',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text(
            'Wyczysc PIN - przy nastepnym wejsciu trzeba go ustawic ponownie',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          onTap: () => _logout(context),
        ),
      ],
    );
  }

  Future<void> _changePin(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinEntryScreen()),
    );
    if (ok != true || !context.mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinSetupScreen(
          title: 'Nowy PIN',
          subtitle: 'Wpisz nowy 4-cyfrowy PIN',
          closable: true,
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Wyloguj?'),
        content: const Text(
          'Wyczyscimy PIN. Przy nastepnym wejsciu do Settings '
          'poprosimy o ustawienie nowego PIN-u.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Wyloguj'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await context.read<PinService>().reset();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
