import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../providers/fcm_provider.dart';
import '../providers/chat_provider.dart';

/// A wrapper widget that ensures all required providers are available
class ProviderWrapper extends StatelessWidget {
  final Widget child;

  const ProviderWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Get all providers from parent context
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final fcmProvider = Provider.of<FCMProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Rewrap with same instances to ensure provider inheritance
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<RoomProvider>.value(value: roomProvider),
        ChangeNotifierProvider<FCMProvider>.value(value: fcmProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ],
      child: child,
    );
  }
}
