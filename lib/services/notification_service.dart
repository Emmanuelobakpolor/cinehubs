import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';
import 'storage_service.dart';

class NotificationService {
  static const String _base =
      'https://cinehubsbackend-production.up.railway.app/api/notifications';
  static const String _readKey = 'read_notification_ids';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Future<Options> _auth() async {
    final token = await StorageService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ─── Read-state helpers (local SharedPreferences) ───────────────────────

  static Future<Set<int>> _getReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_readKey) ?? [])
        .map((s) => int.tryParse(s) ?? -1)
        .toSet();
  }

  static Future<void> _saveReadIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, ids.map((e) => e.toString()).toList());
  }

  /// Mark a single notification as read (stored locally).
  static Future<void> markAsRead(int id) async {
    final ids = await _getReadIds();
    ids.add(id);
    await _saveReadIds(ids);
  }

  /// Mark a list of notification IDs as read.
  static Future<void> markAllAsRead(List<int> ids) async {
    final existing = await _getReadIds();
    existing.addAll(ids);
    await _saveReadIds(existing);
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  /// Returns all notifications for the current user, with local read state applied.
  static Future<List<AppNotification>> fetchMyNotifications() async {
    final res = await _dio.get('$_base/my/', options: await _auth());
    final data = res.data as List;
    final readIds = await _getReadIds();

    return data.map((e) {
      final n = AppNotification.fromJson(e as Map<String, dynamic>);
      n.isRead = readIds.contains(n.id);
      return n;
    }).toList();
  }

  /// Returns the number of unread notifications. Returns 0 on error.
  static Future<int> fetchUnreadCount() async {
    try {
      final notifications = await fetchMyNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (_) {
      return 0;
    }
  }
}
