import 'package:flutter/material.dart';
import '../../data/daily_photo_schedule.dart';

class PhotoTimesSheet extends StatefulWidget {
  const PhotoTimesSheet({required this.schedule, super.key});
  final DailyPhotoSchedule schedule;
  @override
  State<PhotoTimesSheet> createState() => _PhotoTimesSheetState();
}

class _PhotoTimesSheetState extends State<PhotoTimesSheet> {
  late final times = [...widget.schedule.minutes]..sort();
  String? error;
  Future<void> addTime() async {
    final now = TimeOfDay.now();
    final chosen = await showTimePicker(context: context, initialTime: now);
    if (chosen == null || !mounted) return;
    final minute = chosen.hour * 60 + chosen.minute;
    setState(() {
      if (times.contains(minute)) {
        error = 'That time is already on your list.';
      } else {
        times.add(minute);
        times.sort();
        error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Automatic photo times',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a photo and check your plant at these times every day. Uses your phone’s local time.',
          ),
          const SizedBox(height: 16),
          if (times.isEmpty) const Text('Add your first photo time.'),
          for (final minute in times)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                TimeOfDay(
                  hour: minute ~/ 60,
                  minute: minute % 60,
                ).format(context),
              ),
              trailing: IconButton(
                tooltip: 'Remove time',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  times.remove(minute);
                  error = null;
                }),
              ),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          OutlinedButton.icon(
            onPressed: addTime,
            icon: const Icon(Icons.add),
            label: const Text('Add time'),
          ),
          const SizedBox(height: 12),
          Text(
            times.isEmpty
                ? 'Saving an empty list turns scheduled photos off.'
                : widget.schedule.minutes.isEmpty
                ? 'Save times to turn scheduled photos on. Your phone must stay connected.'
                : 'Saving keeps your current schedule On or Off. Your phone must stay connected.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              DailyPhotoSchedule(
                enabled:
                    times.isNotEmpty &&
                    (widget.schedule.minutes.isEmpty ||
                        widget.schedule.enabled),
                minutes: List.of(times),
              ),
            ),
            child: const Text('Save times'),
          ),
        ],
      ),
    ),
  );
}
