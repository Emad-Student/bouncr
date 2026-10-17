import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../navigation/routes.dart';
import '../widgets/brand_header.dart';
import '../widgets/form_widgets.dart';
import 'auth_view_model.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final state = vm.state;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(
                      subtitle: 'The digital bouncer for student events',
                    ),
                    const SizedBox(height: 36),
                    TextField(
                      key: const Key('login_email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      onChanged: vm.onEmailChanged,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.alternate_email),
                        errorText: state.emailError,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      key: const Key('login_password'),
                      label: 'Password',
                      errorText: state.passwordError,
                      onChanged: vm.onPasswordChanged,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => vm.login(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('forgot_password'),
                        onPressed: state.isLoading
                            ? null
                            : () async {
                                final sent = await vm.sendPasswordReset();
                                if (sent && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text(
                                        'If an account exists for this email, a reset link is on its way.'),
                                  ));
                                }
                              },
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    if (state.generalError != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(state.generalError!),
                    ],
                    const SizedBox(height: 24),
                    LoadingButton(
                      key: const Key('login_submit'),
                      label: 'Log in',
                      isLoading: state.isLoading,
                      onPressed: vm.login,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context.push(Routes.register),
                      child: const Text('No account? Register'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
