/// Maps Firebase Authentication error codes to messages a student can act on.
///
/// Kept as a pure function (no Firebase import) so it is unit-testable.
/// With email-enumeration protection enabled, Firebase reports a wrong email
/// and a wrong password with the same `invalid-credential` code on purpose.
String authErrorMessage(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'An account with this email already exists';
    case 'invalid-email':
      return 'This email address is not valid';
    case 'weak-password':
      return 'This password is too weak – use at least 6 characters';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Incorrect email or password';
    case 'user-disabled':
      return 'This account has been disabled';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again';
    case 'network-request-failed':
      return 'No internet connection. Check your network and try again';
    case 'operation-not-allowed':
      return 'Email sign-in is not enabled for this app';
    default:
      return 'Something went wrong. Please try again';
  }
}
