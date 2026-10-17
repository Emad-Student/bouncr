import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../auth/auth_view_model.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/session_view_model.dart';
import '../home/home_screen.dart';
import 'routes.dart';

/// Navigation reacts to [SessionViewModel.isLoggedIn]:
/// * start destination is home when a user is signed in (auto-login),
///   otherwise login;
/// * after login/registration the redirect replaces the whole stack with home,
///   so Back cannot return to the auth screens;
/// * after logout the stack is replaced with login.
GoRouter createRouter(SessionViewModel session) {
  return GoRouter(
    initialLocation: session.isLoggedIn ? Routes.home : Routes.login,
    refreshListenable: session,
    redirect: (context, state) {
      final onAuthScreen = state.matchedLocation.startsWith(Routes.login);
      if (!session.isLoggedIn && !onAuthScreen) return Routes.login;
      if (session.isLoggedIn && onAuthScreen) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => AuthViewModel(context.read<AuthRepository>()),
          child: const LoginScreen(),
        ),
        routes: [
          GoRoute(
            path: 'register',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) => AuthViewModel(context.read<AuthRepository>()),
              child: const RegisterScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
