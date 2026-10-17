import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/app_user.dart';

/// App-wide login state built from the Firebase auth-state listener.
///
/// The router listens to this object: screens never decide where to go after
/// login or logout, navigation simply reacts to [isLoggedIn].
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._repository, {UserRepository? userRepository})
      : _userRepository = userRepository,
        _user = _repository.currentUser {
    _subscription = _repository.userChanges().listen((user) {
      _user = user;
      if (user != null) _userRepository?.ensureProfile(user);
      notifyListeners();
    });
  }

  final AuthRepository _repository;
  final UserRepository? _userRepository;
  late final StreamSubscription<AppUser?> _subscription;
  AppUser? _user;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> signOut() => _repository.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
