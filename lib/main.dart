import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config.dart';
import 'data/auth_repository.dart';
import 'data/event_repository.dart';
import 'data/ticket_repository.dart';
import 'data/user_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);
  if (AppConfig.usesFunctionsEmulator) {
    // FlutterFire rewrites 127.0.0.1 to 10.0.2.2 on Android, which only exists
    // inside the Android emulator. With `adb reverse tcp:5001 tcp:5001`,
    // 127.0.0.1 reaches the computer from emulators and USB phones alike.
    functions.useFunctionsEmulator(
      AppConfig.functionsEmulatorHost,
      AppConfig.functionsEmulatorPort,
      automaticHostMapping: false,
    );
  }

  runApp(BouncrApp(
    authRepository: FirebaseAuthRepository(FirebaseAuth.instance),
    eventRepository: FirestoreEventRepository(firestore),
    ticketRepository: FirebaseTicketRepository(firestore, functions),
    userRepository: FirestoreUserRepository(firestore),
  ));
}
