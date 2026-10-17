import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../auth/auth_view_model.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/session_view_model.dart';
import '../events/event_detail_screen.dart';
import '../events/event_form_screen.dart';
import '../events/event_form_view_model.dart';
import '../events/events_screen.dart';
import '../events/events_view_model.dart';
import 'routes.dart';

/// Navigation reacts to [SessionViewModel.isLoggedIn]:
/// * start destination is the events list when a user is signed in
///   (auto-login), otherwise login;
/// * after login/registration the redirect replaces the whole stack,
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
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => EventsViewModel(
            context.read<EventRepository>(),
            uid: session.user?.uid ?? '',
          ),
          child: const EventsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.newEvent,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => EventFormViewModel(
            context.read<EventRepository>(),
            uid: session.user?.uid ?? '',
          ),
          child: const EventFormScreen(),
        ),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => _EditEventLoader(
              eventId: state.pathParameters['id']!,
              uid: session.user?.uid ?? '',
            ),
          ),
        ],
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

/// Loads the event once, then opens the form pre-filled with it.
/// Non-owners are never shown the form (and the rules would reject a save).
class _EditEventLoader extends StatefulWidget {
  const _EditEventLoader({required this.eventId, required this.uid});

  final String eventId;
  final String uid;

  @override
  State<_EditEventLoader> createState() => _EditEventLoaderState();
}

class _EditEventLoaderState extends State<_EditEventLoader> {
  late final Future<Event?> _event =
      context.read<EventRepository>().watchEvent(widget.eventId).first;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Event?>(
      future: _event,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
              appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final event = snapshot.data;
        if (event == null || !event.isOwnedBy(widget.uid)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Only the organiser can edit this event.')),
          );
        }
        return ChangeNotifierProvider(
          create: (context) => EventFormViewModel(
            context.read<EventRepository>(),
            uid: widget.uid,
            original: event,
          ),
          child: const EventFormScreen(),
        );
      },
    );
  }
}
