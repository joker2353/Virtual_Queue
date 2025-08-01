import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/queue_notification.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

// Helper function to display notifications from background and foreground
Future<void> showLocalNotification(FlutterLocalNotificationsPlugin plugin, RemoteMessage message) async {
  debugPrint('Showing notification: ${message.notification?.title ?? "Data message"}');
  
  if (!kIsWeb) {
    // Get notification title and body from either notification payload or data payload
    String? title = message.notification?.title;
    String? body = message.notification?.body;
    
    // If notification payload is missing, try to get from data
    if (title == null && message.data.containsKey('title')) {
      title = message.data['title'];
    }
    if (body == null && message.data.containsKey('body')) {
      body = message.data['body'];
    }
    
    // Default values if still null
    title ??= 'Virtual Queue';
    body ??= 'You have a new notification';
    
    debugPrint('Showing notification with title: $title, body: $body');
    
    await plugin.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Queue Notifications',
          channelDescription: 'Notifications for queue updates',
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: message.data.isNotEmpty ? json.encode(message.data) : null,
    );
    debugPrint('Notification shown successfully');
  } else {
    debugPrint('Web platform - no local notifications');
  }
}

class FCMService {
  static FCMService? _instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _token;
  String? _userId;
  bool _notificationsInitialized = false;
  
  // Channel IDs
  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'Queue Notifications';
  static const String _channelDesc = 'Notifications for queue updates';
  
  // Singleton pattern
  static FCMService get instance {
    _instance ??= FCMService._();
    return _instance!;
  }
  
  FCMService._();
  
  // Initialize FCM service with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    
    // Background message handler is set in main.dart
    // No need to set it here again
    
    // Request permission
    await _requestPermission();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Get and save FCM token
    await _getAndSaveToken();
    
    // Setup message handling
    _setupMessageHandlers();
    
    debugPrint('FCM Service initialized for user: $userId');
  }
  
  // Request notification permissions
  Future<void> _requestPermission() async {
    if (!kIsWeb) {
      debugPrint('Requesting notification permissions...');
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: true,
        criticalAlert: true,  // Request critical alerts for terminated app
        provisional: false,
        sound: true,
      );
      
      debugPrint('FCM Permission status: ${settings.authorizationStatus}');
      
      // Check if permission was granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Notification permissions granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permissions denied');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('Notification permissions granted provisionally');
      }

      // Set foreground notification presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }
  
  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    if (_notificationsInitialized || kIsWeb) return;
    
    debugPrint('Initializing local notifications');
    
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    // iOS initialization
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    // Initialization settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    // Initialize plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        debugPrint('Notification tapped with payload: ${details.payload}');
        _handleNotificationTap(details.payload);
      },
    );
    
    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      debugPrint('Android notification channel created');
    }
    
    _notificationsInitialized = true;
    debugPrint('Local notifications initialized successfully');
  }
  
  // Public method to explicitly request permissions again if needed
  Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) return true; // Web doesn't need explicit permissions
    
    debugPrint('Manually requesting notification permissions');
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,  // Request critical alerts for terminated app
      provisional: false,
      announcement: false,
      carPlay: true,
    );
    
    final bool granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                       settings.authorizationStatus == AuthorizationStatus.provisional;
    
    debugPrint('Permission request result: $granted');
    
    // Set foreground notification presentation options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Reinitialize local notifications if permissions were granted
    if (granted && !_notificationsInitialized) {
      await _initializeLocalNotifications();
    }
    
    return granted;
  }
  
  // Get and save FCM token
  Future<void> _getAndSaveToken() async {
    if (_userId == null || _userId!.isEmpty) {
      debugPrint('Cannot get token: User ID is not set');
      return;
    }
    
    // Get token
    String? token = await _firebaseMessaging.getToken();
    
    if (token != null) {
      _token = token;
      debugPrint('FCM Token: $token');
      
      // Save token to Firestore
      await _firestore.collection('user_fcm_tokens').doc(_userId).set({
        'token': token,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('FCM token saved to Firestore');
    } else {
      debugPrint('Failed to get FCM token');
    }
  }
  
  // Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('⚡ FOREGROUND MESSAGE RECEIVED: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });
    
    // Messages when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('⚡ INITIAL MESSAGE RECEIVED: ${message.notification?.title}');
        debugPrint('Message data: ${message.data}');
        
        // For terminated app, message can come in data payload
        if (message.notification == null && message.data.containsKey('title')) {
          // Create a synthetic notification from data payload
          final notification = RemoteMessage(
            notification: RemoteNotification(
              title: message.data['title'],
              body: message.data['body'],
            ),
            data: message.data,
          );
          _handleInitialMessage(notification);
        } else {
          _handleInitialMessage(message);
        }
      }
    });
    
    // Messages when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('⚡ BACKGROUND MESSAGE OPENED: ${message.notification?.title}');
      debugPrint('Message data: ${message.data}');
      
      // Check if notification came in data payload
      if (message.notification == null && message.data.containsKey('title')) {
        // Create a synthetic notification from data payload
        final notification = RemoteMessage(
          notification: RemoteNotification(
            title: message.data['title'],
            body: message.data['body'],
          ),
          data: message.data,
        );
        _handleBackgroundMessage(notification);
      } else {
        _handleBackgroundMessage(message);
      }
    });
    
    debugPrint('Message handlers set up successfully');
  }
  
  // Handle foreground messages by showing a local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Handling foreground message: ${message.notification?.title}');
    showLocalNotification(_flutterLocalNotificationsPlugin, message);
  }
  
  // Handle initial message (app opened from terminated state)
  void _handleInitialMessage(RemoteMessage message) {
    // Parse notification data
    if (message.data.isNotEmpty) {
      _handleNotificationTap(json.encode(message.data));
    }
  }
  
  // Handle background message (app in background)
  void _handleBackgroundMessage(RemoteMessage message) {
    // Parse notification data
    if (message.data.isNotEmpty) {
      _handleNotificationTap(json.encode(message.data));
    }
  }
  
  // Handle notification tap
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    try {
      // Parse notification data
      final Map<String, dynamic> data = json.decode(payload);
      final QueueNotification notification = QueueNotification.fromJson(data);
      
      debugPrint('Notification tapped: ${notification.roomId}');
      
      // TODO: Navigate to appropriate screen based on notification type
      // This navigation should be implemented in the UI layer
      // You might want to use a navigation service or global key
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }
  
  // Send queue notification to a specific user
  Future<void> sendQueueNotification(String userId, QueueNotification notification) async {
    try {
      debugPrint('Sending queue notification to user: $userId');
      
      // Get user's FCM token
      final tokenDoc = await _firestore.collection('user_fcm_tokens').doc(userId).get();
      
      if (!tokenDoc.exists) {
        debugPrint('No FCM token found for user: $userId');
        return;
      }
      
      final token = tokenDoc.data()?['token'] as String?;
      
      if (token == null || token.isEmpty) {
        debugPrint('Invalid FCM token for user: $userId');
        return;
      }
      
      // Create notification content
      final isYourTurn = notification.notificationType == 'your_turn';
      final notificationTitle = isYourTurn ? "It's Your Turn!" : "Queue Updated";
      final notificationBody = isYourTurn 
          ? "It's now your turn in ${notification.roomName}"
          : "You moved up in ${notification.roomName}. Position: ${notification.userPosition}";
      
      // Prepare notification data
      final notificationData = {
        'title': notificationTitle,
        'body': notificationBody,
        'roomId': notification.roomId,
        'roomName': notification.roomName,
        'notificationType': notification.notificationType,
        'userId': userId,
        // Convert all numeric fields to strings based on type
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      // Add optional fields if present
      if (isYourTurn) {
        // For your_turn notification type
        notificationData['position'] = '1';  // Position is always 1 for your turn
      } else {
        // For queue_advanced notification type
        notificationData['userPosition'] = notification.userPosition.toString();
              notificationData['currentPosition'] = notification.currentPosition.toString();
            }
      
      // For terminated app notifications, simply show a direct notification
      // This is useful for local testing without Cloud Functions
      if (!kIsWeb && _userId == userId) {
        debugPrint('Sending direct notification with data: $notificationData');
        await _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notificationTitle,
          notificationBody,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          payload: json.encode(notificationData),
        );
      }
      
      // Log notification for troubleshooting
      await _firestore.collection('notifications').add({
        'userId': userId,
        'token': token,
        'title': notificationTitle,
        'body': notificationBody,
        'data': notificationData,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'sent_directly',
      });
      
      debugPrint('Queue notification sent for user: $userId');
      
    } catch (e) {
      debugPrint('Error sending queue notification: $e');
    }
  }
  
  // Update FCM token
  Future<void> updateToken() async {
    await _getAndSaveToken();
  }
  
  // Clean up when user logs out
  Future<void> cleanUp() async {
    if (_userId != null) {
      try {
        // Remove token from Firestore
        await _firestore.collection('user_fcm_tokens').doc(_userId).delete();
        _token = null;
        _userId = null;
        _notificationsInitialized = false;
      } catch (e) {
        debugPrint('Error cleaning up FCM service: $e');
      }
    }
  }
} 