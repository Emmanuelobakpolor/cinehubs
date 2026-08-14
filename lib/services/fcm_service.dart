import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'storage_service.dart';

// Must be a top-level function — Flutter calls this in a separate isolate
// when a data-only message arrives while the app is in background/killed.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Background messages run in a separate Dart isolate. Initialization from
  // main() is not shared with it, so Firebase must be initialized here too.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // FCM automatically shows the notification UI when the app is in background.
  // Nothing extra needed here for display-type messages.
}

class FCMService {
  static const String _base =
      'https://web-production-3fa8c.up.railway.app/api/notifications';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Set to true after the first token upload so we don't spam the endpoint.
  static bool _tokenRegistered = false;

  /// Call this after Firebase.initializeApp() in main().
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission — required on iOS and Android 13+.
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (granted) {
      await _registerToken();
    }

    // Re-register whenever FCM rotates the token.
    messaging.onTokenRefresh.listen((_) => _registerToken());
  }

  /// Upload (or refresh) this device's FCM token to the backend.
  /// Safe to call multiple times — backend uses update_or_create.
  static Future<void> _registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      String? token;

      if (Platform.isIOS) {
        // On iOS the APNS token must be ready before getToken() works.
        token = await messaging.getAPNSToken();
        if (token == null) {
          await Future.delayed(const Duration(seconds: 3));
          token = await messaging.getToken();
        }
      } else {
        token = await messaging.getToken();
      }

      if (token == null) {
        debugPrint('[FCM] getToken() returned null — Firebase may not be initialised');
        return;
      }

      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) {
        debugPrint('[FCM] No auth token — will retry after login');
        return;
      }

      debugPrint('[FCM] Uploading token: ${token.substring(0, 20)}…');
      final response = await _dio.post(
        '$_base/device-token/',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      debugPrint('[FCM] Token registered — HTTP ${response.statusCode}');
      _tokenRegistered = true;
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  /// Call this after the user logs in so the token gets uploaded
  /// even if [initialize] ran before the user authenticated.
  static Future<void> registerAfterLogin() async {
    if (!_tokenRegistered) await _registerToken();
  }

  // ─── Pending notification tap ───────────────────────────────────────────
  // When the user taps a notification while the app is killed or backgrounded,
  // store the intent here. HomeScreen reads it in initState.

  static bool _pendingTap = false;

  static void markNotificationTapped() => _pendingTap = true;

  /// Returns true once — resets after reading.
  static bool consumePendingTap() {
    if (_pendingTap) {
      _pendingTap = false;
      return true;
    }
    return false;
  }
}
