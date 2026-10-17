/// The signed-in user, independent of the Firebase SDK types.
class AppUser {
  const AppUser({required this.uid, required this.email, this.displayName});

  final String uid;
  final String email;
  final String? displayName;

  /// Name to show in the UI, falling back to the part of the email before @.
  String get name {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return email.split('@').first;
  }
}
