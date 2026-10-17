import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';

abstract interface class UserRepository {
  /// Creates `users/{uid}` on first sign-in and keeps the name in sync.
  Future<void> ensureProfile(AppUser user);
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> ensureProfile(AppUser user) async {
    final ref = _db.collection('users').doc(user.uid);
    final name = _safeName(user.name);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'email': user.email,
          'displayName': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (snap.data()?['displayName'] != name &&
          user.displayName != null) {
        await ref.update({'displayName': name});
      }
    } on FirebaseException {
      // A missing profile only affects the name shown at check-in;
      // it is retried on the next sign-in, so the app keeps working.
    }
  }

  /// The rules require 2–40 characters (an email prefix may not fit).
  static String _safeName(String name) {
    final n = name.trim();
    if (n.length < 2) return 'Student';
    return n.length > 40 ? n.substring(0, 40) : n;
  }
}
