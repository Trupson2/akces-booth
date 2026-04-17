import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/motor_controller.dart';
import '../theme/app_theme.dart';

/// Placeholder parowania fotobudki BT (Sesja 4+).
class BtSetupScreen extends StatelessWidget {
  const BtSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Parowanie fotobudki'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  motor.isConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_searching_rounded,
                  size: 48,
                  color: motor.isConnected
                      ? AppTheme.success
                      : AppTheme.muted,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        motor.isConnected
                            ? 'Polaczono z ${motor.connectedDeviceName ?? "?"}'
                            : 'Brak pary',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        motor.isScanning
                            ? 'Skanowanie...'
                            : 'Wlacz fotobudke i kliknij "Skanuj"',
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: motor.isScanning
                  ? null
                  : () async {
                      await motor.scanForDevices();
                      if (context.mounted) {
                        await motor.connectTo('mock-device');
                      }
                    },
              icon: motor.isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bluetooth_rounded),
              label: Text(
                motor.isConnected
                    ? 'Rozlacz'
                    : (motor.isScanning ? 'Skanuje...' : 'Skanuj i polacz'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (motor.isConnected) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: motor.disconnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Rozlacz'),
              ),
            ],
            const SizedBox(height: 32),
            const Text(
              'TODO (Sesja 4): flutter_blue_plus, prawdziwy scan YCKJNB-*, '
              'pamietanie ostatniego urzadzenia, auto-reconnect.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
