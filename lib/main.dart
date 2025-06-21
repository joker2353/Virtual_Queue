import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';
import 'providers/fcm_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/homepage2.dart';
import 'pages/splash_screen.dart';
import 'firebase_options.dart';
import 'widgets/loading_indicator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'providers/cache_provider.dart';
import 'pages/main_layout.dart';

// Define notification channel for Android
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Queue Notifications',
  description: 'Notifications for queue updates',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

// Create a FlutterLocalNotificationsPlugin instance to be used across the app
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Define the background message handler outside of any class
@pragma(
  'vm:entry-point',
) // Ensures this function can be called from native code
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to ensure Firebase is initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Print the message for debugging
  debugPrint('BACKGROUND MESSAGE RECEIVED: ${message.notification?.title}');
  debugPrint('Message data: ${message.data}');

  // For terminated app, message can come in data payload
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

  // Show notification using local notifications plugin
  if (!kIsWeb) {
    // Initialize plugin for terminated state
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();

    // Create Android channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Queue Notifications',
      description: 'Notifications for queue updates',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Create notification channel for terminated app state
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Display the notification with higher priority
    await plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          fullScreenIntent: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );

    debugPrint('Background notification displayed successfully');
  }
}

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // CRITICAL: Set background message handler BEFORE Firebase initialization
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Firebase with debugging
    debugPrint('Starting Firebase initialization');
    if (kIsWeb) {
      debugPrint(
        'Initializing Firebase for Web with options: ${DefaultFirebaseOptions.web.projectId}',
      );
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      debugPrint('Firebase Web initialization complete');
    } else {
      debugPrint('Initializing Firebase for mobile');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase Mobile initialization complete');

      // Initialize notification settings for background messages
      await _initializeNotifications();

      // Request notification permissions right away
      await _requestPermissions();
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const VirtualQueueApp());
}

Future<void> _initializeNotifications() async {
  if (kIsWeb) return;

  // Android initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // iOS initialization
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

  // Initialization settings
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  // Initialize plugin
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      // Handle notification tap
      debugPrint('Notification tapped with payload: ${details.payload}');
      // Navigation to be handled by the app later
    },
  );

  // Create notification channel for Android
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    debugPrint('Android notification channel created');
  }

  debugPrint('Notifications initialized at app start');
}

Future<void> _requestPermissions() async {
  if (kIsWeb) return;

  // Request FCM permissions
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  debugPrint('FCM Permission status: ${settings.authorizationStatus}');

  // Request additional permissions for specific platforms
  if (Platform.isIOS) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
}

class VirtualQueueApp extends StatelessWidget {
  const VirtualQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FCMProvider()),
        ChangeNotifierProxyProvider<AuthProvider, RoomProvider>(
          create: (context) => RoomProvider(userId: ''),
          update: (context, auth, previous) {
            final provider = previous ?? RoomProvider(userId: '');
            provider.userId = auth.user?.uid ?? '';
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => CacheProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
        home: SplashScreen(nextScreen: const MyAppWithProviders()),
      ),
    );
  }
}

class MyAppWithProviders extends StatelessWidget {
  const MyAppWithProviders({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FCMProvider()),
        ChangeNotifierProxyProvider<AuthProvider, RoomProvider>(
          create: (context) => RoomProvider(userId: ''),
          update: (context, auth, previous) {
            final provider = previous ?? RoomProvider(userId: '');
            provider.userId = auth.user?.uid ?? '';
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => CacheProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.user != null) {
            // Connect providers only when user is authenticated
            final fcmProvider = Provider.of<FCMProvider>(
              context,
              listen: false,
            );
            final roomProvider = Provider.of<RoomProvider>(
              context,
              listen: false,
            );

            // Initialize FCM with user ID
            if (!fcmProvider.isInitialized) {
              fcmProvider.initialize(authProvider.user!.uid);
            }

            // Set FCM provider in auth provider for cleanup on logout
            authProvider.setFCMProvider(fcmProvider);

            // Set FCM provider in room provider for sending notifications
            roomProvider.setFCMProvider(fcmProvider);
          }

          return MyApp();
        },
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return auth.isLoading
        ? _buildLoadingScreen()
        : auth.user != null
        ? const MainLayout()
        : const LoginPage();
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
