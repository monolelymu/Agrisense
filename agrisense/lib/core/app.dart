import 'package:flutter/material.dart';
import '../data/models.dart';
import '../features/device/device_screen.dart';
import '../features/diagnosis/diagnosis_screen.dart';
import '../features/history/history_screen.dart';
import '../features/monitoring/alerts_screen.dart';
import '../features/monitoring/dashboard_screen.dart';
import '../features/monitoring/stress_screen.dart';
import '../features/monitoring/trends_screen.dart';
import '../features/settings/settings_screen.dart';
import 'app_controller.dart';
import 'theme.dart';
import 'widgets.dart';

class AgriSenseApp extends StatelessWidget {
  const AgriSenseApp({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AgriSense',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: AppShell(controller: controller),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, this.onScanLeaf, super.key});
  final AppController controller;
  final VoidCallback? onScanLeaf;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  static const labels = [
    'Dashboard',
    'Trends',
    'Devices',
    'History',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.show_chart,
    Icons.router_outlined,
    Icons.history,
    Icons.tune,
  ];
  void devices() => setState(() => index = 2);
  void detail(String title, Widget Function() content) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: Column(
                children: [
                  _StatusBar(controller: widget.controller),
                  Expanded(child: content()),
                ],
              ),
            ),
          ),
        ),
      );
  void diagnosis(DiseaseResult? result) =>
      detail('Diagnosis', () => DiagnosisScreen(result: result));
  void alerts() => detail(
    'Alerts',
    () => AlertsScreen(
      controller: widget.controller,
      onResult: diagnosis,
      onDevices: () {
        Navigator.pop(context);
        devices();
      },
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.ready) {
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: c.busy
                    ? const CircularProgressIndicator()
                    : EmptyState(
                        'Local data could not be loaded',
                        c.error ?? 'Try opening the demo again.',
                        action: FilledButton(
                          onPressed: c.initialize,
                          child: const Text('Retry loading'),
                        ),
                      ),
              ),
            ),
          ),
        );
      }
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final page = switch (index) {
        1 => TrendsScreen(controller: c),
        2 => DeviceScreen(controller: c),
        3 => HistoryScreen(controller: c, onResult: diagnosis),
        4 => SettingsScreen(controller: c),
        _ => DashboardScreen(
          controller: c,
          onScanLeaf: widget.onScanLeaf,
          onDevices: devices,
          onStress: () =>
              detail('Stress score', () => StressScreen(controller: c)),
          onAlerts: alerts,
        ),
      };
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa, color: accent),
              SizedBox(width: 10),
              Text(
                'agri',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              Text(
                'sense',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -.8,
                ),
              ),
            ],
          ),
          actions: [
            if (MediaQuery.sizeOf(context).width > 440)
              const Tag('MOCK WORKSPACE'),
            IconButton(
              tooltip: 'Diagnosis results',
              onPressed: () {
                final items = c.results.where((r) => r.crop == c.selectedCrop);
                diagnosis(items.isEmpty ? null : items.last);
              },
              icon: const Icon(Icons.document_scanner_outlined),
            ),
            IconButton(
              tooltip: 'Alerts',
              onPressed: alerts,
              icon: Badge(
                isLabelVisible: c.activeAlerts(c.selectedCrop).isNotEmpty,
                child: const Icon(Icons.notifications_none),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Column(
          children: [
            _StatusBar(controller: c),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      extended: true,
                      backgroundColor: background,
                      selectedIndex: index,
                      onDestinationSelected: (v) => setState(() => index = v),
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: Text(
                          'WORKSPACE',
                          style: TextStyle(
                            color: muted,
                            letterSpacing: 2,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      destinations: [
                        for (var i = 0; i < labels.length; i++)
                          NavigationRailDestination(
                            icon: Icon(icons[i]),
                            label: Text(labels[i]),
                          ),
                      ],
                    ),
                  if (wide) const VerticalDivider(width: 1),
                  Expanded(child: page),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (v) => setState(() => index = v),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                ],
              ),
      );
    },
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (controller.busy) ...[
        const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            controller.activity,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
      ],
      if (controller.error != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          color: const Color(0xFF503626),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.warning_amber, color: warning),
              Text(controller.error!, style: const TextStyle(color: warning)),
              TextButton(
                onPressed: controller.busy ? null : controller.retrySave,
                child: const Text('Retry saving'),
              ),
            ],
          ),
        ),
    ],
  );
}
