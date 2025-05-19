import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static NotificationService? _instance;
  late TwilioFlutter? _twilioFlutter;
  bool _isInitialized = false;
  
  // Singleton pattern
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }
  
  NotificationService._();
  
  // Initialize with Twilio credentials
  Future<void> initialize({
    required String accountSid,
    required String authToken,
    required String twilioNumber,
  }) async {
    if (_isInitialized) return;
    
    // Skip Twilio initialization on web
    if (kIsWeb) {
      debugPrint('Running on web, skipping Twilio initialization');
      _isInitialized = true;
      return;
    }
    
    _twilioFlutter = TwilioFlutter(
      accountSid: accountSid,
      authToken: authToken,
      twilioNumber: twilioNumber,
    );
    
    _isInitialized = true;
  }
  
  // Check if the service is initialized
  bool get isInitialized => _isInitialized;
  
  // Send WhatsApp message
  Future<bool> sendWhatsAppMessage({
    required String toNumber,
    required String messageBody,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return false;
    }
    
    // For web, just log that we would have sent a message
    if (kIsWeb) {
      debugPrint('Web platform: Would send WhatsApp message to $toNumber: $messageBody');
      return true;
    }
    
    try {
      if (toNumber.isEmpty) {
        debugPrint('No phone number provided for notification');
        return false;
      }
      
      // Format number for WhatsApp (must be in format: whatsapp:+1234567890)
      final formattedNumber = toNumber.startsWith('whatsapp:') 
          ? toNumber 
          : 'whatsapp:$toNumber';
      
      final response = await _twilioFlutter!.sendWhatsApp(
        toNumber: formattedNumber,
        messageBody: messageBody,
      );
      
      // Log the response for debugging
      debugPrint('WhatsApp message sent, response: $response');
      
      return true;
    } catch (e) {
      debugPrint('Error sending WhatsApp message: $e');
      return false;
    }
  }
  
  // Send queue position notification
  Future<bool> sendQueuePositionNotification({
    required String phoneNumber,
    required String queueName,
  }) async {
    final message = 'Hello! Your turn has arrived in the queue "$queueName". Please proceed to the service point.';
    return sendWhatsAppMessage(
      toNumber: phoneNumber,
      messageBody: message,
    );
  }
} 