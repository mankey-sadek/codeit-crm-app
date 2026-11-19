import 'dart:convert';
import 'dart:io';

import 'package:codeit_crm/core/api.dart';
import 'package:codeit_crm/core/obj.dart';
import 'package:codeit_crm/core/session.dart';
import 'package:codeit_crm/core/theme.dart';
import 'package:codeit_crm/router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens every screen of the app, in the dark and the light theme, with API answers recorded from a
/// test CRM (test/fixtures/api.json). A screen fails if it throws, overflows, shows its error state,
/// or asks the API for something that 404s.
Map<String, dynamic> _load(String f) => (jsonDecode(File(f).readAsStringSync()) as Map).cast<String, dynamic>();
final admin = _load('test/fixtures/api.json'), employee = _load('test/fixtures/api_employee.json');
var fixtures = admin;

/// What an ordinary employee (no sales, no settings) opens.
const employeeRoutes = ['/home', '/tasks', '/chat', '/me', '/more', '/search', '/notifications', '/settings', '/tasks/new', '/hr/leaves', '/hr/leaves/new', '/chat/new'];

const routes = [
  '/home', '/tasks', '/chat', '/me', '/more', '/search', '/notifications', '/settings',
  '/tasks/new', '/tasks/4', '/tasks/4/edit', '/projects', '/projects/new', '/projects/3', '/projects/3/edit',
  '/tickets', '/tickets/new', '/tickets/5', '/support-packages',
  '/crm-settings', '/crm-settings/users', '/crm-settings/roles', '/crm-settings/groups', '/crm-settings/pipelines',
  '/crm-settings/sources', '/crm-settings/types', '/crm-settings/tags', '/crm-settings/hr_departments',
  '/crm-settings/hr_settings', '/crm-settings/email_templates',
  '/invoices', '/invoices/new', '/invoices/4', '/invoices/4/edit',
  '/leads', '/leads/new', '/leads/8', '/persons', '/persons/new', '/persons/4',
  '/organizations', '/organizations/new', '/organizations/4', '/activities', '/activities/new',
  '/quotes', '/quotes/2', '/products', '/mail', '/mail/compose', '/mail/inbox/1',
  '/chat/new', '/chat/monitor', '/chat/monitor/1', '/chat/1',
  '/hr/leaves', '/hr/leaves/new', '/hr/employees', '/hr/employees/3', '/hr/attendance', '/hr/payroll', '/hr/payslips/5',
  '/careers', '/careers/2',
];

final missing = <String>{};
Map<String, dynamic>? Function(String path)? override;

void installFakeApi() {
  Api.I.dio.interceptors
    ..clear()
    ..add(InterceptorsWrapper(onRequest: (o, h) {
      final path = o.path.split('?').first;
      final body = override?.call(path) ?? fixtures[path] ?? (o.method == 'GET' ? null : {'ok': true});
      if (body == null) {
        missing.add('${o.method} $path');
        return h.reject(DioException(requestOptions: o, response: Response(requestOptions: o, statusCode: 404, data: {'error': {'message': 'not found'}}), type: DioExceptionType.badResponse));
      }
      h.resolve(Response(requestOptions: o, statusCode: 200, data: jsonDecode(jsonEncode(body))));
    }));
}

Future<void> openScreen(WidgetTester tester, String route, Ci tokens, {double textScale = 1}) async {
  router.go(route);
  await tester.pumpWidget(MaterialApp.router(
    theme: buildTheme(tokens),
    locale: const Locale('ar'),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(textDirection: TextDirection.rtl, child: child!),
    ),
    routerConfig: router,
  ));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // the real fonts, so text takes the space it takes on a phone
    final fonts = {
      'Readex': ['Regular', 'Medium', 'SemiBold', 'Bold'].map((w) => 'assets/fonts/ReadexPro-$w.ttf'),
      'FiraCode': ['Regular', 'Medium'].map((w) => 'assets/fonts/FiraCode-$w.ttf'),
      'Poppins': ['Medium', 'SemiBold', 'Bold'].map((w) => 'assets/fonts/Poppins-$w.ttf'),
    };
    for (final f in fonts.entries) {
      final l = FontLoader(f.key);
      for (final a in f.value) {
        l.addFont(Future.value(ByteData.sublistView(File(a).readAsBytesSync())));
      }
      await l.load();
    }
    SharedPreferences.setMockInitialValues({});
    installFakeApi();
    Session.I.me = Obj.of(fixtures['me']['user']);
    Session.I.booting = false;
  });

  // dark, light, and dark with the biggest text the app allows (phone set to large text)
  for (final (dark, scale) in [(true, 1.0), (false, 1.0), (true, 1.3)]) {
    for (final r in routes) {
      testWidgets('${dark ? 'dark' : 'light'}${scale > 1 ? ' large text' : ''} $r', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        missing.clear();
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final where = RegExp(r'lib/[a-z_/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '';
          errors.add('${d.exceptionAsString().split('\n').first} $where');
        };
        await openScreen(tester, r, dark ? Ci.darkTokens : Ci.lightTokens, textScale: scale);
        FlutterError.onError = old;
        expect(errors.toSet().toList(), isEmpty, reason: 'the screen threw or overflowed');
        expect(find.textContaining('error:'), findsNothing, reason: 'the screen shows its error state');
        expect(missing, isEmpty, reason: 'asked the API for something the test CRM does not have');
        await tester.pumpWidget(const SizedBox()); // stop timers (chat polling)
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }

  group('as an employee', () {
    setUp(() {
      fixtures = employee;
      Session.I.me = Obj.of(employee['me']['user']);
    });
    tearDown(() {
      fixtures = admin;
      Session.I.me = Obj.of(admin['me']['user']);
    });
    for (final r in employeeRoutes) {
      testWidgets('employee $r', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        missing.clear();
        await openScreen(tester, r, Ci.lightTokens);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('error:'), findsNothing, reason: 'the screen shows its error state');
        expect(missing, isEmpty, reason: 'asked the API for something the test CRM does not have');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      });
    }
  });

  testWidgets('my file without an employee file offers to make one', (tester) async {
    override = (p) => p == 'hr/me' ? {'no_file': true} : null;
    addTearDown(() => override = null);
    await openScreen(tester, '/me', Ci.darkTokens);
    expect(find.text('اعمل ملفي'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
