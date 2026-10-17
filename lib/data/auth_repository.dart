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
        email: email.trim(),
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
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();

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
