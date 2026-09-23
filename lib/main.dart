import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app_colors.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Render the app immediately. Firebase/FCM setup can request permission or
  // fail because of a device configuration issue; neither should prevent the
  // user from seeing the app.
  runApp(const CinehubsApp());
  unawaited(_initializeFirebaseAndMessaging());
}

Future<void> _initializeFirebaseAndMessaging() async {
  try {
    // Give native startup a bounded amount of time, rather than leaving the
    // app at its native white launch screen indefinitely.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    }

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // When user taps a notification while app is in background (not killed),
    // mark the pending tap so HomeScreen can open the notifications screen.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      FCMService.markNotificationTapped();
    });

    // When user taps a notification that launched the app from killed state.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      FCMService.markNotificationTapped();
    }

    // Initialise FCM (request permission + upload token). If the user isn't
    // logged in yet, registerAfterLogin() handles the token upload.
    await FCMService.initialize();
  } catch (error, stackTrace) {
    // Notifications are optional. Keep the app usable if Firebase setup fails.
    debugPrint('Firebase/FCM initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class CinehubsApp extends StatelessWidget {
  const CinehubsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        return MaterialApp(
          title: 'Cinehubs',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            scaffoldBackgroundColor: AppColors.background,
            cardColor: Colors.grey.shade50,
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.background,
              elevation: 0,
              iconTheme: IconThemeData(color: AppColors.textDark),
              titleTextStyle: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF2A2A2A),
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
