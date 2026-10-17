import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_validator.dart';
import '../../domain/result.dart';

/// Immutable state of the login / register form.
@immutable
class AuthUiState {
  const AuthUiState({
    this.displayName = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.displayNameError,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.generalError,
    this.isLoading = false,
  });

  final String displayName;
  final String email;
  final String password;
  final String confirmPassword;
  final String? displayNameError;
  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;
  final String? generalError;
  final bool isLoading;

  AuthUiState copyWith({
    String? displayName,
    String? email,
    String? password,
    String? confirmPassword,
    String? Function()? displayNameError,
    String? Function()? emailError,
    String? Function()? passwordError,
    String? Function()? confirmPasswordError,
    String? Function()? generalError,
    bool? isLoading,
  }) {
    return AuthUiState(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      displayNameError:
          displayNameError != null ? displayNameError() : this.displayNameError,
      emailError: emailError != null ? emailError() : this.emailError,
      passwordError: passwordError != null ? passwordError() : this.passwordError,
      confirmPasswordError: confirmPasswordError != null
          ? confirmPasswordError()
          : this.confirmPasswordError,
      generalError: generalError != null ? generalError() : this.generalError,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Holds the form state, validates input and calls the [AuthRepository].
///
/// A fresh instance is created for each auth screen. Successful login or
/// registration does not navigate: the router reacts to the session instead.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository);

  final AuthRepository _repository;
  AuthUiState _state = const AuthUiState();
  bool _disposed = false;

  AuthUiState get state => _state;

  void _emit(AuthUiState next) {
    _state = next;
    // After a successful login the router removes this screen (and disposes
    // this view model) while the request may still be completing.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Typing clears the error of the edited field and the general error.
  void onDisplayNameChanged(String v) => _emit(_state.copyWith(
      displayName: v, displayNameError: () => null, generalError: () => null));
  void onEmailChanged(String v) => _emit(_state.copyWith(
      email: v, emailError: () => null, generalError: () => null));
  void onPasswordChanged(String v) => _emit(_state.copyWith(
      password: v, passwordError: () => null, generalError: () => null));
  void onConfirmPasswordChanged(String v) => _emit(_state.copyWith(
      confirmPassword: v,
      confirmPasswordError: () => null,
      generalError: () => null));

  Future<void> login() async {
    if (_state.isLoading) return;
    final emailError = AuthValidator.validateEmail(_state.email);
    final passwordError = _state.password.isEmpty ? 'Password is required' : null;
    _emit(_state.copyWith(
      emailError: () => emailError,
      passwordError: () => passwordError,
      generalError: () => null,
    ));
    if (emailError != null || passwordError != null) return;

    await _submit(() => _repository.signIn(
          email: _state.email,
          password: _state.password,
        ));
  }

  Future<void> register() async {
    if (_state.isLoading) return;
    final nameError = AuthValidator.validateDisplayName(_state.displayName);
    final emailError = AuthValidator.validateEmail(_state.email);
    final passwordError = AuthValidator.validatePassword(_state.password);
    final confirmError = AuthValidator.validatePasswordConfirmation(
        _state.password, _state.confirmPassword);
    _emit(_state.copyWith(
      displayNameError: () => nameError,
      emailError: () => emailError,
      passwordError: () => passwordError,
      confirmPasswordError: () => confirmError,
      generalError: () => null,
    ));
    if ([nameError, emailError, passwordError, confirmError]
        .any((e) => e != null)) {
      return;
    }

    await _submit(() => _repository.register(
          displayName: _state.displayName,
          email: _state.email,
          password: _state.password,
        ));
  }

  /// Returns true when the reset email was sent (or the address is unknown).
  Future<bool> sendPasswordReset() async {
    if (_state.isLoading) return false;
    final emailError = AuthValidator.validateEmail(_state.email);
    _emit(_state.copyWith(emailError: () => emailError, generalError: () => null));
    if (emailError != null) return false;
    _emit(_state.copyWith(isLoading: true));
    final result = await _repository.sendPasswordReset(_state.email);
    switch (result) {
      case Success():
        _emit(_state.copyWith(isLoading: false));
        return true;
      case Failure(:final message):
        _emit(_state.copyWith(isLoading: false, generalError: () => message));
        return false;
    }
  }

  Future<void> _submit(Future<Result<void>> Function() call) async {
    _emit(_state.copyWith(isLoading: true));
    final result = await call();
    switch (result) {
      case Success():
        _emit(_state.copyWith(isLoading: false));
      case Failure(:final message):
        _emit(_state.copyWith(isLoading: false, generalError: () => message));
    }
  }
}
