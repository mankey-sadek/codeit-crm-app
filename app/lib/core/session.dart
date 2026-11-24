import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'obj.dart';
import 'push.dart';

/// Who is signed in, what they may open, and app preferences (theme).
class Session extends ChangeNotifier {
  Session._();
  static final Session I = Session._();

  Obj? me;
  bool booting = true;
  ThemeMode themeMode = ThemeMode.dark;
  int unreadNotices = 0;
  int unreadChat = 0;

  bool get signedIn => me != null;
  List<String> get screens => me?.ls('screens') ?? const [];
  bool can(String screen) => screens.contains(screen);
  bool get isAdmin => me?.b('is_admin') ?? false;
  String get firstName => (me?.s('name') ?? '').split(' ').first;

  Future<void> boot() async {
    final p = await SharedPreferences.getInstance();
    themeMode = switch (p.getString('theme')) { 'light' => ThemeMode.light, 'system' => ThemeMode.system, _ => ThemeMode.dark };
    if (p.getBool('demo') ?? false) Api.demo = true;
    await Api.loadDemo();
    await Api.I.load();
    Api.I.onUnauthorized = () {
      me = null;
      notifyListeners();
    };
    if (Api.I.hasToken) {
      try {
        me = (await Api.I.get('me')).o('user');
      } on ApiError catch (e) {
        if (e.unauthorized) me = null;
        // offline: keep the last profile so the app still opens
        if (e.code == 'offline' && _cached(p) != null) me = Obj.of(_cached(p));
      }
      if (me != null) _cache(p, me!);
    }
    await Push.init();
    if (me != null) Push.register();
    booting = false;
    notifyListeners();
  }

  /// What a phone keyboard may type that the web never does: Arabic-Indic digits (٠-٩, ۰-۹) and
  /// iOS "smart" quotes and dashes. Turned back into the plain characters the CRM stored.
  static String plainKeys(String v) {
    final b = StringBuffer();
    for (final r in v.runes) {
      if (r >= 0x660 && r <= 0x669) {
        b.writeCharCode(0x30 + r - 0x660);
      } else if (r >= 0x6F0 && r <= 0x6F9) {
        b.writeCharCode(0x30 + r - 0x6F0);
      } else {
        b.write(switch (r) { 0x2018 || 0x2019 => "'", 0x201C || 0x201D => '"', 0x2013 || 0x2014 => '-', _ => String.fromCharCode(r) });
      }
    }
    return b.toString();
  }

  Future<void> login(String email, String password) async {
    email = plainKeys(email).trim().toLowerCase();
    password = plainKeys(password);
    final p = await SharedPreferences.getInstance();
    if (email.trim().toLowerCase() == kReviewEmail && password == kReviewPassword) {
      // App Store / Google Play reviewers: the demo with made-up data, no CRM data is shown
      Api.demo = true;
      await p.setBool('demo', true);
      await Api.loadDemo();
    }
    final r = await Api.I.post('auth/login', {'email': email.trim(), 'password': password, 'device': defaultTargetPlatform.name});
    await Api.I.saveToken(r.s('token'));
    me = r.o('user');
    _cache(await SharedPreferences.getInstance(), me!);
    notifyListeners();
    Push.register();
  }

  Future<void> logout() async {
    await Push.unregister();
    try {
      await Api.I.post('auth/logout');
    } catch (_) {}
    await Api.I.saveToken(null);
    if (Api.demo && !kDemo) {
      Api.demo = false;
      (await SharedPreferences.getInstance()).remove('demo');
    }
    me = null;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', m.name);
  }

  void setBadges({int? notices, int? chat}) {
    unreadNotices = notices ?? unreadNotices;
    unreadChat = chat ?? unreadChat;
    notifyListeners();
  }

  static Map<String, dynamic>? _cached(SharedPreferences p) {
    final s = p.getString('me');
    if (s == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  static void _cache(SharedPreferences p, Obj me) => p.setString('me', jsonEncode(me.j));
}
