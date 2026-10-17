import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/auth_repository.dart';
import 'ui/auth/session_view_model.dart';
import 'ui/navigation/app_router.dart';
import 'ui/theme.dart';

class BouncrApp extends StatefulWidget {
  const BouncrApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<BouncrApp> createState() => _BouncrAppState();
}

class _BouncrAppState extends State<BouncrApp> {
  late final SessionViewModel _session = SessionViewModel(widget.authRepository);
  late final GoRouter _router = createRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: widget.authRepository),
        ChangeNotifierProvider<SessionViewModel>.value(value: _session),
      ],
      child: MaterialApp.router(
        title: 'Bouncr',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        routerConfig: _router,
      ),
    );
  }
}
