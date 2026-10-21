import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late Crop crop;
  late bool fahrenheit;
  String? savedMessage;
  static const labels = {
    'soilMin': 'Soil minimum (%)',
    'soilMax': 'Soil maximum (%)',
    'tempMin': 'Temperature minimum (°C)',
    'tempMax': 'Temperature maximum (°C)',
    'humidityMin': 'Humidity minimum (%)',
    'humidityMax': 'Humidity maximum (%)',
    'gasMax': 'Gas / VOC maximum (raw)',
    'threshold': 'Alert threshold (1–100)',
  };
  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      fields[key] = TextEditingController();
    }
    _load();
  }

  void _load() {
    crop = widget.controller.selectedCrop;
    fahrenheit = widget.controller.fahrenheit;
    final values = widget.controller.settingsFor(crop).toJson();
    for (final e in fields.entries) {
      e.value.text = values[e.key].toString();
    }
    savedMessage = null;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (crop != widget.controller.selectedCrop) _load();
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  double number(String key) => double.tryParse(fields[key]!.text) ?? double.nan;
  String? validate(String key, String? text) {
    final n = double.tryParse(text ?? '');
    if (n == null || !n.isFinite) return 'Enter a finite number';
    if (key == 'threshold' && (n < 1 || n > 100 || n != n.roundToDouble())) {
      return 'Use a whole number from 1 to 100';
    }
    if ((key.startsWith('soil') || key.startsWith('humidity')) &&
        (n < 0 || n > 100)) {
      return 'Use a value from 0 to 100';
    }
    if (key.startsWith('temp') && (n < -40 || n > 80)) {
      return 'Use a value from −40 to 80°C';
    }
    if (key == 'gasMax' && (n < 0 || n > 10000)) {
      return 'Use a value from 0 to 10000';
    }
    if (key.endsWith('Max') &&
        key != 'gasMax' &&
        n <= number(key.replaceAll('Max', 'Min'))) {
      return 'Maximum must exceed minimum';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PageBody(
      children: [
        const SectionTitle(
          'Make it yours',
          'Demo preferences and local storage.',
        ),
        CropPicker(value: crop, onChanged: c.selectCrop),
        const SizedBox(height: 20),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tag('UNVALIDATED DEMO RANGES', color: warning),
                const SizedBox(height: 14),
                Text(
                  '${crop.label} thresholds',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'These values test the software. They are not crop-specific agricultural limits. Temperature thresholds are always edited in Celsius.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 22),
                MetricGrid(
                  minWidth: 300,
                  children: [
                    for (final e in labels.entries)
                      TextFormField(
                        controller: fields[e.key],
                        decoration: InputDecoration(labelText: e.value),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (value) => validate(e.key, value),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Display temperatures in Fahrenheit'),
                  subtitle: const Text(
                    'Applies to all crops. Stored readings stay in Celsius.',
                  ),
                  value: fahrenheit,
                  onChanged: (v) => setState(() => fahrenheit = v),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: c.busy
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          final values = {
                            for (final key in fields.keys)
                              key: key == 'threshold'
                                  ? number(key).toInt()
                                  : number(key),
                          };
                          await c.saveSettings(
                            crop,
                            CropSettings.fromJson(values),
                            fahrenheit,
                          );
                          if (mounted) {
                            setState(
                              () => savedMessage = c.error == null
                                  ? 'Settings saved on this device.'
                                  : null,
                            );
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save settings'),
                ),
                if (savedMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      savedMessage!,
                      style: const TextStyle(color: accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Local demo data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'History stays in this browser profile or Android installation. Clearing browser data or uninstalling the app removes it. There is no cloud sync.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: c.busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reset all demo setups?'),
                            content: const Text(
                              'This removes saved scans, alerts, readings, and preferences for all crops. Seven days of sample readings will be restored and simulated nodes disconnected.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Reset demo'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await c.reset();
                          if (mounted) setState(_load);
                        }
                      },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset demo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'AgriSense • Hardware demo\nSensor readings and device connections here are simulated.\nReal tomato photo analysis is available from the app home screen.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}
