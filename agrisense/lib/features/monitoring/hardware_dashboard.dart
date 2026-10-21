import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/hardware_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/hardware_client.dart';
import '../../data/models.dart';
import '../../data/alert_photo.dart';
import '../diagnosis/tomato_scan.dart';
import '../diagnosis/tomato_scan_screen.dart';
import '../diagnosis/photo_processing.dart';
import 'monitoring_settings_screen.dart';
import '../help/help_screen.dart';
import '../../core/app_issue.dart';
import '../../core/issue_card.dart';
import 'alert_detail_screen.dart';

class HardwareApp extends StatelessWidget {
  const HardwareApp({
    required this.hardware,
    required this.scans,
    this.showTutorial = true,
    super.key,
  });
  final HardwareController hardware;
  final TomatoScanStore scans;
  final bool showTutorial;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AgriSense',
    theme: buildTheme(),
    debugShowCheckedModeBanner: false,
    home: HardwareDashboard(
      hardware: hardware,
      scans: scans,
      showTutorial: showTutorial,
    ),
  );
}

class HardwareDashboard extends StatefulWidget {
  const HardwareDashboard({
    required this.hardware,
    required this.scans,
    this.showTutorial = false,
    super.key,
  });
  final HardwareController hardware;
  final TomatoScanStore scans;
  final bool showTutorial;
  @override
  State<HardwareDashboard> createState() => _HardwareDashboardState();
}

class _HardwareDashboardState extends State<HardwareDashboard>
    with WidgetsBindingObserver {
  Crop crop = Crop.tomato;
  int page = 0;
  int historyCategory = 0;
  String metric = 'Temperature';
  List<TomatoScan> scans = [];
  String? error;
  AppIssue? actionIssue;
  bool saving = false;
  int _scanRevision = -1;
  HardwareController get h => widget.hardware;
  bool get locked => saving || h.busy;
  static const tabs = ['Dashboard', 'Trends', 'Devices', 'History'];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.show_chart,
    Icons.router_outlined,
    Icons.history,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScans();
    if (widget.showTutorial && h.box.get('tutorial-complete-v1') != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tutorial();
      });
    }
  }

  Future<void> _tutorial() => h.withPollingPaused(() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (tutorialContext) => TutorialScreen(
          onDone: () async {
            try {
              await h.box.put('tutorial-complete-v1', true);
            } catch (_) {
              // The guide remains usable if its completion flag cannot be stored.
              if (tutorialContext.mounted) {
                ScaffoldMessenger.of(tutorialContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Tutorial preference could not be saved. The guide may appear again.',
                    ),
                  ),
                );
              }
            }
            if (tutorialContext.mounted) Navigator.of(tutorialContext).pop();
          },
        ),
      ),
    );
  });

  Future<void> _help() => _openSettings(HelpScreen(onReplay: _tutorial));

  void _loadScans() {
    try {
      scans = widget.scans.load();
    } catch (_) {
      error =
          'Saved scans could not be loaded. Existing records are unchanged.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    h.setForeground(
      state == AppLifecycleState.resumed,
      resetDuration:
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!h.backgroundActive) h.stopPolling();
    super.dispose();
  }

  void _crop(Crop value) {
    if (locked) return;
    final monitoring = h.polling;
    setState(() {
      crop = value;
      error = null;
      actionIssue = null;
    });
    if (monitoring)
      _saveAction(
        () => h.startMonitoring(value),
        fallback: AppIssue.background,
      );
  }

  Future<void> _scan() => h.withPollingPaused(() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TomatoScanScreen(
          store: widget.scans,
          hardware: h,
          initialCrop: crop,
        ),
      ),
    );
    if (mounted) setState(_loadScans);
  });

  Future<void> _result(TomatoScan scan) => h.withPollingPaused(() async {
    await Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text('${scan.crop.label} result')),
              body: PageBody(
                children: [
                  TomatoResultCard(scan: scan),
                  if (scan.alertId != null)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AlertDetailScreen(hardware: h, id: scan.alertId!),
                        ),
                      ),
                      child: const Text('View originating alert'),
                    ),
                ],
              ),
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  });

  Future<void> _assign(String kind) => h.withPollingPaused(() async {
    // Avoid a polling request racing with saving the address from this dialog.
    final selected = crop;
    final answer = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _NodeAssignmentDialog(
        crop: selected,
        kind: kind,
        initialAddress: h.address(selected, kind),
        existing: {
          for (final c in Crop.values)
            if (h.address(c, kind).isNotEmpty) c: h.address(c, kind),
        },
        httpEnabled: h.allowLocalHttp,
      ),
    );
    if (answer == null || !mounted) return;
    final success = await _saveAction(() {
      if (answer.$1.trim().isEmpty) return h.assign(selected, kind, '');
      return kind == 'sensor'
          ? h.configureSensor(selected, answer.$1, answer.$2)
          : h.moveCamera(selected, answer.$1);
    });
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            answer.$1.trim().isEmpty
                ? 'Assignment removed. Saved history is unchanged.'
                : '${selected.label} $kind assigned. Saved history is unchanged.',
          ),
        ),
      );
    }
  });

  Future<bool> _saveAction(
    Future<void> Function() action, {
    AppIssue fallback = AppIssue.settings,
  }) async {
    if (locked) return false;
    return h.withPollingPaused(() async {
      setState(() {
        saving = true;
        error = null;
        actionIssue = null;
      });
      try {
        await action();
        return true;
      } catch (e) {
        if (mounted) {
          actionIssue = AppIssue.from(e, fallback: fallback);
          error = e is FormatException
              ? e.message
              : 'Could not save settings. Try again.';
        }
        return false;
      } finally {
        if (mounted) setState(() => saving = false);
      }
    });
  }

  Future<void> _openSettings(Widget screen) => h.withPollingPaused(() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  });

  Future<void> _testCamera() async {
    if (locked) return;
    final selected = crop;
    Uint8List? preview;
    final success = await _saveAction(() async {
      preview = await compute(previewPhoto, await h.capture(selected));
    }, fallback: AppIssue.camera);
    if (!success || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${selected.label} camera connected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(preview!, height: 240, fit: BoxFit.contain),
            const Text(
              'Connection test only. This photo has not been diagnosed or saved.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _scanTile(TomatoScan scan) => Card(
    child: ListTile(
      title: Text('${scan.crop.label} • ${scan.displayLabel}'),
      subtitle: Text(
        '${scan.source == 'auto' ? 'Auto Scan • ' : ''}${scan.uncertain ? 'Uncertain • ' : ''}${(scan.score * 100).toStringAsFixed(1)}% model score\n${dateLabel(scan.timestamp)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _result(scan),
    ),
  );

  Widget _alertPhotoTile(AlertPhoto photo) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        leading: Image.memory(
          photo.jpeg,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
        title: Text('${photo.crop.label} • ${dateLabel(photo.timestamp)}'),
        subtitle: const Text('Sensor warning photo'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => h.withPollingPaused(() async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: Text('${photo.crop.label} warning photo'),
                ),
                body: PageBody(
                  children: [
                    Image.memory(
                      photo.jpeg,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(dateLabel(photo.timestamp)),
                    const SizedBox(height: 12),
                    Text(photo.reason),
                    const SizedBox(height: 12),
                    const Text(
                      'Photo captured after a sensor warning. No disease prediction has been run on this snapshot.',
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
  Widget _metric(String title, String value, String detail) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: muted)),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(detail),
      ],
    ),
  );

  List<Widget> _dashboard(List<TomatoScan> results) {
    final r = h.latest(crop);
    return [
      const SectionTitle(
        'A closer look at your crops.',
        'Your growing conditions, all in one place.',
      ),
      FilledButton.icon(
        onPressed: locked ? null : _scan,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Scan leaf'),
      ),
      const SizedBox(height: 20),
      MetricGrid(
        minWidth: 250,
        children: [
          for (final item in Crop.values)
            Card(
              child: ListTile(
                onTap: locked ? null : () => _crop(item),
                leading: const Icon(Icons.eco_outlined),
                title: Text(item.label),
                subtitle: Text(
                  h.latest(item) == null
                      ? 'No sensor readings'
                      : 'Saved sensor readings',
                ),
                trailing: crop == item
                    ? const Icon(Icons.check_circle, color: accent)
                    : null,
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        '${crop.label} overview',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      if (r == null)
        const EmptyState(
          'No sensor readings yet',
          'Assign a sensor IP in Devices, then tap Read sensors.',
        )
      else ...[
        Tag(h.fresh(crop) ? 'RECENT SENSOR READING' : 'SAVED SENSOR READING'),
        Text('Received ${dateLabel(r.receivedAt)}'),
        const SizedBox(height: 12),
        MetricGrid(
          children: [
            _metric(
              'Soil moisture',
              r.soil == null ? '—' : '${r.soil!.toStringAsFixed(0)}%',
              r.soilCalibrated
                  ? 'Calibrated by device'
                  : 'Uncalibrated • raw ${r.soilRaw}',
            ),
            _metric(
              'Temperature',
              r.temperature == null
                  ? '—'
                  : '${r.temperature!.toStringAsFixed(1)}°C',
              'Air temperature',
            ),
            _metric(
              'Humidity',
              r.humidity == null ? '—' : '${r.humidity!.toStringAsFixed(0)}%',
              'Relative humidity',
            ),
            _metric(
              'Gas sensor',
              '${r.gasRaw} raw',
              'Uncalibrated MQ135 ADC; not ppm',
            ),
          ],
        ),
        if (r.temperature == null || r.humidity == null)
          const Text('Temperature/humidity sensor reported a failed reading.'),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          OutlinedButton(
            onPressed:
                locked || !h.allowLocalHttp || h.address(crop, 'sensor').isEmpty
                ? null
                : () => h.refresh(crop),
            child: const Text('Read sensors'),
          ),
          TextButton(
            onPressed: locked ? null : () => setState(() => page = 2),
            child: const Text('Set up devices'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text('Latest diagnosis', style: Theme.of(context).textTheme.titleLarge),
      if (results.isEmpty)
        const Text('No saved scans for this crop yet.')
      else
        _scanTile(results.first),
    ];
  }

  List<Widget> _devices() => [
    Text(
      '${crop.label} devices',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const Text(
      'Connect your phone and boards to the same trusted Wi-Fi. Enter the IP printed by each board in Serial Monitor.',
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Allow local hardware access'),
      subtitle: const Text(
        'Allows app requests over trusted Wi-Fi. Turning this off does not stop automatic capture rules already saved on a sensor.',
      ),
      value: h.allowLocalHttp,
      onChanged: locked ? null : (v) => _saveAction(() => h.setHttpAllowed(v)),
    ),
    const SizedBox(height: 16),
    for (final kind in ['camera', 'sensor']) ...[
      Card(
        child: ListTile(
          title: Text(kind == 'camera' ? 'Camera node' : 'Sensor node'),
          subtitle: Text(
            h.address(crop, kind).isEmpty
                ? 'Not assigned'
                : h.address(crop, kind),
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: locked ? null : () => _assign(kind),
        ),
      ),
      const SizedBox(height: 12),
    ],
    const Text(
      'Select the crop above, then edit its sensor or camera. Assigning an existing board moves it from its previous crop. The sensor confirms and remembers its crop; saved history stays unchanged.',
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      onPressed:
          locked || !h.allowLocalHttp || h.address(crop, 'sensor').isEmpty
          ? null
          : () => h.refresh(crop),
      child: const Text('Test sensor and save reading'),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(h.monitoringStatus),
    ),
    if (h.status[crop] != null)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Last sensor request: ${h.status[crop]}'),
      ),
    if (h.notificationStatus != null)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(h.notificationStatus!),
      ),
    if (h.notificationIssue != null) IssueCard(issue: h.notificationIssue!),
    OutlinedButton.icon(
      onPressed: locked
          ? null
          : () => _openSettings(
              MonitoringSettingsScreen(hardware: h, crop: crop),
            ),
      icon: const Icon(Icons.notifications_outlined),
      label: const Text('Monitoring & Auto Scan'),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed:
          locked || !h.allowLocalHttp || h.address(crop, 'camera').isEmpty
          ? null
          : _testCamera,
      icon: const Icon(Icons.camera_alt_outlined),
      label: const Text('Test camera connection'),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: locked ? null : _scan,
      icon: const Icon(Icons.camera_alt_outlined),
      label: const Text('Open capture and analysis'),
    ),
    const SizedBox(height: 12),
    const Text(
      'Photo analysis: Tomato available · Chili and Eggplant coming soon.',
    ),
  ];

  double? _value(HardwareSample r) => switch (metric) {
    'Humidity' => r.humidity,
    'Soil moisture' => r.soil,
    'Gas raw' => r.gasRaw.toDouble(),
    _ => r.temperature,
  };
  double _tickStep(double value) {
    if (value <= 0) return 1;
    final base = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    for (final multiplier in [1, 2, 5, 10]) {
      if (base * multiplier >= value) return base * multiplier;
    }
    return base * 10;
  }

  String _elapsed(double minutes) => minutes >= 1440
      ? '${(minutes / 1440).toStringAsFixed(1)}d'
      : minutes >= 60
      ? '${(minutes / 60).toStringAsFixed(1)}h'
      : '${minutes.toStringAsFixed(minutes < 1 && minutes != 0 ? 1 : 0)}m';
  List<Widget> _trends() {
    final readings = h.readings(crop).where((r) => _value(r) != null).toList();
    final start = readings.isEmpty ? DateTime.now() : readings.first.receivedAt;
    final span = readings.isEmpty
        ? 1.0
        : math.max(
            1.0,
            readings.last.receivedAt.difference(start).inMilliseconds / 60000,
          );
    final xStep = _tickStep(span / 3);
    final values = readings.map((r) => _value(r)!).toList();
    final low = values.isEmpty ? 0.0 : values.reduce(math.min);
    final high = values.isEmpty ? 1.0 : values.reduce(math.max);
    final padding = math.max(
      (high - low) * .1,
      metric == 'Gas raw' ? 10.0 : 1.0,
    );
    final yStep = _tickStep((high - low + padding * 2) / 4);
    return [
      const SectionTitle(
        'Growing patterns',
        'Actual saved readings. No generated samples.',
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final name in [
            'Temperature',
            'Humidity',
            'Soil moisture',
            'Gas raw',
          ])
            ChoiceChip(
              label: Text(name),
              selected: metric == name,
              onSelected: (_) => setState(() => metric = name),
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (readings.isEmpty)
        const EmptyState(
          'No readings for this metric',
          'Read your sensor in Devices. Soil percentages require firmware calibration.',
        )
      else
        Panel(
          padding: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$metric (${metric == 'Temperature'
                    ? '°C'
                    : metric == 'Gas raw'
                    ? 'ADC'
                    : '%'})',
              ),
              const SizedBox(height: 8),
              Text('${readings.length} samples • from ${dateLabel(start)}'),
              const SizedBox(height: 8),
              const Text(
                'Horizontal axis: minutes since the first saved sample.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 320,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (span / xStep).ceil() * xStep,
                    minY: ((low - padding) / yStep).floor() * yStep,
                    maxY: ((high + padding) / yStep).ceil() * yStep,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: yStep,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          interval: yStep,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toStringAsFixed(yStep < 1 ? 1 : 0),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: xStep,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _elapsed(value),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        color: accent,
                        isCurved: false,
                        dotData: FlDotData(show: readings.length < 20),
                        spots: [
                          for (final r in readings)
                            FlSpot(
                              r.receivedAt.difference(start).inMilliseconds /
                                  60000,
                              _value(r)!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      const Text(
        'Missing measurements are omitted. Up to 5,000 recent readings per crop are retained locally.',
      ),
    ];
  }

  List<Widget> _history(List<TomatoScan> results) => [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 3; i++)
          ChoiceChip(
            label: Text(const ['Scans', 'Alerts', 'Readings'][i]),
            selected: historyCategory == i,
            onSelected: (_) => setState(() => historyCategory = i),
          ),
      ],
    ),
    const SizedBox(height: 20),
    if (historyCategory == 0) ...[
      Text(
        '${results.length} saved scans',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (results.isEmpty)
        const EmptyState(
          'No saved scans',
          'Scan a leaf to save a result for this crop.',
        ),
      for (final result in results) ...[
        _scanTile(result),
        const SizedBox(height: 12),
      ],
    ],
    if (historyCategory == 1) ...[
      for (final alert in h.alerts.where((a) => a.crop == crop)) ...[
        Card(
          child: ListTile(
            title: Text(
              '${dateLabel(alert.timestamp)} · ${alertStateLabel(alert.state)}',
            ),
            subtitle: Text(alert.reason),
            trailing: const Icon(Icons.chevron_right),
            onTap: locked
                ? null
                : () => _openSettings(
                    AlertDetailScreen(hardware: h, id: alert.id),
                  ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Text('Warning photos', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Alerts link the trigger, photo and diagnosis. Older warning photos appear below. Board SD photos stay on the camera.',
      ),
      const SizedBox(height: 16),
      if (!h.alertPhotos.any((p) => p.crop == crop) &&
          !h.alerts.any((a) => a.crop == crop))
        const EmptyState(
          'No warning photos',
          'Enable sensor alerts in Monitoring & Auto Scan to record warnings here.',
        ),
      for (final photo in h.alertPhotos.reversed.where(
        (p) => p.crop == crop && p.alertId == null,
      ))
        _alertPhotoTile(photo),
    ],
    if (historyCategory == 2) ...[
      Text(
        'Recent sensor readings',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (h.readings(crop).isEmpty)
        const EmptyState(
          'No sensor readings saved.',
          'Assign a sensor in Devices and read a sample.',
        ),
      for (final r in h.readings(crop).reversed.take(100)) ...[
        Card(
          child: ListTile(
            title: Text(dateLabel(r.receivedAt)),
            subtitle: Text(
              'Temperature ${r.temperature ?? '—'} °C · Humidity ${r.humidity ?? '—'}%\n'
              'Soil ${r.soil == null ? 'unavailable' : '${r.soil}%'} · Gas ${r.gasRaw} raw',
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      const Text(
        'Latest 100 readings shown. Trends uses all retained readings.',
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: h,
    builder: (context, _) {
      if (_scanRevision != h.revision) {
        _loadScans();
        _scanRevision = h.revision;
      }
      final results = scans.where((s) => s.crop == crop).toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('AgriSense'),
          actions: [
            IconButton(
              tooltip: 'Help & troubleshooting',
              onPressed: locked ? null : _help,
              icon: const Icon(Icons.help_outline),
            ),
            IconButton(
              tooltip: 'Scan leaf',
              onPressed: locked ? null : _scan,
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          ],
        ),
        body: PageBody(
          children: [
            if (page != 0)
              Text(
                tabs[page],
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            AbsorbPointer(
              absorbing: locked,
              child: CropPicker(value: crop, onChanged: _crop),
            ),
            const SizedBox(height: 20),
            if (locked) const LinearProgressIndicator(),
            if (error != null || h.error != null)
              IssueCard(
                issue: error != null
                    ? actionIssue ??
                          AppIssue.from(
                            FormatException(error!),
                            fallback: error!.contains('Saved scans')
                                ? AppIssue.history
                                : AppIssue.settings,
                          )
                    : h.issue ?? AppIssue.connection,
                onSettings: locked ? null : () => setState(() => page = 2),
                onRetry: locked
                    ? null
                    : error?.contains('Saved scans') == true
                    ? () => setState(() {
                        error = null;
                        _loadScans();
                      })
                    : error == null &&
                          h.allowLocalHttp &&
                          h.address(crop, 'sensor').isNotEmpty
                    ? () => h.refresh(crop)
                    : null,
              ),
            if (page == 0) ..._dashboard(results),
            if (page == 1) ..._trends(),
            if (page == 2) ..._devices(),
            if (page == 3) ..._history(results),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (v) => setState(() => page = v),
          destinations: [
            for (var i = 0; i < tabs.length; i++)
              NavigationDestination(icon: Icon(icons[i]), label: tabs[i]),
          ],
        ),
      );
    },
  );
}

class _NodeAssignmentDialog extends StatefulWidget {
  const _NodeAssignmentDialog({
    required this.crop,
    required this.kind,
    required this.initialAddress,
    required this.existing,
    required this.httpEnabled,
  });
  final Crop crop;
  final String kind, initialAddress;
  final Map<Crop, String> existing;
  final bool httpEnabled;
  @override
  State<_NodeAssignmentDialog> createState() => _NodeAssignmentDialogState();
}

class _NodeAssignmentDialogState extends State<_NodeAssignmentDialog> {
  final formKey = GlobalKey<FormState>();
  late final ip = TextEditingController(text: widget.initialAddress);
  final code = TextEditingController();
  @override
  void dispose() {
    ip.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Assign ${widget.kind} to ${widget.crop.label}'),
    content: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: ip,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                try {
                  hardwareAddress(value);
                  return null;
                } on FormatException {
                  return 'Use a private numeric IPv4 address, optionally with a port.';
                }
              },
              decoration: const InputDecoration(
                labelText: 'Private IPv4 address',
                hintText: '192.168.1.50',
              ),
            ),
            if (widget.existing.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Or use an existing board:'),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in widget.existing.entries)
                    ActionChip(
                      label: Text(e.key.label),
                      onPressed: () {
                        ip.text = e.value;
                        code.clear();
                      },
                    ),
                ],
              ),
            ],
            if (widget.kind == 'sensor') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: code,
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value.trim())
                    ? null
                    : 'Enter the 32-character pairing code, or leave blank to reuse the saved code.',
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Sensor pairing code',
                ),
              ),
              const Text(
                'First setup: paste the code from Serial Monitor. Leave blank to reuse the saved code for this IP.',
              ),
              if (!widget.httpEnabled)
                const Text(
                  'Enable local hardware access before assigning the sensor.',
                  style: TextStyle(color: warning),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'This assigns the board to ${widget.crop.label}, replacing its previous crop assignment. Move the physical board to the correct plant too.',
            ),
            const Text(
              'Leave the IP blank to remove the app assignment. This does not erase readings or reset the board.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (formKey.currentState!.validate()) {
            Navigator.pop(context, (ip.text, code.text));
          }
        },
        child: const Text('Apply assignment'),
      ),
    ],
  );
}
