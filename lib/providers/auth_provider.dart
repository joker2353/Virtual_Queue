import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  User? user;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );

    // Create user doc if not exists
    final user = userCredential.user;
    if (user != null) {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await userDoc.get();
      if (!doc.exists) {
        await userDoc.set({
          'name': user.displayName,
          'email': user.email,
          'contactNumber': '',
          'address': '',
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }
}
