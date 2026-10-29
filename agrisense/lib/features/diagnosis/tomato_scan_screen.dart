import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app.dart';
import '../../core/app_controller.dart';
import '../../core/hardware_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/app_issue.dart';
import '../../core/issue_card.dart';
import '../../data/models.dart';
import 'tomato_classifier.dart';
import 'disease_example.dart';
import 'scan_guidance.dart';
import 'tomato_scan.dart';
import 'tomato_context_widgets.dart';
import 'model_catalog.dart';
import 'crop_knowledge_screen.dart';
import 'photo_processing.dart';
import 'camera_live_panel.dart';
import 'camera_gamepad.dart';
import 'simple_result_card.dart';
import '../help/help_screen.dart';

class TomatoApp extends StatelessWidget {
  const TomatoApp({
    required this.store,
    required this.demoController,
    super.key,
  });
  final TomatoScanStore store;
  final AppController demoController;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AgriSense',
    theme: buildTheme(),
    debugShowCheckedModeBanner: false,
    home: TomatoScanScreen(store: store, demoController: demoController),
  );
}

class TomatoScanScreen extends StatefulWidget {
  const TomatoScanScreen({
    required this.store,
    this.demoController,
    this.hardware,
    this.initialCrop = Crop.tomato,
    this.embedded = false,
    this.onCropChanged,
    this.onBusyChanged,
    super.key,
  });
  final TomatoScanStore store;
  final AppController? demoController;
  final HardwareController? hardware;
  final Crop initialCrop;
  final bool embedded;
  final ValueChanged<Crop>? onCropChanged;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<TomatoScanScreen> createState() => _TomatoScanScreenState();
}

class _TomatoScanScreenState extends State<TomatoScanScreen> {
  final picker = ImagePicker();
  final _standaloneClassifier = TomatoClassifier();
  TomatoClassifier get classifier =>
      widget.hardware?.classifier ?? _standaloneClassifier;
  List<TomatoScan> history = [];
  TomatoScan? result;
  Crop crop = Crop.tomato;
  int page = 0;
  bool get canScan =>
      supported &&
      classifier.supports(crop) &&
      !busy &&
      widget.hardware?.userBusy != true &&
      widget.hardware?.cameraControlActive != true;
  List<TomatoScan> get cropHistory =>
      history.where((s) => s.crop == crop).toList();
  bool _busy = false, saved = false;
  bool get busy => _busy;
  set busy(bool value) {
    _busy = value;
    if (widget.onBusyChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onBusyChanged!(busy);
      });
    }
  }

  String? error;
  AppIssue? issue;
  String activity = '';
  Future<void>? _recoveryCheck;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    crop = widget.initialCrop;
    if (widget.hardware != null) page = 1;
    try {
      history = widget.store.load();
      result = widget.store.unsavedResults[crop];
    } catch (_) {
      issue = AppIssue.history;
      error =
          'Saved scans could not be read. Existing records have not been removed.';
    }
    if (supported && !widget.store.photoRecoveryChecked) {
      widget.store.photoRecoveryChecked = true;
      if (widget.store.box.containsKey('pending-photo-crop-v1')) {
        _recoveryCheck = _recoverPhoto();
      }
    }
  }

  Future<void> _recoverPhoto() async {
    var restoring = false;
    try {
      final lost = await picker.retrieveLostData();
      if (!mounted) return;
      if (lost.exception != null) throw lost.exception!;
      if (lost.files?.isNotEmpty ?? false) {
        restoring = true;
        setState(() {
          busy = true;
          activity = 'Restoring selected photo…';
        });
        final pendingCrop = widget.store.box.get('pending-photo-crop-v1');
        final matches = Crop.values.where((c) => c.name == pendingCrop);
        if (matches.isEmpty || !classifier.supports(matches.first)) {
          throw StateError(
            'The interrupted photo has no verified crop model. Select it again.',
          );
        }
        final recoveredCrop = matches.first;
        setState(() => crop = recoveredCrop);
        await _analyze(lost.files!.first, recoveredCrop);
      }
    } catch (_) {
      issue = AppIssue.photo;
      if (mounted) {
        setState(
          () =>
              error = 'Photo recovery failed. Please select your photo again.',
        );
      }
    } finally {
      if (mounted && restoring) setState(() => busy = false);
    }
  }

  @override
  void didUpdateWidget(covariant TomatoScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCrop != widget.initialCrop &&
        crop != widget.initialCrop) {
      _changeCrop(widget.initialCrop);
    }
  }

  void _changeCrop(Crop value) {
    crop = value;
    error = null;
    issue = null;
    result = widget.store.unsavedResults[value];
    saved = false;
    activity = '';
  }

  Future<void> _selectPhoto() => widget.hardware == null
      ? _choosePhoto()
      : widget.hardware!.withPollingPaused(() async {
          await widget.hardware!.waitForIdle();
          await _choosePhoto();
        });

  Future<void> _choosePhoto() async {
    await _recoveryCheck;
    if (!mounted) return;
    if (!canScan) return;
    final selectedCrop = crop;
    setState(() {
      busy = true;
      error = null;
      issue = null;
      activity = 'Selecting photo…';
    });
    try {
      await widget.store.box.put('pending-photo-crop-v1', selectedCrop.name);
      final photo = await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (photo != null && mounted) await _analyze(photo, selectedCrop);
    } on FormatException catch (e) {
      issue = AppIssue.from(e, fallback: AppIssue.photo);
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      issue = AppIssue.from(e, fallback: AppIssue.model);
      if (mounted) {
        setState(
          () => error =
              'The photo could not be analyzed. Try a JPEG or PNG photo. If this continues, restart the app.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _analyze(XFile photo, Crop selectedCrop) async {
    setState(() {
      result = null;
      saved = false;
      page = 1;
      activity = 'Checking ${selectedCrop.label.toLowerCase()} photo…';
    });
    if (await photo.length() > maxPhotoBytes) {
      throw const FormatException('Choose a photo smaller than 15 MB.');
    }
    final scan = await classifier.classifyCrop(
      selectedCrop,
      await photo.readAsBytes(),
    );
    if (!mounted) return;
    setState(() => result = scan);
    await _save(scan);
  }

  Future<void> _capture() => widget.hardware == null
      ? Future<void>.value()
      : widget.hardware!.withPollingPaused(() async {
          await widget.hardware!.waitForIdle();
          await _captureAndAnalyze();
        });

  Future<void> _captureAndAnalyze() async {
    await _recoveryCheck;
    if (!mounted) return;
    if (!canScan || widget.hardware == null) return;
    final selectedCrop = crop;
    setState(() {
      busy = true;
      error = null;
      issue = null;
      activity = 'Taking a photo…';
    });
    try {
      final bytes = await widget.hardware!.capture(selectedCrop);
      final capturedAt = DateTime.now();
      await compute(previewPhoto, bytes);
      final original = await widget.store.saveCameraOriginal(
        selectedCrop,
        capturedAt,
        bytes,
      );
      if (!mounted) return;
      setState(() => activity = 'Checking photo…');
      await _analyzeCameraOriginal(original);
    } catch (e) {
      issue =
          !activity.startsWith('Analyzing') &&
              widget.hardware!.cameraStatus[selectedCrop] != 'Received'
          ? AppIssue.fromCamera(e)
          : AppIssue.from(
              e,
              fallback: activity.startsWith('Analyzing')
                  ? AppIssue.model
                  : AppIssue.camera,
            );
      if (mounted) {
        setState(
          () => error =
              'The photo could not be captured, saved or analyzed. Any saved original is available below for retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _analyzeCameraOriginal(CameraOriginal original) async {
    final prediction = await classifier.classifyCrop(
      original.crop,
      original.jpeg,
    );
    final scan = widget.hardware!.attachScanContext(
      TomatoScan.fromJson({
        ...prediction.toJson(),
        'id': 'camera-${original.id}',
        'crop': original.crop.name,
        'source': 'camera',
        'timestamp': original.at.toIso8601String(),
      }),
      at: original.at,
    );
    if (!mounted) return;
    setState(() {
      result = scan;
      saved = false;
      page = 1;
    });
    await _save(scan);
  }

  Future<void> _retryCameraOriginal(CameraOriginal original) =>
      widget.hardware!.withPollingPaused(() async {
        await widget.hardware!.waitForIdle();
        if (!mounted || busy) return;
        setState(() {
          busy = true;
          error = null;
          activity = 'Checking saved photo…';
        });
        try {
          await _analyzeCameraOriginal(original);
        } catch (_) {
          if (mounted) {
            setState(() {
              issue = AppIssue.model;
              error = 'Analysis failed. Your photo is saved; try again later.';
            });
          }
        } finally {
          if (mounted) setState(() => busy = false);
        }
      });

  Future<void> _save(TomatoScan scan) async {
    widget.store.unsavedResults[scan.crop] = scan;
    try {
      await widget.store.save(scan);
      if (widget.store.unsavedResults[scan.crop]?.id == scan.id) {
        widget.store.unsavedResults.remove(scan.crop);
      }
      if (!mounted) return;
      setState(() {
        saved = true;
        error = null;
        history = [scan, ...history.where((item) => item.id != scan.id)]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    } catch (_) {
      issue = AppIssue.storage;
      if (mounted) {
        setState(
          () => error =
              'Prediction ready, but saving failed. Free some storage and retry saving.',
        );
      }
    }
  }

  Future<void> _retrySave() async {
    final scan = result;
    if (scan == null) return;
    setState(() {
      busy = true;
      activity = 'Saving result…';
    });
    await _save(scan);
    if (mounted) setState(() => busy = false);
  }

  void _selectCrop(Crop value) {
    if (busy || widget.hardware?.userBusy == true || value == crop) return;
    if (widget.onCropChanged != null) {
      widget.onCropChanged!(value);
    } else {
      setState(() => _changeCrop(value));
    }
  }

  Future<void> _previewCamera() async {
    await _recoveryCheck;
    if (!mounted) return;
    if (busy || widget.hardware == null) return;
    setState(() {
      busy = true;
      error = null;
      issue = null;
      activity = 'Getting a camera photo…';
    });
    try {
      await widget.hardware!.capture(crop);
    } catch (e) {
      if (mounted) {
        setState(() {
          issue = AppIssue.fromCamera(e);
          error = widget.hardware!.cameraMessage(crop);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _embeddedCamera(TomatoScan? shown) {
    final hardware = widget.hardware!;
    final pending = widget.store.pendingCameraPhotos(crop);
    final cameraReady =
        hardware.allowLocalHttp && hardware.address(crop, 'camera').isNotEmpty;
    return PageBody(
      children: [
        const SectionTitle(
          'Camera',
          'Check a leaf using the camera or a photo on your phone.',
        ),
        AbsorbPointer(
          absorbing: busy || hardware.userBusy,
          child: CropPicker(value: crop, onChanged: _selectCrop),
        ),
        const SizedBox(height: 20),
        if (pending.isNotEmpty) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('A saved photo still needs checking.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _retryCameraOriginal(pending.first),
                  child: const Text('Check saved photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(activity),
          const SizedBox(height: 16),
        ],
        if (error != null) ...[
          IssueCard(
            issue: issue ?? AppIssue.camera,
            onRetry: busy
                ? null
                : issue == AppIssue.storage && result != null
                ? _retrySave
                : cameraReady
                ? _previewCamera
                : null,
            retryLabel: issue == AppIssue.storage
                ? 'Retry saving'
                : 'Retry camera',
          ),
          const SizedBox(height: 16),
        ],
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CameraLivePanel(hardware: hardware),
              const SizedBox(height: 16),
              const Text('Move camera', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Center(
                child: CameraGamepad(
                  hardware: hardware,
                  crop: crop,
                  blocked: busy,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: canScan && cameraReady ? _capture : null,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Check plant now'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    !busy &&
                        !hardware.userBusy &&
                        !hardware.cameraControlActive &&
                        cameraReady
                    ? _previewCamera
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh photo'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: canScan ? _selectPhoto : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose Photo'),
              ),
              const SizedBox(height: 12),
              Text(
                cameraReady
                    ? 'Show one leaf clearly in good light.'
                    : 'Camera not connected. Tap Connect on Home.',
              ),
              if (!supported)
                const Text('Photo analysis is available in the Android app.'),
              if (!classifier.supports(crop)) Text(modelStatus(crop)),
            ],
          ),
        ),
        if (shown != null) ...[
          const SizedBox(height: 24),
          Text(
            result?.id == shown.id
                ? 'Leaf check result'
                : 'Latest saved result',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SimpleResultCard(scan: shown),
          const SizedBox(height: 8),
          Text(
            result?.id == shown.id && !saved
                ? 'Not saved yet.'
                : 'Saved on this device.',
          ),
          if (result?.id == shown.id && !saved)
            TextButton(
              onPressed: busy ? null : _retrySave,
              child: const Text('Retry saving'),
            ),
        ],
      ],
    );
  }

  void _showScan(TomatoScan scan) => setState(() {
    crop = scan.crop;
    result = scan;
    saved = true;
    page = 1;
  });

  Future<void> _openMainDashboard() async {
    if (busy) return;
    if (widget.hardware != null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      busy = true;
      activity = 'Opening main dashboard…';
    });
    try {
      if (!widget.demoController!.ready) {
        await widget.demoController!.initialize();
      }
      if (!mounted) return;
      widget.demoController!.selectCrop(crop);
      setState(() => busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (dashboardContext) => AppShell(
            controller: widget.demoController!,
            onScanLeaf: () {
              _selectCrop(widget.demoController!.selectedCrop);
              setState(() => page = 1);
              Navigator.of(dashboardContext).pop();
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not open the main dashboard. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
          errorBuilder: (_, _, _) =>
              const Icon(Icons.eco_outlined, color: accent),
        ),
      ),
      title: Text(scan.displayLabel),
      subtitle: Text(
        '${scan.crop.label} • ${dateLabel(scan.timestamp)}\n'
        '${scan.uncertain ? 'Uncertain • ' : ''}Model score: ${(scan.score * 100).toStringAsFixed(1)}%',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: busy ? null : () => _showScan(scan),
    ),
  );

  Widget _photoActions() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analyzing as ${crop.label}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Choose the crop that matches your leaf.'),
        const SizedBox(height: 8),
        Text(
          classifier.supports(crop)
              ? cropModels[crop]?.testingNotice ??
                    'Choose a clear leaf photo. Analysis runs on this device.'
              : modelStatus(crop),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: canScan ? _selectPhoto : null,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Scan leaf'),
        ),
        if (widget.hardware != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                canScan &&
                    widget.hardware!.allowLocalHttp &&
                    widget.hardware!.address(crop, 'camera').isNotEmpty
                ? _capture
                : null,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capture and analyze'),
          ),
          if (widget.hardware!.address(crop, 'camera').isEmpty) ...[
            const SizedBox(height: 8),
            const Text('Connect the camera in Settings → Device setup.'),
          ],
          if (!widget.hardware!.allowLocalHttp) ...[
            const SizedBox(height: 8),
            const Text(
              'Open Settings → Device setup and turn on local hardware access.',
            ),
          ],
        ],
        if (!supported)
          const Text('Photo analysis is available in the Android app.'),
        ...[
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.menu_book_outlined),
            label: Text('${crop.label} knowledge & care'),
            onPressed: busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CropKnowledgeScreen(crop: crop),
                    ),
                  ),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scans = cropHistory;
    final shown = result?.crop == crop
        ? result
        : (scans.isEmpty ? null : scans.first);
    if (widget.embedded && widget.hardware != null) {
      return _embeddedCamera(shown);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriSense'),
        actions: [
          IconButton(
            tooltip: 'Help & troubleshooting',
            onPressed: busy
                ? null
                : () async {
                    Future<void> openHelp() async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => HelpScreen(crop: crop),
                        ),
                      );
                    }

                    final hardware = widget.hardware;
                    if (hardware == null) {
                      await openHelp();
                    } else {
                      await hardware.withPollingPaused(openHelp);
                    }
                  },
            icon: const Icon(Icons.help_outline),
          ),
        ],
        leading: IconButton(
          tooltip: 'Back to main dashboard',
          icon: const Icon(Icons.arrow_back),
          onPressed: busy ? null : _openMainDashboard,
        ),
      ),
      body: PageBody(
        children: [
          Text(
            ['Dashboard', 'Diagnosis', 'History', 'Devices'][page],
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          AbsorbPointer(
            absorbing: busy,
            child: CropPicker(value: crop, onChanged: _selectCrop),
          ),
          const SizedBox(height: 20),
          if (busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(activity),
            const SizedBox(height: 16),
          ],
          if (error != null) ...[
            IssueCard(
              issue: issue ?? AppIssue.unknown,
              onRetry: busy
                  ? null
                  : issue == AppIssue.storage && result != null
                  ? _retrySave
                  : canScan
                  ? _selectPhoto
                  : null,
              retryLabel: issue == AppIssue.storage
                  ? 'Retry saving'
                  : 'Choose another photo',
            ),
            const SizedBox(height: 16),
          ],
          if (page == 0 || page == 1) ...[
            _photoActions(),
            const SizedBox(height: 24),
          ],
          if (page == 0) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${crop.label} monitoring',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('No device connected'),
                  const Text(
                    'Sensor readings will appear when hardware integration is available.',
                  ),
                  TextButton(
                    onPressed: busy ? null : () => setState(() => page = 3),
                    child: const Text('View devices'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Latest diagnosis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (scans.isEmpty)
              const Text('No saved scans for this crop yet.')
            else
              _scanTile(scans.first),
          ],
          if (page == 1) ...[
            if (shown == null)
              const EmptyState(
                'No diagnosis yet',
                'Select a leaf photo to begin.',
              )
            else ...[
              TomatoResultCard(scan: shown),
              const SizedBox(height: 12),
              Text(
                result?.id == shown.id && !saved
                    ? 'Not saved yet.'
                    : 'Saved on this device.',
              ),
              if (result?.id == shown.id && !saved && error == null)
                TextButton(
                  onPressed: busy ? null : _retrySave,
                  child: const Text('Retry saving'),
                ),
            ],
          ],
          if (page == 2) ...[
            Text(
              '${scans.length} saved ${crop.label.toLowerCase()} scans',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Saved on this device. Clearing app data or uninstalling removes these records.',
            ),
            const SizedBox(height: 12),
            if (scans.isEmpty)
              const EmptyState(
                'No saved scans',
                'Your results will appear here after a scan.',
              ),
            for (final scan in scans) _scanTile(scan),
          ],
          if (page == 3) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${crop.label} devices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text('Sensor node: No device connected'),
                  const Text('Camera node: No device connected'),
                  const SizedBox(height: 12),
                  const Text(
                    'Hardware integration is not available yet. Manual photo scans do not require a connected device.',
                  ),
                  const SizedBox(height: 12),
                  const FilledButton(
                    onPressed: null,
                    child: Text('Scan from camera node'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: widget.hardware != null
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (value) {
                if (!busy) setState(() => page = value);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.document_scanner_outlined),
                  label: 'Diagnosis',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.router_outlined),
                  label: 'Devices',
                ),
              ],
            ),
    );
  }
}

class TomatoResultCard extends StatelessWidget {
  const TomatoResultCard({required this.scan, super.key});
  final TomatoScan scan;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.memory(
          scan.preview,
          height: 240,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('Photo preview unavailable.'),
        ),
        const SizedBox(height: 16),
        Text(
          'Selected crop: ${scan.crop.label}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 8),
        Text(
          scan.displayLabel,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Model score: ${(scan.score * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (scan.uncertain) ...[
          const Tag('UNCERTAIN', color: warning),
          const SizedBox(height: 8),
          Text(scanRetakeGuidance(scan)),
        ],
        const Text(
          'Image prediction. Confirm the cause by inspecting the plant.',
          style: TextStyle(color: muted),
        ),
        Text(dateLabel(scan.timestamp), style: const TextStyle(color: muted)),
        const SizedBox(height: 12),
        Text(scanSensorSummary(scan)),
        DiseaseExampleButton(scan: scan),
        const SizedBox(height: 24),
        Text('Top predictions', style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < scan.rankedPredictions.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final name = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, child: Text('${i + 1}')),
                    Expanded(
                      child: Text(scan.rankedPredictions[i].displayLabel),
                    ),
                  ],
                );
                final score = Text(
                  '${(scan.rankedPredictions[i].score * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: muted),
                );
                if (constraints.maxWidth < 400 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.25) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [name, const SizedBox(height: 8), score],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: name),
                    const SizedBox(width: 16),
                    score,
                  ],
                );
              },
            ),
          ),
        if (scan.rankedPredictions.length < 3)
          const Text(
            'This older scan saved only its leading prediction.',
            style: TextStyle(color: muted),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Explanation & care'),
          children: [TomatoExplanation(scan: scan)],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Details'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Source: ${scan.source == 'auto'
                    ? 'Auto Scan'
                    : scan.source == 'camera'
                    ? 'Camera node'
                    : 'Uploaded photo'}\nModel: ${scan.modelVersion}\n'
                'Model scores are not measured accuracy. Uncertain results need a clearer photo or further assessment.',
                style: const TextStyle(color: muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
