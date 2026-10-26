import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/widgets.dart';

class WateringReminderCard extends StatefulWidget {
  const WateringReminderCard({super.key, required this.hardware});
  final HardwareController hardware;
  @override
  State<WateringReminderCard> createState() => _WateringReminderCardState();
}

class _WateringReminderCardState extends State<WateringReminderCard> {
  bool busy = false;
  String? message;
  HardwareController get h => widget.hardware;
  Future<void> _save(int? minute, bool enabled) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await h.saveWatering(minute, enabled);
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Reminder could not be saved. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit() async {
    final existing = h.watering.minute;
    final selected = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: existing ~/ 60, minute: existing % 60),
    );
    if (selected == null || !mounted) return;
    // Saving an explicit first time enables reminders; editing an off one keeps it off.
    await _save(
      selected.hour * 60 + selected.minute,
      existing == null || h.watering.enabled,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: h,
    builder: (context, _) {
      final reminder = h.watering;
      final minute = reminder.minute;
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Watering reminder'),
              subtitle: Text(
                minute == null
                    ? 'Choose a daily time'
                    : 'Daily at ${TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context)}',
              ),
              value: reminder.enabled,
              onChanged: busy
                  ? null
                  : (enabled) {
                      if (enabled && minute == null) {
                        _edit();
                      } else {
                        _save(minute, enabled);
                      }
                    },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : _edit,
              icon: const Icon(Icons.schedule),
              label: const Text('Edit reminder time'),
            ),
            if (minute != null)
              TextButton(
                onPressed: busy ? null : () => _save(null, false),
                child: const Text('Clear reminder time'),
              ),
            if (reminder.enabled && reminder.next != null) ...[
              const SizedBox(height: 8),
              Text('Next reminder: ${dateLabel(reminder.next!)}'),
            ],
            const SizedBox(height: 8),
            const Text(
              'Check the soil before watering. This reminder does not measure dryness.',
            ),
            if (reminder.enabled && !reminder.notificationsAllowed) ...[
              const SizedBox(height: 12),
              const Text(
                'Android notifications are off. Allow AgriSense notifications to receive reminders.',
              ),
            ],
            if (reminder.enabled && !reminder.precise) ...[
              const SizedBox(height: 12),
              const Text(
                'Android may delay this reminder. Allow precise reminders for your chosen time.',
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await h.allowPreciseReminders();
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => message =
                            'Android reminder access could not open. Please retry.',
                      );
                    }
                  }
                },
                child: const Text('Allow precise reminders'),
              ),
            ],
            if (message != null || h.remindersIssue != null) ...[
              const SizedBox(height: 8),
              Text(message ?? h.remindersIssue!),
            ],
          ],
        ),
      );
    },
  );
}
