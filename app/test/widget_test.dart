import 'package:codeit_crm/core/api.dart';
import 'package:dio/dio.dart';
import 'package:codeit_crm/core/fmt.dart' as f;
import 'package:codeit_crm/core/obj.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
