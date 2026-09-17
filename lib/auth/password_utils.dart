class PasswordStrength {
  const PasswordStrength({
    required this.hasSpecialCharacter,
    required this.hasTwoNumbers,
    required this.hasUppercase,
    required this.hasMinimumLength,
    required this.isWithinMaximumLength,
  });

  final bool hasSpecialCharacter;
  final bool hasTwoNumbers;
  final bool hasUppercase;
  final bool hasMinimumLength;
  final bool isWithinMaximumLength;

  bool get isValid =>
      hasSpecialCharacter &&
      hasTwoNumbers &&
      hasUppercase &&
      hasMinimumLength &&
      isWithinMaximumLength;

  int get score => [
    hasSpecialCharacter,
    hasTwoNumbers,
    hasUppercase,
    hasMinimumLength,
    isWithinMaximumLength,
  ].where((requirement) => requirement).length;

  String get label {
    if (isWithinMaximumLength == false) return 'Too long';
    if (score <= 1) return 'Weak';
    if (score <= 3) return 'Fair';
    if (score == 4) return 'Good';
    return 'Strong';
  }
}

PasswordStrength evaluatePasswordStrength(String password) {
  final numericCount = RegExp(r'[0-9]').allMatches(password).length;
  return PasswordStrength(
    hasSpecialCharacter: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    hasTwoNumbers: numericCount >= 2,
    hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
    hasMinimumLength: password.length >= 6,
    isWithinMaximumLength: password.length <= 32,
  );
}
