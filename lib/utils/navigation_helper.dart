import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../providers/fcm_provider.dart';

/// Helper class for navigating between screens with proper provider inheritance
class NavigationHelper {
  /// Navigate to a screen with all providers preserved
  static void navigateTo(BuildContext context, Widget screen) {
    // First capture all providers outside of the navigation
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final fcmProvider = Provider.of<FCMProvider>(context, listen: false);

    // Then perform the navigation with the captured providers
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
                ChangeNotifierProvider<RoomProvider>.value(value: roomProvider),
                ChangeNotifierProvider<FCMProvider>.value(value: fcmProvider),
              ],
              child: screen,
            ),
      ),
    );
  }
}
