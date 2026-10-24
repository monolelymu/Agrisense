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
import 'notification_settings_screen.dart';
import '../help/help_screen.dart';
import '../../core/app_issue.dart';
import '../../core/issue_card.dart';
import 'alert_detail_screen.dart';
import '../diagnosis/model_catalog.dart';
import '../diagnosis/crop_knowledge_screen.dart';
import '../diagnosis/simple_result_card.dart';
import '../../data/daily_photo_schedule.dart';
import 'photo_times_sheet.dart';

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
  DateTime? recordDate;
  bool bookmarksOnly = false;
  final Set<String> _bookmarkWrites = {};
  String metric = 'Temperature';
  int trendDays = 1;
  String historyQuery = '';
  final historySearch = TextEditingController();
  DateTimeRange? historyDates;
  bool oldestFirst = false;
  int historyLimit = 50;
  String scanFilter = 'All results';
  List<TomatoScan> scans = [];
  String? error;
  AppIssue? actionIssue;
  bool saving = false;
  bool cameraBusy = false;
  bool _askedForNotifications = false;
  String? connectionNotice;
  int _scanRevision = -1;
  HardwareController get h => widget.hardware;
  bool get locked => saving || h.userBusy || cameraBusy;
  static const tabs = [
    'Home',
    'Camera',
    'Records',
    'Settings',
    'Device setup',
    'Trends',
    'Technical logs',
  ];
  static const icons = [
    Icons.home_outlined,
    Icons.camera_alt_outlined,
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

  Future<void> _help() => h.withPollingPaused(() async {
    final destination = await Navigator.of(context).push<HelpDestination>(
      MaterialPageRoute<HelpDestination>(
        builder: (helpContext) => HelpScreen(
          crop: crop,
          onReplay: () =>
              Navigator.of(helpContext).pop(HelpDestination.tutorial),
          showShortcuts: true,
        ),
      ),
    );
    if (!mounted) return;
    switch (destination) {
      case HelpDestination.tutorial:
        setState(() => page = 0);
        await _tutorial();
      case HelpDestination.scan:
        setState(() => page = 1);
      case HelpDestination.devices:
        _secondaryPage(4);
      case HelpDestination.monitoring:
        await _openSettings(MonitoringSettingsScreen(hardware: h, crop: crop));
      case HelpDestination.alerts:
        setState(() {
          historyCategory = 1;
        });
        _secondaryPage(6);
      case null:
        break;
    }
  });

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
    historySearch.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (!h.backgroundActive) h.stopPolling();
    super.dispose();
  }

  void _crop(Crop value) {
    if (locked || crop == value) return;
    setState(() {
      crop = value;
      error = null;
      actionIssue = null;
    });
    h.selectMonitoringCrop(value);
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
                  SimpleResultCard(scan: scan),
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
      if (answer.$1.trim().isEmpty) return h.clearSavedAddress(selected, kind);
      return kind == 'sensor'
          ? h.configureSensor(selected, answer.$1, answer.$2)
          : h.moveCamera(selected, answer.$1);
    });
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            answer.$1.trim().isEmpty
                ? 'Saved IP cleared from this phone. History and pairing are kept. Board automatic capture is not stopped.'
                : 'Kit $kind saved for all crops. Saved history is unchanged.',
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
        await h.waitForIdle();
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
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          scan.preview,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.eco_outlined),
        ),
      ),
      title: Text(
        '${scan.crop.label} • ${scan.uncertain ? 'Uncertain result' : scan.displayLabel}',
      ),
      subtitle: Text(
        '${scan.uncertain ? 'Uncertain result • ' : ''}${dateLabel(scan.timestamp)}',
      ),
      trailing: IconButton(
        tooltip: widget.scans.bookmarked(scan.id)
            ? 'Remove bookmark'
            : 'Bookmark',
        icon: Icon(
          widget.scans.bookmarked(scan.id)
              ? Icons.bookmark
              : Icons.bookmark_border,
        ),
        onPressed: _bookmarkWrites.contains(scan.id)
            ? null
            : () => _bookmark(scan.id),
      ),
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
          errorBuilder: (_, _, _) =>
              const Icon(Icons.image_not_supported_outlined),
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
      SizedBox(
        width: double.infinity,
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection & monitoring',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Join the same pocket Wi-Fi as your boards, then connect.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: locked ? null : _connect,
                  icon: const Icon(Icons.link),
                  label: Text(
                    saving
                        ? 'Checking your devices…'
                        : h.polling &&
                              (h.status[crop] == 'Unavailable' ||
                                  h.cameraStatus[crop] == 'Unavailable')
                        ? 'Retry connection'
                        : 'Connect AgriSense',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (connectionNotice != null) ...[
                Text(connectionNotice!),
                const SizedBox(height: 12),
              ],
              _connectionRow(
                Icons.sensors,
                'Sensor',
                h.address(crop, 'sensor').isEmpty
                    ? 'Not set up'
                    : h.fresh(crop)
                    ? 'Receiving readings'
                    : h.status[crop] == 'Unavailable'
                    ? 'Reconnecting…'
                    : 'Not checked. Tap Connect.',
                h.fresh(crop),
              ),
              const SizedBox(height: 8),
              _connectionRow(
                Icons.camera_alt_outlined,
                'Camera',
                h.address(crop, 'camera').isEmpty
                    ? 'Not set up'
                    : h.cameraStatus[crop] == 'Received'
                    ? 'Photo connection checked'
                    : h.cameraStatus[crop] == 'Unavailable'
                    ? 'Reconnecting…'
                    : 'Not checked. Tap Connect.',
                h.cameraStatus[crop] == 'Received',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    h.polling ? Icons.sync : Icons.pause_circle_outline,
                    color: h.polling ? accent : muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      h.polling ? 'Monitoring is on' : 'Tap Connect to start',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _scheduleCard(),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: locked
            ? null
            : () => _openSettings(
                NotificationSettingsScreen(hardware: h, crop: crop),
              ),
        icon: const Icon(Icons.notifications_outlined),
        label: const Text('Edit sensor alerts'),
      ),
      const SizedBox(height: 24),
      Text(
        '${crop.label} overview',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      if (r == null)
        const EmptyState(
          'No sensor readings yet',
          'Tap Connect to check your saved sensor. First time? Open Device setup.',
        )
      else ...[
        Tag(h.fresh(crop) ? 'RECENT SENSOR READING' : 'SAVED SENSOR READING'),
        const SizedBox(height: 8),
        Text('Received ${dateLabel(r.receivedAt)}'),
        if (!h.fresh(crop))
          const Text(
            'Historical reading. Read sensors again for current conditions.',
          ),
        const SizedBox(height: 12),
        MetricGrid(
          children: [
            _metric(
              'Soil moisture',
              !r.soilCalibrated
                  ? 'Not calibrated'
                  : r.soil == null
                  ? 'Unavailable'
                  : '${r.soil!.toStringAsFixed(0)}%',
              r.soilCalibrated ? 'Calibrated by device' : 'Needs calibration',
            ),
            _metric(
              'Temperature',
              r.temperature == null
                  ? 'Unavailable'
                  : '${r.temperature!.toStringAsFixed(1)}°C',
              'Air temperature',
            ),
            _metric(
              'Humidity',
              r.humidity == null
                  ? 'Unavailable'
                  : '${r.humidity!.toStringAsFixed(0)}%',
              'Relative humidity',
            ),
          ],
        ),
        if (r.temperature == null || r.humidity == null)
          const Text('Temperature/humidity sensor reported a failed reading.'),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: locked ? null : () => _secondaryPage(5),
            child: const Text('View trends'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text('Latest diagnosis', style: Theme.of(context).textTheme.titleLarge),
      if (results.isEmpty)
        const Text('No saved scans for this crop yet.')
      else
        _scanTile(results.first),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: locked ? null : () => setState(() => page = 1),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Check a leaf'),
      ),
    ];
  }

  // Reuse the installed firmware's existing endpoints. Discovery is not assumed.
  Future<void> _connect() async {
    if (!h.allowLocalHttp) {
      setState(
        () => connectionNotice =
            'Local hardware access is off. Enable it in Settings to connect.',
      );
      return;
    }
    if (h.address(crop, 'sensor').isEmpty &&
        h.address(crop, 'camera').isEmpty) {
      setState(
        () => connectionNotice =
            'Your kit connection has not been configured yet. Automatic device discovery is not available in this version.',
      );
      return;
    }
    setState(() => connectionNotice = null);
    final selected = crop;
    await _saveAction(() async {
      if (h.backgroundEnabled && !_askedForNotifications) {
        _askedForNotifications = true;
        try {
          await h.notifications.requestPermission();
        } catch (_) {
          /* Monitoring can run if notifications are declined. */
        }
      }
      if (h.address(selected, 'sensor').isNotEmpty) {
        await h.refresh(selected);
      }
      final camera = h.address(selected, 'camera');
      if (camera.isNotEmpty) {
        await h.checkCamera(selected);
      }
      if (!h.polling) await h.startMonitoring(selected);
    }, fallback: AppIssue.connection);
  }

  final List<int> _pageHistory = [];
  void _back() {
    if (locked) return;
    setState(() => page = _pageHistory.isEmpty ? 0 : _pageHistory.removeLast());
  }

  void _secondaryPage(int destination) {
    if (locked || page == destination) return;
    setState(() {
      _pageHistory.add(page);
      page = destination;
    });
  }

  List<Widget> _settings() => [
    const Text(
      'Everyday controls stay on Home and Camera. Set up your kit here.',
    ),
    const SizedBox(height: 16),
    Card(
      child: ListTile(
        leading: const Icon(Icons.router_outlined),
        title: const Text('Device setup'),
        subtitle: const Text('Saved boards and local Wi-Fi access'),
        trailing: const Icon(Icons.chevron_right),
        onTap: locked ? null : () => _secondaryPage(4),
      ),
    ),
    const SizedBox(height: 12),
    Card(
      child: ListTile(
        leading: const Icon(Icons.tune),
        title: const Text('Monitoring & Auto Scan'),
        subtitle: const Text(
          'Alerts, presets and existing automatic capture rules',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: locked
            ? null
            : () => _openSettings(
                MonitoringSettingsScreen(hardware: h, crop: crop),
              ),
      ),
    ),
    const SizedBox(height: 12),
    Card(
      child: ListTile(
        title: const Text('Technical logs'),
        subtitle: const Text(
          'Sensor readings, alerts and saved photo originals',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _secondaryPage(6),
      ),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: () => _openSettings(CropKnowledgeScreen(crop: crop)),
      icon: const Icon(Icons.menu_book_outlined),
      label: const Text('Plant reference details'),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: locked ? null : _help,
      icon: const Icon(Icons.help_outline),
      label: const Text('Help & troubleshooting'),
    ),
  ];

  List<Widget> _devices() => [
    Text('Kit devices', style: Theme.of(context).textTheme.headlineSmall),
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
      'This camera and sensor connection is shared across all crops. Changing the crop on Home does not change the sensor firmware configuration. Saved history stays unchanged.',
    ),
    const SizedBox(height: 16),
    Text('Connection tests', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    if (!h.allowLocalHttp)
      const Text('Enable local hardware access above to test your devices.'),
    if (h.address(crop, 'sensor').isEmpty)
      const Text('Assign a sensor above to enable its connection test.'),
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
    if (h.address(crop, 'camera').isEmpty)
      const Text('Assign a camera above to enable its connection test.'),
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
      label: const Text('Scan leaf'),
    ),
    const SizedBox(height: 12),
    Text(modelStatus(crop)),
  ];

  Widget _connectionRow(
    IconData icon,
    String name,
    String status,
    bool connected,
  ) => Row(
    children: [
      Icon(icon, color: connected ? accent : muted),
      const SizedBox(width: 12),
      Expanded(child: Text('$name: $status')),
      Icon(
        connected ? Icons.check_circle_outline : Icons.info_outline,
        color: connected ? accent : muted,
        size: 18,
      ),
    ],
  );

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

  List<Widget> _trends() {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: trendDays));
    final readings =
        h
            .readings(crop)
            .where(
              (r) =>
                  _value(r)?.isFinite == true &&
                  !r.receivedAt.isAfter(now) &&
                  (trendDays == 0 || !r.receivedAt.isBefore(cutoff)),
            )
            .toList()
          ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
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
      DropdownButtonFormField<String>(
        initialValue: metric,
        decoration: const InputDecoration(labelText: 'Reading'),
        items: [
          for (final name in ['Temperature', 'Humidity', 'Soil moisture'])
            DropdownMenuItem(value: name, child: Text(name)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => metric = value);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: trendDays,
        decoration: const InputDecoration(labelText: 'Period'),
        items: [
          for (final entry in const {
            1: 'Last 24 hours',
            7: 'Last 7 days',
            30: 'Last 30 days',
            0: 'All time',
          }.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => trendDays = value);
        },
      ),
      const SizedBox(height: 12),
      if (readings.isEmpty)
        const EmptyState('No readings yet', 'Connect AgriSense to start.')
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
              Text(
                'Latest ${values.last.toStringAsFixed(1)} · Average ${(values.reduce((a, b) => a + b) / values.length).toStringAsFixed(1)}\n'
                'Low ${low.toStringAsFixed(1)} · High ${high.toStringAsFixed(1)}',
              ),
              Text(
                'Last reading ${dateLabel(readings.last.receivedAt)}',
                style: const TextStyle(color: muted),
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
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots
                            .map(
                              (spot) => LineTooltipItem(
                                '${dateLabel(start.add(Duration(milliseconds: (spot.x * 60000).round())))}\n${spot.y.toStringAsFixed(1)} ${metric == 'Temperature'
                                    ? '°C'
                                    : metric == 'Gas raw'
                                    ? 'ADC'
                                    : '%'}',
                                const TextStyle(color: accent),
                              ),
                            )
                            .toList(),
                      ),
                    ),
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
                              dateLabel(
                                start.add(
                                  Duration(
                                    milliseconds: (value * 60000).round(),
                                  ),
                                ),
                              ).replaceFirst(' ', '\n'),
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
                        dotData: const FlDotData(show: true),
                        spots: [
                          for (var i = 0; i < readings.length; i++) ...[
                            if (i > 0 &&
                                readings[i].receivedAt
                                        .difference(readings[i - 1].receivedAt)
                                        .inMinutes >
                                    30)
                              FlSpot.nullSpot,
                            FlSpot(
                              readings[i].receivedAt
                                      .difference(start)
                                      .inMilliseconds /
                                  60000,
                              _value(readings[i])!,
                            ),
                          ],
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
      if (readings.isNotEmpty)
        const Text('Tap a point to see its reading and time.'),
    ];
  }

  bool _matchesHistory(DateTime at, String text) {
    final dates = historyDates;
    return (dates == null ||
            (!at.isBefore(dates.start) &&
                at.isBefore(dates.end.add(const Duration(days: 1))))) &&
        '$text ${dateLabel(at)} ${at.toIso8601String()}'.toLowerCase().contains(
          historyQuery.trim().toLowerCase(),
        );
  }

  Future<void> _chooseHistoryDates() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: historyDates,
    );
    if (dates != null && mounted) {
      setState(() {
        historyDates = dates;
        historyLimit = 50;
      });
    }
  }

  Future<void> _bookmark(String id) async {
    if (!_bookmarkWrites.add(id)) return;
    try {
      await widget.scans.bookmark(id, !widget.scans.bookmarked(id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this bookmark. Please try again.'),
          ),
        );
      }
    } finally {
      _bookmarkWrites.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editTimes() async {
    final selected = crop;
    final value = await showModalBottomSheet<DailyPhotoSchedule>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PhotoTimesSheet(schedule: h.schedule(selected)),
    );
    if (value != null && mounted) {
      await _saveAction(() => h.saveSchedule(selected, value));
    }
  }

  Widget _scheduleCard() {
    final settings = h.schedule(crop);
    final next = settings.next(DateTime.now());
    String time(int minute) =>
        TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic photos'),
            value: settings.enabled,
            onChanged: locked
                ? null
                : (enabled) {
                    if (enabled && settings.minutes.isEmpty) {
                      _editTimes();
                    } else {
                      _saveAction(
                        () => h.saveSchedule(
                          crop,
                          DailyPhotoSchedule(
                            enabled: enabled,
                            minutes: settings.minutes,
                          ),
                        ),
                      );
                    }
                  },
          ),
          Text(
            settings.minutes.isEmpty
                ? 'Choose when to check your plant each day.'
                : 'Every day: ${settings.minutes.map(time).join(' · ')}',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: locked ? null : _editTimes,
            icon: const Icon(Icons.schedule),
            label: const Text('Edit times'),
          ),
          const SizedBox(height: 12),
          if (next != null)
            Text(
              !h.polling
                  ? 'Connect to start scheduled photos.'
                  : h.address(crop, 'camera').isEmpty
                  ? 'Waiting for a camera connection.'
                  : 'Next check: ${MaterialLocalizations.of(context).formatMediumDate(next)} · ${TimeOfDay.fromDateTime(next).format(context)}',
            ),
          if (h.automaticStatus != null) ...[
            const SizedBox(height: 8),
            Text(h.automaticStatus!),
          ],
          if (h.polling) ...[
            const SizedBox(height: 8),
            Text(
              h.backgroundActive
                  ? 'Checks continue while your phone is locked.'
                  : 'Keep the app open. Background monitoring is not active.',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _records(List<TomatoScan> results) {
    final filtered = results.where((scan) {
      final at = scan.timestamp.toLocal();
      return (!bookmarksOnly || widget.scans.bookmarked(scan.id)) &&
          (recordDate == null ||
              (at.year == recordDate!.year &&
                  at.month == recordDate!.month &&
                  at.day == recordDate!.day));
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              recordDate == null
                  ? 'Choose date'
                  : MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(recordDate!),
            ),
            onPressed: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: recordDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (value != null && mounted) setState(() => recordDate = value);
            },
          ),
          if (recordDate != null)
            TextButton(
              onPressed: () => setState(() => recordDate = null),
              child: const Text('Clear date'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('All')),
          ButtonSegment(value: true, label: Text('Bookmarked')),
        ],
        selected: {bookmarksOnly},
        onSelectionChanged: (values) =>
            setState(() => bookmarksOnly = values.single),
      ),
      const SizedBox(height: 20),
      if (filtered.isEmpty)
        EmptyState(
          bookmarksOnly
              ? 'No bookmarked checks'
              : recordDate != null
              ? 'No checks on this date'
              : 'No saved leaf checks',
          bookmarksOnly
              ? 'Tap the bookmark beside a check to save it here.'
              : 'Your plant photos and results will appear here.',
        ),
      for (final scan in filtered) ...[
        _scanTile(scan),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _technicalHistory(List<TomatoScan> results) {
    final filteredScans =
        results
            .where(
              (s) =>
                  _matchesHistory(
                    s.timestamp,
                    '${s.id} ${s.displayLabel} ${s.source} ${s.uncertain ? 'uncertain' : ''}',
                  ) &&
                  (scanFilter == 'All results' ||
                      (scanFilter == 'Uncertain'
                          ? s.uncertain
                          : scanFilter == 'Healthy'
                          ? s.label == 'healthy'
                          : s.label != 'healthy')),
            )
            .toList()
          ..sort(
            (a, b) => oldestFirst
                ? a.timestamp.compareTo(b.timestamp)
                : b.timestamp.compareTo(a.timestamp),
          );
    final filteredAlerts =
        h.alerts
            .where(
              (a) =>
                  a.crop == crop &&
                  _matchesHistory(
                    a.timestamp,
                    '${a.id} ${a.reason} ${alertStateLabel(a.state)}',
                  ),
            )
            .toList()
          ..sort(
            (a, b) => oldestFirst
                ? a.timestamp.compareTo(b.timestamp)
                : b.timestamp.compareTo(a.timestamp),
          );
    final filteredPhotos =
        h.alertPhotos
            .where(
              (p) =>
                  p.crop == crop &&
                  p.alertId == null &&
                  _matchesHistory(p.timestamp, p.reason),
            )
            .toList()
          ..sort(
            (a, b) => oldestFirst
                ? a.timestamp.compareTo(b.timestamp)
                : b.timestamp.compareTo(a.timestamp),
          );
    final filteredReadings =
        h
            .readings(crop)
            .where(
              (r) => _matchesHistory(
                r.receivedAt,
                '${r.id} ${r.deviceId} temperature ${r.temperature} humidity ${r.humidity} soil ${r.soil} gas ${r.gasRaw}',
              ),
            )
            .toList()
          ..sort(
            (a, b) => oldestFirst
                ? a.receivedAt.compareTo(b.receivedAt)
                : b.receivedAt.compareTo(a.receivedAt),
          );
    final count = historyCategory == 0
        ? filteredScans.length
        : historyCategory == 1
        ? filteredAlerts.length + filteredPhotos.length
        : filteredReadings.length;
    return [
      DropdownButtonFormField<int>(
        initialValue: historyCategory,
        decoration: const InputDecoration(labelText: 'Show'),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Leaf checks')),
          DropdownMenuItem(value: 1, child: Text('Alerts')),
          DropdownMenuItem(value: 2, child: Text('Readings')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            historyCategory = value;
            historyLimit = 50;
            scanFilter = 'All results';
            historyQuery = '';
            historySearch.clear();
          });
        },
      ),
      const SizedBox(height: 16),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Search & filters'),
        subtitle: Text(
          historyQuery.isNotEmpty ||
                  historyDates != null ||
                  scanFilter != 'All results' ||
                  oldestFirst
              ? 'Filters applied'
              : 'Optional',
        ),
        children: [
          TextField(
            controller: historySearch,
            decoration: InputDecoration(
              labelText: 'Search records',
              hintText: 'Search by result or date',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: historyQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        historySearch.clear();
                        historyQuery = '';
                        historyLimit = 50;
                      }),
                    ),
            ),
            onChanged: (value) => setState(() {
              historyQuery = value;
              historyLimit = 50;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _chooseHistoryDates,
                icon: const Icon(Icons.date_range),
                label: Text(
                  historyDates == null
                      ? 'Date range'
                      : '${dateLabel(historyDates!.start).split(' ').first} – ${dateLabel(historyDates!.end).split(' ').first}',
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  oldestFirst = !oldestFirst;
                  historyLimit = 50;
                }),
                icon: const Icon(Icons.sort),
                label: Text(oldestFirst ? 'Oldest first' : 'Newest first'),
              ),
              if (historyDates != null ||
                  historyQuery.isNotEmpty ||
                  scanFilter != 'All results')
                TextButton(
                  onPressed: () => setState(() {
                    historyDates = null;
                    historyQuery = '';
                    historySearch.clear();
                    scanFilter = 'All results';
                    historyLimit = 50;
                  }),
                  child: const Text('Clear filters'),
                ),
            ],
          ),
          if (historyCategory == 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in [
                  'All results',
                  'Healthy',
                  'Other results',
                  'Uncertain',
                ])
                  ChoiceChip(
                    label: Text(filter),
                    selected: scanFilter == filter,
                    onSelected: (_) => setState(() {
                      scanFilter = filter;
                      historyLimit = 50;
                    }),
                  ),
              ],
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (count == 0 &&
          (historyQuery.isNotEmpty ||
              historyDates != null ||
              (historyCategory == 0 && scanFilter != 'All results')))
        const EmptyState(
          'No matching records',
          'Try another search or clear the filters.',
        ),
      if (historyCategory == 0) ...[
        Text(
          '${filteredScans.length} saved leaf checks',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (results.isEmpty && historyQuery.isEmpty && historyDates == null)
          const EmptyState(
            'No saved leaf checks',
            'Open Camera to check a leaf or choose a photo.',
          ),
        for (final result in filteredScans.take(historyLimit)) ...[
          _scanTile(result),
          const SizedBox(height: 12),
        ],
      ],
      if (historyCategory == 1) ...[
        Text('Sensor alerts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Each alert links its trigger, photo and diagnosis when available. Failures remain visible here.',
        ),
        const SizedBox(height: 16),
        for (final alert in filteredAlerts.take(historyLimit)) ...[
          Card(
            child: ListTile(
              title: Text(alertStateLabel(alert.state)),
              subtitle: Text('${dateLabel(alert.timestamp)}\n${alert.reason}'),
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
        if (!h.alertPhotos.any((p) => p.crop == crop && p.alertId == null) &&
            !h.alerts.any((a) => a.crop == crop))
          const EmptyState(
            'No alerts saved',
            'Enable sensor alerts in Monitoring & Auto Scan to record warnings here.',
          ),
        if (filteredPhotos.isNotEmpty) ...[
          Text(
            'Older warning photos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'These older photos have no linked alert record. Board SD photos stay on the camera.',
          ),
          const SizedBox(height: 16),
        ],
        for (final photo in filteredPhotos.take(
          math.max(0, historyLimit - filteredAlerts.length),
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
        for (final r in filteredReadings.take(historyLimit)) ...[
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
      ],
      if (count > 0)
        Text(
          'Showing ${math.min(count, historyLimit)} of $count matching records',
          style: const TextStyle(color: muted),
        ),
      if (count > historyLimit)
        TextButton.icon(
          onPressed: () => setState(() => historyLimit += 50),
          icon: const Icon(Icons.expand_more),
          label: const Text('Show 50 more'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: h,
    builder: (context, _) {
      if (_scanRevision != h.revision) {
        _loadScans();
        _scanRevision = h.revision;
      }
      final results = scans.where((s) => s.crop == crop).toList();
      return PopScope(
        canPop: page < 3 && !locked,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !locked && page >= 3) {
            _back();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: page >= 3
                ? BackButton(onPressed: locked ? null : _back)
                : null,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AgriSense'),
                Text(
                  'No More GuessPlant',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: locked ? null : () => _secondaryPage(3),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Settings'),
              ),
            ],
          ),
          body: page == 1
              ? TomatoScanScreen(
                  store: widget.scans,
                  hardware: h,
                  initialCrop: crop,
                  embedded: true,
                  onCropChanged: _crop,
                  onBusyChanged: (value) {
                    if (mounted && cameraBusy != value) {
                      setState(() => cameraBusy = value);
                    }
                  },
                )
              : PageBody(
                  key: ValueKey(page),
                  children: [
                    if (page != 0)
                      Text(
                        tabs[page],
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    if (page == 0 || page == 5) ...[
                      Text(
                        'Choose crop',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (page != 3 && page != 4)
                      AbsorbPointer(
                        absorbing: locked,
                        child: CropPicker(value: crop, onChanged: _crop),
                      ),
                    const SizedBox(height: 20),
                    if (locked) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Completing your request…'),
                      const SizedBox(height: 16),
                    ],
                    if (error != null || (page >= 3 && h.error != null))
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
                        onSettings: locked ? null : () => _secondaryPage(4),
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
                    if (page == 2) ..._records(results),
                    if (page == 3) ..._settings(),
                    if (page == 4) ..._devices(),
                    if (page == 5) ..._trends(),
                    if (page == 6) ..._technicalHistory(results),
                  ],
                ),
          bottomNavigationBar: page >= 3
              ? null
              : NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: locked
                      ? null
                      : (v) => setState(() {
                          page = v;
                          _loadScans();
                        }),
                  destinations: [
                    for (var i = 0; i < 3; i++)
                      NavigationDestination(
                        icon: Icon(icons[i]),
                        label: tabs[i],
                      ),
                  ],
                ),
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
                'First setup: paste the code from Serial Monitor. For the same sensor at a new IP, leave blank to reuse its saved code after device verification.',
              ),
              if (!widget.httpEnabled)
                const Text(
                  'Enable local hardware access before assigning the sensor.',
                  style: TextStyle(color: warning),
                ),
            ],
            if (widget.kind == 'camera')
              const Text(
                'If the sensor IP also changed, update the sensor assignment first. The app must confirm board automatic capture is off before changing the camera.',
              ),
            const SizedBox(height: 12),
            Text(
              'This assigns the board to ${widget.crop.label}, replacing its previous crop assignment. Move the physical board to the correct plant too.',
            ),
            const Text(
              'Clear saved IP, or leave the IP blank, to forget only this phone’s address. History and pairing are kept. This works offline and does not stop automatic capture already running on the board.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      if (widget.initialAddress.isNotEmpty)
        TextButton.icon(
          key: const ValueKey('clear-saved-ip'),
          icon: const Icon(Icons.link_off),
          label: const Text('Clear saved IP'),
          onPressed: () => Navigator.pop(context, ('', '')),
        ),
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
