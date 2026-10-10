import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart' as models;

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final crop = c.selectedCrop;
    final nodes = c.discovered[crop] ?? [];
    return PageBody(
      children: [
        const SectionTitle(
          'Your connected garden',
          'Pair the nodes that bring your crop data together.',
        ),
        CropPicker(value: crop, onChanged: c.selectCrop),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Tag('SIMULATED CONNECTIONS'),
              const SizedBox(height: 14),
              Text(
                '${crop.label} node pair',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'This demo does not scan real Bluetooth or Wi-Fi devices. Each crop has its own virtual node pair; the physical build currently has one pair.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: c.busy ? null : c.scan,
                icon: const Icon(Icons.radar),
                label: Text(
                  nodes.isEmpty ? 'Scan simulated nodes' : 'Scan again',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (nodes.isEmpty)
          const EmptyState(
            'Ready to discover',
            'Tap Scan simulated nodes to find the Sensor Node and Vision Node.',
            icon: Icons.router_outlined,
          ),
        for (final kind in nodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        kind == models.NodeKind.sensor
                            ? Icons.sensors
                            : Icons.camera_alt_outlined,
                        color: accent,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kind == models.NodeKind.sensor
                                  ? 'Sensor Node'
                                  : 'Vision Node',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${crop.label} • ${kind == models.NodeKind.sensor ? 'BLE telemetry stub' : 'Wi-Fi image stub'}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tag(
                        'SIMULATED • ${c.device(crop, kind).state.name.toUpperCase()}',
                      ),
                      OutlinedButton(
                        onPressed: c.busy ? null : () => c.toggleDevice(kind),
                        child: Text(
                          c.connected(crop, kind)
                              ? 'Disconnect'
                              : c.device(crop, kind).state ==
                                    models.ConnectionState.connecting
                              ? 'Connecting…'
                              : 'Connect',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Connections reset when the app restarts. History remains on this browser or phone.',
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}
