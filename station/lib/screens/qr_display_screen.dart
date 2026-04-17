import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_widget.dart';
import '../widgets/scan_instructions.dart';

class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  bool _initializedFb = false;

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();
    final settings = context.watch<SettingsStore>();
    final job = sm.currentJob;

    // Pierwsze wejscie: przenies default z SettingsStore do joba.
    if (!_initializedFb && job != null) {
      _initializedFb = true;
      if (settings.fbDefaultOn != job.publishToFacebook) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          sm.setPublishToFacebook(settings.fbDefaultOn);
        });
      }
    }

    // publicUrl z backendu moze byc juz pelny "https://..." albo tylko host/path.
    final rawUrl = job?.publicUrl ?? 'booth.akces360.pl/v/MOCK12';
    final fullUrl = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
    final url = rawUrl.replaceAll(RegExp(r'^https?://'), '');

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final qrSize = (h * 0.7).clamp(180.0, 360.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Lewa strona: QR
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: QrWidget(data: fullUrl, size: qrSize),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Prawa strona: tekst + countdown + next button
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 34)),
                          const SizedBox(height: 4),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Twoj film jest gotowy!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const ScanInstructions(),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              url,
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _FacebookOptInTile(
                            value: job?.publishToFacebook ?? false,
                            onChanged: sm.setPublishToFacebook,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: AppTheme.muted, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Nastepny gosc za: ${sm.qrCountdownSeconds}s',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: sm.nextGuest,
                            icon: const Icon(Icons.skip_next_rounded, size: 18),
                            label: const Text('Nastepny gosc'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Opt-in checkbox: zgoda na publikacje filmu na Facebook @akces360.
/// Flaga idzie do backendu w headers (X-Publish-Facebook).
class _FacebookOptInTile extends StatelessWidget {
  const _FacebookOptInTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF1877F2).withValues(alpha: 0.12)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? const Color(0xFF1877F2)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: const Color(0xFF1877F2),
              visualDensity: VisualDensity.compact,
            ),
            const Icon(Icons.facebook_rounded,
                color: Color(0xFF1877F2), size: 20),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Zgadzam sie na publikacje filmu na\nFacebook: @akces360',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
