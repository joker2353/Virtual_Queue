import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';
import 'providers/notification_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'firebase_options.dart';
import 'widgets/loading_indicator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  if (kIsWeb) {
    // Initialize with minimal config for testing
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider2<AuthProvider, NotificationProvider, RoomProvider>(
          create: (context) => RoomProvider(userId: ''),
          update: (context, auth, notificationProvider, previous) {
            final provider = previous ?? RoomProvider(userId: '');
            provider.userId = auth.user?.uid ?? '';
            return RoomProvider(
              userId: auth.user?.uid ?? '',
              notificationProvider: notificationProvider,
            );
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    // Initialize notification provider with Twilio credentials
    // Skip Twilio initialization on web since it might not be supported
    if (!kIsWeb) {
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Replace with your actual Twilio credentials
        notificationProvider.initialize(
          accountSid: 'YOUR_TWILIO_ACCOUNT_SID',
          authToken: 'YOUR_TWILIO_AUTH_TOKEN',
          twilioNumber: 'whatsapp:+14155238886', // Twilio Sandbox WhatsApp number
        );
      });
    }
    
    return MaterialApp(
      title: 'Virtual Queue',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        cardTheme: CardTheme(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: auth.isLoading
          ? _buildLoadingScreen()
          : auth.user != null
              ? HomePage()
              : LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: LoadingIndicator(
          size: 60,
          message: 'Loading app...',
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }
}
