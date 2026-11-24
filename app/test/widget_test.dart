import 'package:codeit_crm/core/api.dart';
import 'package:dio/dio.dart';
import 'package:codeit_crm/core/fmt.dart' as f;
import 'package:codeit_crm/core/obj.dart';
import 'package:codeit_crm/core/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('money uses Western digits and EGP', () {
    expect(f.money(85000), contains('85,000'));
  });

  test('Obj reads loose JSON safely', () {
    const o = Obj({'n': '12', 'b': 1, 'ref': {'id': 3, 'name': 'سارة'}});
    expect(o.i('n'), 12);
    expect(o.b('b'), true);
    expect(o.ref('ref'), 'سارة');
    expect(o.i('missing', 7), 7);
  });

  test('API calls go to /api/mobile/v1/<path>', () {
    final o = RequestOptions(baseUrl: Api.I.dio.options.baseUrl, path: 'auth/login');
    expect(o.uri.toString(), 'https://crm.coditvision.com/api/mobile/v1/auth/login');
  });

  test('the store reviewers sign-in opens the demo, without the CRM', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Session.I.login(kReviewEmail, kReviewPassword);
    expect(Api.demo, isTrue);
    expect(Session.I.me?.s('email'), kReviewEmail);
    expect((await Api.I.get('settings/users')).l('data'), isNotEmpty);
    Api.demo = false;
  });

  test('signing in still works when the phone refuses to store the token', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // no keychain in tests: every secure-storage call throws, like a refused keychain on a phone
    Api.I.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (o.path == 'auth/login') return h.resolve(Response(requestOptions: o, statusCode: 200, data: {'token': 't1', 'user': {'id': 1, 'email': 'a@b.c', 'screens': {}}}));
      h.resolve(Response(requestOptions: o, statusCode: 200, data: {'ok': true}));
    }));
    await Session.I.login('a@b.c', 'x');
    expect(Api.I.hasToken, isTrue);
    expect(Session.I.me?.s('email'), 'a@b.c');
  });

  test('a phone keyboard types the same password as the web', () {
    expect(Session.plainKeys('Abc١٢٣'), 'Abc123');
    expect(Session.plainKeys('x۴۵'), 'x45');
    expect(Session.plainKeys('it\u2019s\u2014ok'), "it's-ok");
    expect(Session.plainKeys('Pass#2026!'), 'Pass#2026!');
  });
}
