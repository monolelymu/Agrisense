import '../../data/hardware_client.dart';
import '../../data/models.dart';
import 'tomato_knowledge.dart';

enum ReferencePosition { within, above, below, unavailable }

String referencePositionLabel(ReferencePosition position) => switch (position) {
  ReferencePosition.within => 'Within reference',
  ReferencePosition.above => 'Above reference',
  ReferencePosition.below => 'Below reference',
  ReferencePosition.unavailable => 'No recent reading',
};

bool recentTomatoSample(HardwareSample? sample, DateTime at) =>
    sample != null &&
    sample.crop == Crop.tomato &&
    !sample.receivedAt.isAfter(at) &&
    at.difference(sample.receivedAt) <= const Duration(seconds: 30);

bool _valid(double? value, double lower, double upper) =>
    value != null && value.isFinite && value >= lower && value <= upper;

class GrowingConditions {
  const GrowingConditions({
    required this.at,
    required this.daytime,
    required this.minimumTemperature,
    required this.maximumTemperature,
    required this.temperaturePosition,
    required this.humidityPosition,
    this.sampleAt,
    this.temperature,
    this.humidity,
    this.soil,
  });
  final DateTime at;
  final DateTime? sampleAt;
  final bool daytime;
  final double minimumTemperature, maximumTemperature;
  final double? temperature, humidity, soil;
  final ReferencePosition temperaturePosition, humidityPosition;

  factory GrowingConditions.assess(HardwareSample? sample, DateTime at) {
    final local = at.toLocal();
    final day = local.hour >= 6 && local.hour < 18;
    final lower = day ? 21.0 : 18.0, upper = day ? 29.0 : 21.0;
    final fresh = recentTomatoSample(sample, at);
    final t = fresh && _valid(sample!.temperature, -40, 80)
        ? sample.temperature
        : null;
    final rh = fresh && _valid(sample!.humidity, 0, 100)
        ? sample.humidity
        : null;
    ReferencePosition position(double? value, double min, double max) =>
        value == null
        ? ReferencePosition.unavailable
        : value < min
        ? ReferencePosition.below
        : value > max
        ? ReferencePosition.above
        : ReferencePosition.within;
    return GrowingConditions(
      at: at,
      sampleAt: sample?.receivedAt,
      daytime: day,
      minimumTemperature: lower,
      maximumTemperature: upper,
      temperature: t,
      humidity: rh,
      soil: fresh && sample!.soilCalibrated && _valid(sample.soil, 0, 100)
          ? sample.soil
          : null,
      temperaturePosition: position(t, lower, upper),
      humidityPosition: position(rh, 65, 75),
    );
  }

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'sample_at': sampleAt?.toIso8601String(),
    'daytime': daytime,
    'minimum_temperature': minimumTemperature,
    'maximum_temperature': maximumTemperature,
    'temperature': temperature,
    'humidity': humidity,
    'soil': soil,
    'temperature_position': temperaturePosition.name,
    'humidity_position': humidityPosition.name,
  };
  factory GrowingConditions.fromJson(Map value) => GrowingConditions(
    at: DateTime.parse(value['at'] as String),
    sampleAt: value['sample_at'] == null
        ? null
        : DateTime.parse(value['sample_at'] as String),
    daytime: value['daytime'] as bool,
    minimumTemperature: (value['minimum_temperature'] as num).toDouble(),
    maximumTemperature: (value['maximum_temperature'] as num).toDouble(),
    temperature: (value['temperature'] as num?)?.toDouble(),
    humidity: (value['humidity'] as num?)?.toDouble(),
    soil: (value['soil'] as num?)?.toDouble(),
    temperaturePosition: ReferencePosition.values.byName(
      value['temperature_position'] as String,
    ),
    humidityPosition: ReferencePosition.values.byName(
      value['humidity_position'] as String,
    ),
  );
}

enum EvidenceState {
  noContext,
  notAssessable,
  partial,
  currentMatch,
  notMatching,
  durationNotEstablished,
  favorableHistory,
}

class EnvironmentalEvidence {
  const EnvironmentalEvidence(
    this.state,
    this.message, {
    this.observedSeconds = 0,
    this.requiredSeconds,
    this.averageTemperature,
  });
  final EvidenceState state;
  final String message;
  final int observedSeconds;
  final int? requiredSeconds;
  final double? averageTemperature;
  Map<String, dynamic> toJson() => {
    'state': state.name,
    'message': message,
    'observed_seconds': observedSeconds,
    'required_seconds': requiredSeconds,
    'average_temperature': averageTemperature,
  };
  factory EnvironmentalEvidence.fromJson(Map value) => EnvironmentalEvidence(
    EvidenceState.values.byName(value['state'] as String),
    value['message'] as String,
    observedSeconds: value['observed_seconds'] as int,
    requiredSeconds: value['required_seconds'] as int?,
    averageTemperature: (value['average_temperature'] as num?)?.toDouble(),
  );
}

bool _temperatureMatches(HardwareSample sample, TomatoEnvironmentRule rule) =>
    rule.minimumTemperature == null ||
    (_valid(sample.temperature, -40, 80) &&
        sample.temperature! >= rule.minimumTemperature! &&
        sample.temperature! <= rule.maximumTemperature!);
bool _humidityMatches(HardwareSample sample, TomatoEnvironmentRule rule) =>
    rule.minimumHumidity == null ||
    (_valid(sample.humidity, 0, 100) &&
        (rule.humidityExclusive
            ? sample.humidity! > rule.minimumHumidity!
            : sample.humidity! >= rule.minimumHumidity!));

EnvironmentalEvidence assessTomatoEvidence(
  String label,
  HardwareSample? sample,
  Iterable<HardwareSample> history,
  DateTime at,
) {
  if (!recentTomatoSample(sample, at)) {
    return const EnvironmentalEvidence(
      EvidenceState.noContext,
      'No recent sensor readings are linked to this photo.',
    );
  }
  final rule = tomatoKnowledge[label]?.rule;
  if (rule == null) {
    return const EnvironmentalEvidence(
      EvidenceState.notAssessable,
      'These sensors cannot reliably assess this condition. Use the image and inspection guidance.',
    );
  }
  if ((rule.minimumTemperature != null &&
          !_valid(sample!.temperature, -40, 80)) ||
      (rule.minimumHumidity != null && !_valid(sample!.humidity, 0, 100))) {
    return const EnvironmentalEvidence(
      EvidenceState.noContext,
      'A measurement required for this reference is unavailable.',
    );
  }
  if (rule.requiresLeafWetness) {
    return const EnvironmentalEvidence(
      EvidenceState.durationNotEstablished,
      'Duration not established. This reference requires measured leaf wetness; air humidity cannot replace it.',
    );
  }
  // Only late blight has a numerical exposure rule in this reference version.
  // Its source specifies average temperature, rather than every sample in-band.
  if (rule.duration != null) {
    final required = rule.duration!;
    if (sample!.deviceId.isEmpty) {
      return EnvironmentalEvidence(
        EvidenceState.durationNotEstablished,
        'Duration not established. Sensor identity is unavailable.',
        requiredSeconds: required.inSeconds,
      );
    }
    final readings =
        history
            .where(
              (s) =>
                  s.crop == sample.crop &&
                  !s.receivedAt.isAfter(sample.receivedAt),
            )
            .toList()
          ..add(sample);
    readings.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final ids = <String>{};
    HardwareSample? newer;
    var elapsed = Duration.zero;
    var weightedTemperature = 0.0;
    for (final reading in readings) {
      if (reading.deviceId != sample.deviceId) break;
      if (!ids.add(reading.id)) continue;
      if (!_valid(reading.temperature, -40, 80) ||
          !_humidityMatches(reading, rule)) {
        break;
      }
      if (newer != null) {
        final interval = newer.receivedAt.difference(reading.receivedAt);
        if (interval > const Duration(seconds: 30)) break;
        final remaining = required - elapsed;
        final used = interval > remaining ? remaining : interval;
        weightedTemperature += reading.temperature! * used.inMicroseconds;
        elapsed += used;
        if (elapsed >= required) break;
      }
      newer = reading;
    }
    if (elapsed < required) {
      return EnvironmentalEvidence(
        EvidenceState.durationNotEstablished,
        'Duration not established. The reference needs about 10 hours of continuous high-humidity observations with suitable average temperature.',
        observedSeconds: elapsed.inSeconds,
        requiredSeconds: required.inSeconds,
      );
    }
    final average = weightedTemperature / elapsed.inMicroseconds;
    final matches =
        average >= rule.minimumTemperature! &&
        average <= rule.maximumTemperature!;
    return EnvironmentalEvidence(
      matches ? EvidenceState.favorableHistory : EvidenceState.notMatching,
      matches
          ? 'Recorded conditions match one published favorable exposure reference. This does not confirm infection.'
          : 'Recorded average temperature does not match this favorable reference. Disease is not ruled out.',
      observedSeconds: elapsed.inSeconds,
      requiredSeconds: required.inSeconds,
      averageTemperature: average,
    );
  }
  if (!_temperatureMatches(sample!, rule) || !_humidityMatches(sample, rule)) {
    return const EnvironmentalEvidence(
      EvidenceState.notMatching,
      'Linked readings do not match this particular favorable reference. Disease is not ruled out.',
    );
  }
  if (rule.qualitativeRequirement != null) {
    return EnvironmentalEvidence(
      EvidenceState.partial,
      'Some linked readings match the reference. ${rule.qualitativeRequirement}',
    );
  }
  return const EnvironmentalEvidence(
    EvidenceState.currentMatch,
    'Linked readings match a published favorable condition. Exposure duration and infection are not established.',
  );
}

class TomatoAssessment {
  const TomatoAssessment({
    required this.referenceVersion,
    required this.context,
    required this.conditions,
    required this.evidence,
  });
  final String referenceVersion, context;
  final GrowingConditions conditions;
  final EnvironmentalEvidence evidence;
  factory TomatoAssessment.assess({
    required String label,
    required String context,
    required HardwareSample sample,
    required Iterable<HardwareSample> history,
    required DateTime at,
  }) => TomatoAssessment(
    referenceVersion: tomatoReferenceVersion,
    context: context,
    conditions: GrowingConditions.assess(sample, at),
    evidence: assessTomatoEvidence(label, sample, history, at),
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'reference_version': referenceVersion,
    'context': context,
    'conditions': conditions.toJson(),
    'evidence': evidence.toJson(),
  };
  static TomatoAssessment? tryFromJson(Map? value) {
    if (value == null || value['version'] != 1) return null;
    try {
      return TomatoAssessment(
        referenceVersion: value['reference_version'] as String,
        context: value['context'] as String,
        conditions: GrowingConditions.fromJson(value['conditions'] as Map),
        evidence: EnvironmentalEvidence.fromJson(value['evidence'] as Map),
      );
    } on Object {
      // Optional future/corrupt context must not hide an otherwise readable scan.
      return null;
    }
  }
}
