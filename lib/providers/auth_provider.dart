import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'fcm_provider.dart'; // Import FCM provider

class AuthProvider with ChangeNotifier {
  User? user;
  bool _isLoading = true;
  late GoogleSignIn _googleSignIn;
  String _errorMessage = '';
  FCMProvider? _fcmProvider; // Reference to FCM provider

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Set FCM provider reference
  void setFCMProvider(FCMProvider fcmProvider) {
    _fcmProvider = fcmProvider;
  }

  AuthProvider() {
    // Initialize Google Sign In based on platform
    _googleSignIn = GoogleSignIn();
    
    try {    
      // Add a print statement to verify Firebase initialization
      print('Initializing Firebase Auth listener');
      
      FirebaseAuth.instance.authStateChanges().listen((u) {
        print('Auth state changed: ${u?.uid ?? 'User is null'}');
        user = u;
        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        print('Auth state change error: $error');
        _isLoading = false;
        _errorMessage = 'Authentication error: $error';
        notifyListeners();
      });
    } catch (e) {
      print('Error in AuthProvider constructor: $e');
      _isLoading = false;
      _errorMessage = 'Authentication initialization error: $e';
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      print('Attempting to sign in with Google: ${kIsWeb ? 'Web Platform' : 'Mobile Platform'}');
      
      UserCredential userCredential;
      
      if (kIsWeb) {
        // Web implementation of Google Sign-In
        print('Using Firebase Auth Google provider for web');
        // Create a GoogleAuthProvider
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        // Pop-up sign-in for Web
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        print('Web Google Sign-In successful: ${userCredential.user?.uid}');
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          _isLoading = false;
          notifyListeners();
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // Create user doc if not exists (shared between web & mobile)
      final user = userCredential.user;
      if (user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final doc = await userDoc.get();
        if (!doc.exists) {
          await userDoc.set({
            'name': user.displayName ?? 'User',
            'email': user.email ?? '',
            'contactNumber': '',
            'address': '',
            'photoURL': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Google Sign-In error: $e');
      _errorMessage = 'Google Sign-In error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // New method for email/password sign-in
  Future<void> _signInWithEmailPassword() async {
    try {
      print('Starting email/password sign-in');
      // Try standard demo credentials
      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: 'demo@example.com',
          password: 'password123',
        );
        print('Email/password sign-in successful: ${userCredential.user?.uid}');
        
        final user = userCredential.user;
        if (user != null) {
          final userDoc = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid);
          final doc = await userDoc.get();
          if (!doc.exists) {
            await userDoc.set({
              'name': 'Web Demo User',
              'email': user.email,
              'contactNumber': '',
              'address': '',
              'photoURL': '',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        print('Demo account login failed, creating new account: $e');
        // If login fails, create the demo account
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'demo@example.com',
          password: 'password123',
        );
        
        print('Created new demo account: ${userCredential.user?.uid}');
        
        final user = userCredential.user;
        if (user != null) {
          final userDoc = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid);
          await userDoc.set({
            'name': 'Web Demo User',
            'email': user.email,
            'contactNumber': '',
            'address': '',
            'photoURL': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Email/password sign in error: $e');
      _errorMessage = 'Sign in error: $e';
    }
  }
  
  // Helper method for anonymous sign-in (keeping for reference)
  Future<void> _signInAnonymously() async {
    try {
      print('Starting anonymous sign-in');
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      print('Anonymous sign-in successful: ${userCredential.user?.uid}');
      
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
      _errorMessage = 'Anonymous sign in error: $e';
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Cleanup FCM before signing out
      if (_fcmProvider != null) {
        await _fcmProvider!.cleanUp();
      }
      
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
