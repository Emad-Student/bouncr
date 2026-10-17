import 'package:bouncr/domain/auth_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate email gets a readable message', () {
    expect(authErrorMessage('email-already-in-use'),
        'An account with this email already exists');
  });

  test('wrong email and wrong password share one message', () {
    const expected = 'Incorrect email or password';
    expect(authErrorMessage('invalid-credential'), expected);
    expect(authErrorMessage('wrong-password'), expected);
    expect(authErrorMessage('user-not-found'), expected);
  });

  test('unknown codes never leak technical details', () {
    expect(authErrorMessage('internal-error'), 'Something went wrong. Please try again');
  });
}
