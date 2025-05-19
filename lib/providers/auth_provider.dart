import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthProvider with ChangeNotifier {
  User? user;
  bool _isLoading = true;
  late GoogleSignIn _googleSignIn;

  bool get isLoading => _isLoading;

  AuthProvider() {
    // Initialize Google Sign In based on platform
    _googleSignIn = GoogleSignIn();
        
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // For web platform, use anonymous sign-in as a fallback
      if (kIsWeb) {
        await _signInAnonymously();
        return;
      }
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

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
    } catch (e) {
      print('Sign in error: $e');
      // Fallback to anonymous sign-in if Google sign-in fails
      if (kIsWeb) {
        await _signInAnonymously();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Helper method for anonymous sign-in
  Future<void> _signInAnonymously() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final user = userCredential.user;
      if (user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final doc = await userDoc.get();
        if (!doc.exists) {
          await userDoc.set({
            'name': 'Web User',
            'email': '',
            'contactNumber': '',
            'address': '',
            'photoURL': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Anonymous sign in error: $e');
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      print('Sign out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
