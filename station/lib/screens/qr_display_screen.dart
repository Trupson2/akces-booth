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
                          const Text('🎉', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 6),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Twoj film jest gotowy!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Icon(Icons.phone_android_rounded,
                                  color: AppTheme.muted, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Zeskanuj aparatem telefonu',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 16),
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
