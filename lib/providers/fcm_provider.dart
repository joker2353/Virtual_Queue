import 'package:flutter/foundation.dart';
import '../services/fcm_service.dart';
import '../models/queue_notification.dart';
import 'dart:async';

class FCMProvider with ChangeNotifier {
  final FCMService _fcmService = FCMService.instance;
  bool _isInitialized = false;
  String? _userId;
  
  // Getters
  bool get isInitialized => _isInitialized;
  String? get userId => _userId;
  
  // Initialize provider with user ID
  Future<void> initialize(String userId) async {
    if (_isInitialized && _userId == userId) return;
    
    _userId = userId;
    await _fcmService.initialize(userId);
    _isInitialized = true;
    
    // Explicitly request notification permissions
    if (!kIsWeb) {
      debugPrint('FCMProvider: Explicitly requesting notification permissions');
      await requestPermissions();
    }
    
    notifyListeners();
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
  
  // Clean up when user logs out
  Future<void> cleanUp() async {
    if (_isInitialized) {
      await _fcmService.cleanUp();
      _isInitialized = false;
      _userId = null;
      notifyListeners();
    }
  }
} 