import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/soil_calibration.dart';

class SoilCalibrationScreen extends StatefulWidget {
  const SoilCalibrationScreen({
    required this.hardware,
    required this.crop,
    super.key,
  });
  final HardwareController hardware;
  final Crop crop;

  @override
  State<SoilCalibrationScreen> createState() => _SoilCalibrationScreenState();
}

class _SoilCalibrationScreenState extends State<SoilCalibrationScreen> {
  final dry = TextEditingController();
  final wet = TextEditingController();
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final saved = widget.hardware.soilCalibration(widget.crop);
    if (saved != null) {
      dry.text = '${saved.dry}';
      wet.text = '${saved.wet}';
    }
  }

  @override
  void dispose() {
    dry.dispose();
    wet.dispose();
    super.dispose();
  }

  Future<void> save({bool clear = false}) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final dryValue = int.tryParse(dry.text.trim());
      final wetValue = int.tryParse(wet.text.trim());
      if (!clear && (dryValue == null || wetValue == null)) {
        throw const FormatException(
          'Enter both readings as whole numbers from 0 to 4095.',
        );
      }
      final value = clear
          ? null
          : SoilCalibration(dry: dryValue!, wet: wetValue!);
      await widget.hardware.saveSoilCalibration(widget.crop, value);
      if (mounted) Navigator.of(context).pop();
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save soil percentage settings. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Soil percentage')),
    body: PageBody(
      children: [
        const Text('Set up once for this soil sensor on this phone.'),
        const SizedBox(height: 16),
        const Text(
          '1. On Home, note the soil reading with the probe in dry soil. This will be 0%.',
        ),
        const SizedBox(height: 8),
        const Text(
          '2. Put the probe in thoroughly wet soil and wait for a steady reading. Note the number. This will be 100%. Keep the electronics dry.',
        ),
        const SizedBox(height: 8),
        const Text(
          '3. Enter those two numbers below, then save. Return the probe to the soil you want to monitor.',
        ),
        const SizedBox(height: 8),
        const Text(
          'To measure new references later, choose Use raw readings instead first.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: dry,
          enabled: !saving,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Dry soil reading (0%)',
            helperText: 'Raw number from 0 to 4095',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: wet,
          enabled: !saving,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Wet soil reading (100%)',
            helperText: 'Raw number from 0 to 4095',
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'This is relative moisture between your references, not a laboratory water-content measurement. Existing sensor alerts and kit warning LEDs keep their current units.',
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving ? null : () => save(),
          child: const Text('Save percentage'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: saving ? null : () => save(clear: true),
          child: const Text('Use raw readings instead'),
        ),
      ],
    ),
  );
}
