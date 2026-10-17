import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/session_view_model.dart';

/// Temporary home screen for the walking skeleton (Lab 1).
/// It is replaced by the events list in Lab 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const problemStatement =
      'Student clubs run their events with Google Forms and screenshot '
      '"tickets", so tickets get copied and shared, events get overbooked, '
      'and organisers have no reliable way to check who is allowed in.';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bouncr')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('The problem we solve', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(problemStatement, style: text.bodyLarge),
            const Spacer(),
            Text(
              'Logged in as ${session.user?.email ?? ''}',
              key: const Key('home_logged_in_as'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('home_logout'),
              onPressed: session.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
