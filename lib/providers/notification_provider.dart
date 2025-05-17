import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService.instance;
  bool _isInitialized = false;
  
  // Getters
  bool get isInitialized => _isInitialized;
  
  // Initialize Twilio service
  Future<void> initialize({
    required String accountSid,
    required String authToken,
    required String twilioNumber,
  }) async {
    await _notificationService.initialize(
      accountSid: accountSid,
      authToken: authToken,
      twilioNumber: twilioNumber,
    );
    
    _isInitialized = _notificationService.isInitialized;
    notifyListeners();
  }
  
  // Send WhatsApp notification for queue position
  Future<bool> sendQueuePositionNotification({
    required String phoneNumber,
    required String queueName,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationProvider: Service not initialized');
      return false;
    }
    
    return _notificationService.sendQueuePositionNotification(
      phoneNumber: phoneNumber,
      queueName: queueName,
    );
  }
} 