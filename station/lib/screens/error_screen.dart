import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../theme/app_theme.dart';
import '../widgets/big_action_button.dart';

/// Wyswietlany gdy AppStateMachine wchodzi w AppState.error.
/// Gosc/operator decyduje: "Sprobuj ponownie" albo "Anuluj (wroc)".
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lekkie czerwone tlo - bez paniki, ale wyraznie.
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0x33EF4444),
                  Color(0xFF0F172A),
                ],
                radius: 1.3,
                center: Alignment(0, -0.2),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Ikona
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.error,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tytul
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      sm.errorTitle.isEmpty ? 'Cos poszlo nie tak' : sm.errorTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Opis
                  Text(
                    sm.errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Debug info - ktory stan wywolal error
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'stan: ${sm.errorFrom.name}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Akcje
                  LayoutBuilder(
                    builder: (context, _) {
                      final screenH = MediaQuery.of(context).size.height;
                      final btnH = (screenH * 0.14).clamp(72.0, 110.0);
                      return Row(
                        children: [
                          Expanded(
                            child: BigActionButton(
                              label: 'SPROBUJ PONOWNIE',
                              icon: Icons.refresh_rounded,
                              color: AppTheme.success,
                              height: btnH,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                sm.retryFromError();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: BigActionButton(
                              label: 'ANULUJ',
                              icon: Icons.close_rounded,
                              color: AppTheme.surfaceLight,
                              height: btnH,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                sm.cancelFromError();
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Footer hint
                  const Text(
                    'Problem sie powtarza? Przytrzymaj logo Akces 360 '
                    'w IDLE zeby otworzyc logi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
