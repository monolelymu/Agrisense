String? validateLimit(
  String? text, {
  required double minimum,
  required double maximum,
}) {
  final value = double.tryParse(text?.trim() ?? '');
  if (value == null || !value.isFinite) return 'Enter a valid number.';
  if (value < minimum || value > maximum) return 'Use $minimum to $maximum.';
  return null;
}

String? validateSeconds(
  String? text, {
  required int minimum,
  required int maximum,
}) {
  final value = int.tryParse(text?.trim() ?? '');
  if (value == null) return 'Enter whole seconds.';
  if (value < minimum || value > maximum) {
    return 'Use $minimum to $maximum seconds.';
  }
  return null;
}
