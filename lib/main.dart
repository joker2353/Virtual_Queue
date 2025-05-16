import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'firebase_options.dart';
import 'widgets/loading_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, RoomProvider>(
          create: (context) => RoomProvider(userId: ''),
          update: (context, auth, previous) {
            final provider = previous ?? RoomProvider(userId: '');
            provider.userId = auth.user?.uid ?? '';
            return provider;
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
    return const Scaffold(
      body: Center(
        child: LoadingIndicator(
          size: 60,
          message: 'Loading app...',
          useBlurBackground: true,
        ),
      ),
    );
  }
}
