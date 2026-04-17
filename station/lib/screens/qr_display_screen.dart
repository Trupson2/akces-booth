import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_widget.dart';

class QrDisplayScreen extends StatelessWidget {
  const QrDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();
    final job = sm.currentJob;

    final url = job?.publicUrl ?? 'booth.akces360.pl/v/MOCK12';
    final fullUrl = 'https://$url';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              // Lewa strona: QR
              Expanded(
                flex: 4,
                child: Center(
                  child: QrWidget(data: fullUrl, size: 360),
                ),
              ),
              const SizedBox(width: 32),
              // Prawa strona: tekst + countdown + next button
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎉',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Twoj film jest\ngotowy!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.phone_android_rounded,
                            color: AppTheme.muted, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Zeskanuj aparatem telefonu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        url,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 15,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Countdown
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: AppTheme.muted, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Nastepny gosc za: ${sm.qrCountdownSeconds}s',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: sm.nextGuest,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Nastepny gosc'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
