import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'constants/colors.dart';
import 'providers/app_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/main_shell.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/orders_screen.dart';
import 'constants/app_env.dart';

// Global navigator key for notification tap deep-linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Supabase credentials loaded securely from environment / AppEnv
const String supabaseUrl = AppEnv.supabaseUrl;
const String supabaseAnonKey = AppEnv.supabaseAnonKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom global error boundary builder to capture rendering crashes and prevent failures
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF9FBF9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFD32F2F),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait a moment and try again, or restart the application.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Optimize Flutter memory image cache to hold up to 1000 decoded images / 250 MB
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024;

  // Initialize Firebase and Cloud Messaging
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService.instance.initialize(
      onNotificationTap: (data) {
        final screen = data['screen'];
        if (screen == 'orders') {
          navigatorKey.currentState?.pushNamed('/orders');
        }
      },
    );
    print("Firebase & FCM successfully initialized.");
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  if (supabaseUrl != 'YOUR_SUPABASE_URL' && supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY') {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print("Supabase successfully initialized.");
    } catch (e) {
      print("Supabase initialization failed: $e. Running in offline/demo mode.");
    }
  } else {
    print("Supabase credentials not configured yet. Running in offline/demo mode.");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const SabzeeWalaApp(),
    ),
  );
}

class SabzeeWalaApp extends StatelessWidget {
  const SabzeeWalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SabzeeWala',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter', // Defaulting to clean modern font styling
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textDark),
          titleTextStyle: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: mediaQueryData.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.05,
            ),
          ),
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OtpScreen(),
        '/home': (context) => const MainShell(),
        '/complete_profile': (context) => const CompleteProfileScreen(),
        '/orders': (context) => const OrdersScreen(),
      },
    );
  }
}
