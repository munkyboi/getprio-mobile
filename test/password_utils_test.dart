import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/password_utils.dart';

void main() {
  test('accepts the customer registration password requirements', () {
    final strength = evaluatePasswordStrength('Upper!12');

    expect(strength.isValid, isTrue);
    expect(strength.hasSpecialCharacter, isTrue);
    expect(strength.hasTwoNumbers, isTrue);
    expect(strength.hasUppercase, isTrue);
    expect(strength.hasMinimumLength, isTrue);
    expect(strength.isWithinMaximumLength, isTrue);
  });

  test('rejects passwords that miss a required rule or exceed the maximum', () {
    expect(evaluatePasswordStrength('upper!1').isValid, isFalse);
    expect(evaluatePasswordStrength('Upper12').isValid, isFalse);
    expect(
      evaluatePasswordStrength('Upper!1234567890123456789012345678').isValid,
      isFalse,
    );
    expect(evaluatePasswordStrength('Upper!12').score, 5);
  });
}
