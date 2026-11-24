import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalCupertinoLocalizations, GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import 'core/push.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/home.dart';
import 'router.dart';
import 'ui/desktop.dart';
import 'ui/kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Push.onOpen = (link) {
    if (!Session.I.signedIn) return;
    router.push(link.startsWith('/') ? link : (crmLinkRoute(link) ?? '/notifications'));
  };
  Push.onForeground = (m) {
    final d = m.data;
    if (d['kind'] == 'chat') {
      Session.I.setBadges(chat: Session.I.unreadChat + 1);
    } else {
      Session.I.setBadges(notices: Session.I.unreadNotices + 1);
    }
    final c = rootKey.currentContext;
    final n = m.notification;
    if (c != null && n != null) toast(c, [n.title, n.body].whereType<String>().where((x) => x.isNotEmpty).join(' · '));
  };
  await Session.I.boot();
  runApp(const CodeItApp());
}

class CodeItApp extends StatelessWidget {
  const CodeItApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Session.I,
        builder: (context, _) {
          final dark = Session.I.themeMode == ThemeMode.dark ||
              (Session.I.themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: dark ? Ci.darkTokens.surface : Ci.lightTokens.surface,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ));
          return MaterialApp.router(
            title: 'code it CRM',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Ci.lightTokens),
            darkTheme: buildTheme(Ci.darkTokens),
            themeMode: Session.I.themeMode,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.3)),
              child: DesktopFrame(child: child!),
            ),
          );
        },
      );
}
