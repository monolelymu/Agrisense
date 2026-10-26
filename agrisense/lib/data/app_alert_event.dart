class AppAlertEvent {
  const AppAlertEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.at,
    required this.target,
  });
  final String id, type, title, body, target;
  final DateTime at;
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'at': at.millisecondsSinceEpoch,
    'target': target,
  };
  factory AppAlertEvent.fromJson(Map value) {
    if (!['sensor', 'scheduled', 'watering'].contains(value['type']) ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['body'] is! String ||
        value['target'] is! String ||
        value['at'] is! int) {
      throw const FormatException('Invalid alert event.');
    }
    return AppAlertEvent(
      id: value['id'],
      type: value['type'],
      title: value['title'],
      body: value['body'],
      at: DateTime.fromMillisecondsSinceEpoch(value['at']),
      target: value['target'],
    );
  }
}

class AlertTarget {
  const AlertTarget(this.type, this.target, this.token);
  final String type, target, token;
}

class WateringReminder {
  const WateringReminder({
    this.enabled = false,
    this.minute,
    this.precise = false,
    this.next,
    this.notificationsAllowed = true,
  });
  final bool enabled, precise;
  final bool notificationsAllowed;
  final int? minute;
  final DateTime? next;
  factory WateringReminder.fromJson(Map value) => WateringReminder(
    enabled: value['enabled'] == true,
    minute: value['minute'] as int?,
    notificationsAllowed: value['notifications'] != false,
    precise: value['precise'] == true,
    next: value['next'] is int
        ? DateTime.fromMillisecondsSinceEpoch(value['next'] as int)
        : null,
  );
}
