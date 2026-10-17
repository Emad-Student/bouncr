import 'package:bouncr/domain/auth_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateEmail', () {
    test('accepts a normal address and ignores surrounding spaces', () {
      expect(AuthValidator.validateEmail('anna@student.wsb.edu.pl'), isNull);
      expect(AuthValidator.validateEmail('  anna@uni.pl  '), isNull);
    });

    test('rejects empty input', () {
      expect(AuthValidator.validateEmail(''), 'Email is required');
      expect(AuthValidator.validateEmail('   '), 'Email is required');
    });

    test('rejects malformed addresses', () {
      for (final email in ['anna', 'anna@', '@uni.pl', 'anna@uni', 'an na@uni.pl']) {
        expect(AuthValidator.validateEmail(email), 'Enter a valid email address',
            reason: email);
      }
    });
  });

  group('validatePassword', () {
    test('requires a value', () {
      expect(AuthValidator.validatePassword(''), 'Password is required');
    });

    test('enforces the Firebase minimum of 6 characters', () {
      expect(AuthValidator.validatePassword('12345'),
          'Password must be at least 6 characters');
      expect(AuthValidator.validatePassword('123456'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('requires a confirmation', () {
      expect(AuthValidator.validatePasswordConfirmation('secret1', ''),
          'Please confirm your password');
    });

    test('detects a mismatch', () {
      expect(AuthValidator.validatePasswordConfirmation('secret1', 'secret2'),
          'Passwords do not match');
    });

    test('accepts matching passwords', () {
      expect(
          AuthValidator.validatePasswordConfirmation('secret1', 'secret1'), isNull);
    });
  });

  group('validateDisplayName', () {
    test('requires 2 to 40 characters', () {
      expect(AuthValidator.validateDisplayName(' '), 'Name is required');
      expect(AuthValidator.validateDisplayName('A'), 'Name is too short');
      expect(AuthValidator.validateDisplayName('A' * 41),
          'Name must be at most 40 characters');
      expect(AuthValidator.validateDisplayName('Anna Kowalska'), isNull);
    });
  });
}
