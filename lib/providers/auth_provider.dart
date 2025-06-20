import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'fcm_provider.dart'; // Import FCM provider

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        kIsWeb
            ? '666976149522-aqvvs0u1buvhfkndtpv00ogh3k8qj8l6.apps.googleusercontent.com'
            : null,
  );
  User? _user;
  bool _isLoading = false;
  String? _error;
  FCMProvider? _fcmProvider;

  AuthProvider() {
    _initialize();
  }

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  void _initialize() {
    try {
      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) {
        _user = user;
        print('Auth state changed: ${user?.uid}');
        notifyListeners();
      });
    } catch (e) {
      print('Error initializing auth: $e');
      _setError(e.toString());
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);

      late final AuthCredential credential;

      if (kIsWeb) {
        // Web-specific sign in
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        final userCredential = await _auth.signInWithPopup(googleProvider);
        _user = userCredential.user;
      } else {
        // Mobile sign in
        await _googleSignIn.signOut(); // Clear any existing sessions
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          throw Exception('Google Sign In was cancelled');
        }

        // Get auth details from request
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create credential
        credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in with Firebase
        final userCredential = await _auth.signInWithCredential(credential);
        _user = userCredential.user;
      }

      print('Successfully signed in with Google: ${_user?.uid}');
    } catch (e) {
      print('Error signing in with Google: $e');
      _setError('Failed to sign in with Google: ${e.toString()}');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      _setError(null);

      // Clean up FCM tokens if needed
      if (_fcmProvider != null) {
        await _fcmProvider!.cleanUp();
      }

      if (!kIsWeb) {
        // Only sign out from Google Sign In on mobile
        await _googleSignIn.signOut();
      }
      await _auth.signOut();

      _user = null;
    } catch (e) {
      print('Error signing out: $e');
      _setError('Failed to sign out: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  void setFCMProvider(FCMProvider fcmProvider) {
    _fcmProvider = fcmProvider;
  }
}
