String normalizePhilippineMobileNumber(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');

  if (digits.startsWith('63') && digits.length == 12) {
    digits = '0${digits.substring(2)}';
  } else if (digits.length == 10 && digits.startsWith('9')) {
    digits = '0$digits';
  }

  return digits.substring(0, digits.length > 11 ? 11 : digits.length);
}

bool isPhilippineMobileNumber(String value) {
  return RegExp(r'^09\d{9}$').hasMatch(normalizePhilippineMobileNumber(value));
}

String formatPhilippineMobileNumber(String value) {
  final digits = normalizePhilippineMobileNumber(value);
  if (digits.isEmpty) return '';

  final first = digits.substring(0, digits.length > 4 ? 4 : digits.length);
  if (digits.length <= 4) return '($first';

  final second = digits.substring(4, digits.length > 7 ? 7 : digits.length);
  if (digits.length <= 7) return '($first) $second';

  final third = digits.substring(7);
  return '($first) $second-$third';
}
