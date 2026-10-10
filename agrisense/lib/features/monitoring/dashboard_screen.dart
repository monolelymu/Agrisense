import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.controller,
    required this.onDevices,
    required this.onStress,
    required this.onAlerts,
    super.key,
  });
  final AppController controller;
  final VoidCallback onDevices, onStress, onAlerts;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final crop = c.selectedCrop;
    final r = c.latest(crop);
    final score = c.score(crop).value;
    final stressed = score >= c.settingsFor(crop).threshold;
    final sensorConnected = c.connected(crop, NodeKind.sensor);
    return PageBody(
      children: [
        const SectionTitle(
          'A closer look at your crops.',
          'Your growing conditions, all in one place.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C4933), Color(0xFF1C3026)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF47614A)),
          ),
          child: Wrap(
            spacing: 26,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.spa_outlined, color: accent, size: 64),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Tag('AGRISENSE / DEMO WORKSPACE'),
                  const SizedBox(height: 14),
                  Text(
                    'Small signals.\nBetter understanding.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Three crops. A guided preview of connected growing.',
                    style: TextStyle(color: Color(0xFFD0DECF), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                'Your crop setups',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Tag('${Crop.values.length} SIMULATED'),
          ],
        ),
        const SizedBox(height: 14),
        MetricGrid(
          minWidth: 310,
          children: [
            for (final item in Crop.values)
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => c.selectCrop(item),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            switch (item) {
                              Crop.tomato => Icons.eco,
                              Crop.chili => Icons.local_florist,
                              Crop.eggplant => Icons.grass,
                            },
                            color: switch (item) {
                              Crop.tomato => const Color(0xFFF09980),
                              Crop.chili => accent,
                              Crop.eggplant => const Color(0xFFD2B4F5),
                            },
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (crop == item)
                            const Icon(Icons.check_circle, color: accent),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            '${c.score(item).value}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const Text(
                            ' / 100 stress',
                            style: TextStyle(color: muted),
                          ),
                          const Spacer(),
                          Icon(
                            c.connected(item, NodeKind.sensor)
                                ? Icons.sensors
                                : Icons.sensors_off,
                            color: muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        c.connected(item, NodeKind.sensor)
                            ? 'Simulated Sensor Node connected'
                            : 'Saved sample • Sensor Node disconnected',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${crop.label} overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Tag('MOCK READINGS'),
            Text(
              'Last sample ${dateLabel(r.timestamp)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        MetricGrid(
          children: [
            _Metric(
              'Soil moisture',
              '${r.soil.toStringAsFixed(0)}%',
              Icons.water_drop_outlined,
              'Demo moisture level',
            ),
            _Metric(
              'Temperature',
              c.temperature(r.temperature),
              Icons.thermostat_outlined,
              'Air temperature',
            ),
            _Metric(
              'Humidity',
              '${r.humidity.toStringAsFixed(0)}%',
              Icons.air,
              'Relative humidity',
            ),
            _Metric(
              'Gas / VOC',
              '${r.gas.toStringAsFixed(0)} raw',
              Icons.blur_on,
              'Uncalibrated gas reading',
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (c.activeAlerts(crop).isNotEmpty) ...[
          Panel(
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.warning_amber, color: warning),
                Text(
                  '${crop.label}: demo stress threshold crossed.',
                  style: const TextStyle(color: warning),
                ),
                TextButton(
                  onPressed: onAlerts,
                  child: const Text('Review alert →'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stress at a glance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '$score/100',
                    style: TextStyle(
                      color: stressed ? warning : accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: stressed ? warning : accent,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    stressed
                        ? 'Attention • outside demo ranges'
                        : 'Within demo ranges',
                    style: TextStyle(color: stressed ? warning : muted),
                  ),
                  TextButton(
                    onPressed: onStress,
                    child: const Text('Explore sensor contributions →'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Tag('TRY THE GUIDED DEMO'),
              const SizedBox(height: 12),
              Text(
                'See what happens when conditions change.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                sensorConnected
                    ? 'Record a normal sample, then simulate stress. Connect the Vision Node to also produce a mock diagnosis.'
                    : 'Start by connecting the simulated nodes. No Bluetooth, camera, or Wi-Fi permissions are used.',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onDevices,
                    icon: const Icon(Icons.router_outlined),
                    label: const Text('Set up devices'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: c.busy || !sensorConnected
                        ? null
                        : () => c.sample(stressed: false),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Normal sample'),
                  ),
                  FilledButton.icon(
                    onPressed: c.busy || !sensorConnected
                        ? null
                        : () => c.sample(stressed: true),
                    icon: const Icon(Icons.bolt),
                    label: const Text('Simulate stress'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'PROTOTYPE ONLY • Stress ranges and results are illustrative, not validated agricultural advice.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.icon, this.caption);
  final String title, value, caption;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 24),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(color: muted)),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(caption, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    ),
  );
}
