class DailyPhotoSchedule {
  const DailyPhotoSchedule({this.enabled = false, this.minutes = const []});
  final bool enabled;
  final List<int> minutes;

  void validate() {
    if ((enabled && minutes.isEmpty) ||
        minutes.any((m) => m < 0 || m >= 1440) ||
        minutes.toSet().length != minutes.length) {
      throw const FormatException(
        'Choose different valid times before turning automatic photos on.',
      );
    }
  }

  DateTime? next(DateTime now) {
    if (!enabled || minutes.isEmpty) return null;
    final sorted = [...minutes]..sort();
    for (final minute in sorted) {
      final at = DateTime(
        now.year,
        now.month,
        now.day,
        minute ~/ 60,
        minute % 60,
      );
      if (at.isAfter(now)) return at;
    }
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      sorted.first ~/ 60,
      sorted.first % 60,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'minutes': [...minutes]..sort(),
  };
  factory DailyPhotoSchedule.fromJson(Map value) {
    final result = DailyPhotoSchedule(
      enabled: value['enabled'] == true,
      minutes: (value['minutes'] as List? ?? []).cast<int>(),
    );
    result.validate();
    return result;
  }
}
