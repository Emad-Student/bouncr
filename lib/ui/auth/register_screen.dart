import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../widgets/brand_header.dart';
import '../widgets/form_widgets.dart';
import 'auth_view_model.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final state = vm.state;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(
                      subtitle: 'Create your account to get event tickets',
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      key: const Key('register_name'),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      onChanged: vm.onDisplayNameChanged,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        helperText: 'Shown to organisers when you check in',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: state.displayNameError,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('register_email'),
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
                      key: const Key('register_password'),
                      label: 'Password',
                      errorText: state.passwordError,
                      onChanged: vm.onPasswordChanged,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      key: const Key('register_confirm'),
                      label: 'Confirm password',
                      errorText: state.confirmPasswordError,
                      onChanged: vm.onConfirmPasswordChanged,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => vm.register(),
                    ),
                    if (state.generalError != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(state.generalError!),
                    ],
                    const SizedBox(height: 24),
                    LoadingButton(
                      key: const Key('register_submit'),
                      label: 'Create account',
                      isLoading: state.isLoading,
                      onPressed: vm.register,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: state.isLoading ? null : () => context.pop(),
                      child: const Text('Already have an account? Log in'),
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
