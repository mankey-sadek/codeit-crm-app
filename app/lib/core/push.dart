import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

/// Push notifications (Firebase Cloud Messaging). The Firebase ids come from the build
/// (--dart-define FB_*), so a build without them simply has no push and works as before.
class Push {
  Push._();

  static const _project = String.fromEnvironment('FB_PROJECT');
  static const _sender = String.fromEnvironment('FB_SENDER');
  static const _androidKey = String.fromEnvironment('FB_ANDROID_KEY');
  static const _androidApp = String.fromEnvironment('FB_ANDROID_APP');
  static const _iosKey = String.fromEnvironment('FB_IOS_KEY');
  static const _iosApp = String.fromEnvironment('FB_IOS_APP');

  static bool _ready = false;
  static StreamSubscription<String>? _refresh;

  /// Called with the screen to open when a notification is tapped, and for messages that
  /// arrive while the app is open (to refresh the badges and show a small banner).
  static void Function(String route)? onOpen;
  static void Function(RemoteMessage m)? onForeground;

  static FirebaseOptions? get _options {
    if (kIsWeb || _project.isEmpty || _sender.isEmpty) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android when _androidKey.isNotEmpty && _androidApp.isNotEmpty =>
        const FirebaseOptions(apiKey: _androidKey, appId: _androidApp, messagingSenderId: _sender, projectId: _project),
      TargetPlatform.iOS when _iosKey.isNotEmpty && _iosApp.isNotEmpty => const FirebaseOptions(
          apiKey: _iosKey, appId: _iosApp, messagingSenderId: _sender, projectId: _project, iosBundleId: 'com.coditvision.crm'),
      _ => null,
    };
  }

  static Future<void> init() async {
    final o = _options;
    if (o == null || _ready) return;
    try {
      await Firebase.initializeApp(options: o);
      _ready = true;
      FirebaseMessaging.onMessage.listen((m) => onForeground?.call(m));
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) Future.delayed(const Duration(milliseconds: 600), () => _open(first));
    } catch (e) {
      debugPrint('push off: $e');
    }
  }

  /// After sign-in (and on every start while signed in): ask once, then send the token to the CRM.
  static Future<void> register() async {
    if (!_ready || Api.demo) return;
    try {
      final fm = FirebaseMessaging.instance;
      final s = await fm.requestPermission();
      if (s.authorizationStatus == AuthorizationStatus.denied) return;
      await fm.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // the APNs token can take a moment after the first permission prompt
        for (var i = 0; i < 10 && await fm.getAPNSToken() == null; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      final t = await fm.getToken();
      if (t != null) await _send(t);
      _refresh ??= fm.onTokenRefresh.listen(_send);
    } catch (e) {
      debugPrint('push register: $e');
    }
  }

  /// On logout: this phone stops getting pushes for that person.
  static Future<void> unregister() async {
    if (!_ready) return;
    try {
      await _refresh?.cancel();
      _refresh = null;
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static Future<void> _send(String token) => Api.I.post('devices', {
        'push_token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'app_version': const String.fromEnvironment('BUILD', defaultValue: '1'),
      });

  static void _open(RemoteMessage m) {
    final d = m.data;
    final route = d['kind'] == 'chat' && (d['conversation_id'] ?? '').isNotEmpty
        ? '/chat/${d['conversation_id']}?t=${Uri.encodeComponent(m.notification?.title ?? '')}'
        : (d['route'] ?? '');
    onOpen?.call(route);
  }
}
