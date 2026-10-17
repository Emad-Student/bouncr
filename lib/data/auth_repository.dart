import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';
import '../domain/auth_error_messages.dart';
import '../domain/result.dart';

/// Authentication operations the app needs. The UI depends on this
/// interface only, never on the Firebase SDK.
abstract interface class AuthRepository {
  /// Emits the current user on sign-in, sign-out and profile changes.
  Stream<AppUser?> userChanges();

  AppUser? get currentUser;

  Future<Result<void>> signIn({required String email, required String password});

  Future<Result<void>> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Sends a password-reset link. Succeeds even if no account exists, so the
  /// app does not reveal which emails are registered.
  Future<Result<void>> sendPasswordReset(String email);
}

/// [AuthRepository] backed by Firebase Authentication. This is the only class
/// in the app that talks to `FirebaseAuth`.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> userChanges() => _auth.userChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      await _auth.signInWithEmailAndPassword(
        email: _normalise(email),
        password: password,
      );
    });
  }

  @override
  Future<Result<void>> register({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _normalise(email),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    final result = await _guard(() => _auth.sendPasswordResetEmail(email: _normalise(email)));
    // "user-not-found" is reported as success on purpose (see interface).
    if (result case Failure(:final message)
        when message == authErrorMessage('user-not-found')) {
      return const Result.success(null);
    }
    return result;
  }

  /// Emails are case-insensitive; trimming avoids "invisible" typos.
  static String _normalise(String email) => email.trim().toLowerCase();

  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Result.success(null);
    } on FirebaseAuthException catch (e) {
      return Result.failure(authErrorMessage(e.code));
    } catch (_) {
      return Result.failure(authErrorMessage('unknown'));
    }
  }

  static AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }
}
