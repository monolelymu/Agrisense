/// Two measured ADC endpoints, local to this phone and sensor.
class SoilCalibration {
  SoilCalibration({required this.dry, required this.wet}) {
    if (dry < 0 || dry > 4095 || wet < 0 || wet > 4095 || dry == wet) {
      throw const FormatException(
        'Enter different dry and wet readings from 0 to 4095.',
      );
    }
  }

  final int dry, wet;

  double percentage(int raw) =>
      ((raw - dry) * 100 / (wet - dry)).clamp(0, 100).toDouble();

  Map<String, dynamic> toJson() => {'version': 1, 'dry': dry, 'wet': wet};

  static SoilCalibration? tryFromJson(dynamic value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['dry'] is! int ||
        value['wet'] is! int) {
      return null;
    }
    try {
      return SoilCalibration(
        dry: value['dry'] as int,
        wet: value['wet'] as int,
      );
    } on FormatException {
      return null;
    }
  }
}
