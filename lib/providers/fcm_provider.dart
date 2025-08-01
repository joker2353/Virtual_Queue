import 'package:flutter/foundation.dart';
import '../services/fcm_service.dart';
import '../models/queue_notification.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class FCMProvider extends ChangeNotifier {
  final FCMService _fcmService = FCMService.instance;
  bool _isInitialized = false;
  String? _userId;
  String? _fcmToken;

  // Getters
  bool get isInitialized => _isInitialized;
  String? get userId => _userId;
  String? get fcmToken => _fcmToken;

  // Initialize provider with user ID
  Future<void> initialize(String userId) async {
    if (_isInitialized) return;
    _userId = userId;
    await _setupFCM();
    _isInitialized = true;

    // Explicitly request notification permissions
    if (!kIsWeb) {
      debugPrint('FCMProvider: Explicitly requesting notification permissions');
      await requestPermissions();
    }

    notifyListeners();
  }

  Future<void> _setupFCM() async {
    if (kIsWeb) {
      // Web platform setup
      _fcmToken = await FirebaseMessaging.instance.getToken(
        vapidKey: 'YOUR_VAPID_KEY', // Replace with your VAPID key
      );
    } else {
      // Mobile platform setup
      _fcmToken = await FirebaseMessaging.instance.getToken();
    }

    // Save the token to Firestore
    if (_fcmToken != null && _userId != null) {
      await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .set({
            'fcmToken': _fcmToken,
            'lastUpdated': DateTime.now(),
          }, firestore.SetOptions(merge: true));
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _updateToken();
    });
  }

  Future<void> _updateToken() async {
    if (_fcmToken != null && _userId != null) {
      await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({'fcmToken': _fcmToken, 'lastUpdated': DateTime.now()});
    }
  }

  // Explicitly request notification permissions
  Future<bool> requestPermissions() async {
    return await _fcmService.requestNotificationPermissions();
  }

  // Send notification when it's the user's turn
  Future<void> sendYourTurnNotification({
    required String userId,
    required String roomId,
    required String roomName,
    required int position,
  }) async {
    if (!_isInitialized) {
      debugPrint('FCMProvider: Not initialized');
      return;
    }

    final notification = QueueNotification.yourTurn(
      roomId: roomId,
      roomName: roomName,
      position: position,
    );

    await _fcmService.sendQueueNotification(userId, notification);
  }

  // Send notification when the queue advances
  Future<void> sendQueueAdvancedNotification({
    required String userId,
    required String roomId,
    required String roomName,
    required int currentPosition,
    required int userPosition,
  }) async {
    if (!_isInitialized) {
      debugPrint('FCMProvider: Not initialized');
      return;
    }

    final notification = QueueNotification.queueAdvanced(
      roomId: roomId,
      roomName: roomName,
      currentPosition: currentPosition,
      userPosition: userPosition,
    );

    await _fcmService.sendQueueNotification(userId, notification);
  }

  // New method to send ready for pickup notification
  Future<void> sendReadyForPickupNotification({
    required String customerContact,
    required String orderNumber,
    required String shopName,
  }) async {
    try {
      // Get the customer's FCM token from their document
      final customerDoc =
          await firestore.FirebaseFirestore.instance
              .collection('customers')
              .doc(customerContact)
              .get();

      final String? customerFCMToken = customerDoc.data()?['fcmToken'];

      if (customerFCMToken == null) {
        print('No FCM token found for customer: $customerContact');
        return;
      }

      // Create the notification message
      final message = {
        'notification': {
          'title': 'Order Ready for Pickup! 🛍️',
          'body':
              'Your order #$orderNumber from $shopName is ready for pickup.',
        },
        'data': {
          'type': 'order_ready',
          'orderNumber': orderNumber,
          'shopName': shopName,
        },
        'token': customerFCMToken,
      };

      // Send the notification using Cloud Functions
      await firestore.FirebaseFirestore.instance
          .collection('notifications')
          .add({
            ...message,
            'timestamp': firestore.FieldValue.serverTimestamp(),
            'status': 'pending',
            'customerContact': customerContact,
          });

      print('Ready for pickup notification sent to customer: $customerContact');
    } catch (e) {
      print('Error sending ready for pickup notification: $e');
    }
  }

  // Clean up when user logs out
  Future<void> cleanUp() async {
    if (_isInitialized) {
      await _fcmService.cleanUp();
      _isInitialized = false;
      _userId = null;
      _fcmToken = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isInitialized = false;
    _userId = null;
    _fcmToken = null;
    super.dispose();
  }
}
