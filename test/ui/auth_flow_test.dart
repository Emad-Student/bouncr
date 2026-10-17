import 'dart:async';

import 'package:bouncr/app.dart';
import 'package:bouncr/data/auth_repository.dart';
import 'package:bouncr/domain/app_user.dart';
import 'package:bouncr/domain/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [AuthRepository] so the UI can be tested without Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedIn}) : _user = signedIn;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  int calls = 0;
  String? failWith;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> userChanges() => _controller.stream;

  void _set(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<Result<void>> signIn({required String email, required String password}) async {
    calls++;
    if (failWith != null) return Result.failure(failWith!);
    _set(AppUser(uid: 'u1', email: email));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    calls++;
    if (failWith != null) return Result.failure(failWith!);
    _set(AppUser(uid: 'u1', email: email, displayName: displayName));
    return const Result.success(null);
  }

  @override
  Future<void> signOut() async => _set(null);
}

void main() {
  testWidgets('invalid input shows field errors without calling the backend',
      (tester) async {
    final repo = FakeAuthRepository();
    await tester.pumpWidget(BouncrApp(authRepository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_email')), 'not-an-email');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(repo.calls, 0);
  });

  testWidgets('register validates every field before calling the backend',
      (tester) async {
    final repo = FakeAuthRepository();
    await tester.pumpWidget(BouncrApp(authRepository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No account? Register'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('register_name')), 'Anna');
    await tester.enterText(find.byKey(const Key('register_email')), 'anna@uni.pl');
    await tester.enterText(find.byKey(const Key('register_password')), '123');
    await tester.enterText(find.byKey(const Key('register_confirm')), '1234');
    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(repo.calls, 0);
  });

  testWidgets('backend errors are shown as readable messages', (tester) async {
    final repo = FakeAuthRepository()..failWith = 'Incorrect email or password';
    await tester.pumpWidget(BouncrApp(authRepository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_email')), 'anna@uni.pl');
    await tester.enterText(find.byKey(const Key('login_password')), 'wrong-pass');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password'), findsOneWidget);
  });

  testWidgets('login opens home, logout returns to login', (tester) async {
    final repo = FakeAuthRepository();
    await tester.pumpWidget(BouncrApp(authRepository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_email')), 'anna@uni.pl');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret1');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Logged in as anna@uni.pl'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_logout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
  });

  testWidgets('a signed-in user skips the login screen (auto-login)',
      (tester) async {
    final repo = FakeAuthRepository(
        signedIn: const AppUser(uid: 'u1', email: 'anna@uni.pl'));
    await tester.pumpWidget(BouncrApp(authRepository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Logged in as anna@uni.pl'), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsNothing);
  });
}
