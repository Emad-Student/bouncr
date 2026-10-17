/// Pure input validation for the auth forms.
///
/// Deliberately free of Flutter/Android imports so it can be unit-tested on
/// the plain Dart VM. Every function returns an error message or `null`.
class AuthValidator {
  AuthValidator._();

  /// Firebase Authentication rejects shorter passwords.
  static const int minPasswordLength = 6;
  static const int maxDisplayNameLength = 40;

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? validateEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return 'Email is required';
    if (!_email.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }

  static String? validatePasswordConfirmation(
    String password,
    String confirmation,
  ) {
    if (confirmation.isEmpty) return 'Please confirm your password';
    if (password != confirmation) return 'Passwords do not match';
    return null;
  }

  static String? validateDisplayName(String name) {
    final value = name.trim();
    if (value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Name is too short';
    if (value.length > maxDisplayNameLength) {
      return 'Name must be at most $maxDisplayNameLength characters';
    }
    return null;
  }
}
