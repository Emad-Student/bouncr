import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/auth_repository.dart';
import 'data/event_repository.dart';
import 'data/user_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  runApp(BouncrApp(
    authRepository: FirebaseAuthRepository(FirebaseAuth.instance),
    eventRepository: FirestoreEventRepository(firestore),
    userRepository: FirestoreUserRepository(firestore),
  ));
}
