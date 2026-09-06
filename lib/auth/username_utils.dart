String buildUsernameFromName(String name) {
  final normalized = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.length > 30 ? normalized.substring(0, 30) : normalized;
}

String normalizeUsernameInput(String username) {
  final normalized = username.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9_]'),
    '',
  );
  return normalized.length > 30 ? normalized.substring(0, 30) : normalized;
}

bool isUsernameFormatValid(String username) {
  return RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username);
}
