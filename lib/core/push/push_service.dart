import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background/terminated message handler. Must be a top-level function annotated
/// with @pragma('vm:entry-point'). FCM shows the system notification for
/// notification-type messages automatically; we keep this minimal.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No work needed for v1 — the OS renders the notification. Kept as the
  // registered entry point so background delivery is wired per FCM docs.
}

/// Handles the device's push lifecycle: permission, FCM token registration to
/// the current Supabase user (`users.fcm_token`), token refresh, and foreground
/// display via flutter_local_notifications. Server-side prefs/gating are Stage 2.
class PushService {
  PushService(this._client);

  final SupabaseClient _client;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'usora_default'; // matches manifest meta-data
  static const _channelName = 'Usora';
  bool _inited = false;

  /// One-time setup (called once after Firebase.initializeApp). Requests
  /// permission, wires foreground display + token-refresh. Safe on all platforms.
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await FirebaseMessaging.instance.requestPermission();

    // Local notifications (foreground display). Android channel + iOS options.
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ));

    // iOS: also show banners while foregrounded.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.instance.onTokenRefresh.listen(_writeToken);
  }

  /// Fetch + store this device's token for the current user. Call after login.
  Future<void> registerForCurrentUser() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _writeToken(token);
    } catch (e, st) {
      debugPrint('push token register failed: $e\n$st');
    }
  }

  /// Clear this user's token (call on logout so they stop receiving pushes).
  Future<void> clearForCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('users').update({'fcm_token': null}).eq('id', uid);
    } catch (_) {/* best-effort */}
  }

  Future<void> _writeToken(String token) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('users').update({'fcm_token': token}).eq('id', uid);
    } catch (e) {
      debugPrint('push token write failed: $e');
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return; // data-only messages: nothing to show for v1
    _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// True on the platforms we support push for.
  static bool get supported => Platform.isIOS || Platform.isAndroid;
}
