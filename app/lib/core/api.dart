import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'obj.dart';

const kApiBase = String.fromEnvironment('API', defaultValue: 'https://crm.coditvision.com/api/mobile/v1');
const kDemo = bool.fromEnvironment('DEMO');
const kAppBuild = int.fromEnvironment('BUILD', defaultValue: 1);

class ApiError implements Exception {
  ApiError(this.message, {this.code = '', this.status = 0, this.details = const {}});
  final String message, code;
  final int status;
  final Map<String, dynamic> details;
  bool get unauthorized => status == 401;
  @override
  String toString() => message;
}

/// Talks to /api/mobile/v1 with the login token. In DEMO builds it answers from bundled
/// sample responses recorded from a real CRM, so the app can be shown without a server.
class Api {
  Api._();
  static final Api I = Api._();

  final _store = const FlutterSecureStorage();
  String? _token;
  void Function()? onUnauthorized;

  late final Dio dio = Dio(BaseOptions(
    baseUrl: kApiBase.endsWith('/') ? kApiBase : '$kApiBase/', // dio just glues baseUrl + path
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json', 'X-Locale': 'ar', 'X-App-Build': '$kAppBuild'},
  ))
    ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (_token != null) o.headers['Authorization'] = 'Bearer $_token';
      if (kDemo) return h.resolve(_demo(o));
      h.next(o);
    }));

  Map<String, String> get authHeaders => {if (_token != null) 'Authorization': 'Bearer $_token'};
  bool get hasToken => _token != null;

  Future<void> load() async {
    if (kDemo) {
      _token = 'demo';
      return;
    }
    try {
      _token = await _store.read(key: 'token');
    } catch (_) {
      _token = null;
    }
  }

  Future<void> saveToken(String? t) async {
    _token = t;
    if (kDemo) return;
    if (t == null) {
      await _store.delete(key: 'token');
    } else {
      await _store.write(key: 'token', value: t);
    }
  }

  Future<Obj> get(String path, [Map<String, dynamic>? q]) => _wrap(() => dio.get(path, queryParameters: _clean(q)));
  Future<Obj> post(String path, [Object? body]) => _wrap(() => dio.post(path, data: body));
  Future<Obj> put(String path, [Object? body]) => _wrap(() => dio.put(path, data: body));
  Future<Obj> delete(String path) => _wrap(() => dio.delete(path));

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) => q == null ? null : (Map.of(q)..removeWhere((k, v) => v == null || v == ''));

  Future<Obj> _wrap(Future<Response> Function() f) async {
    try {
      final r = await f();
      final data = r.data is String && (r.data as String).isNotEmpty ? jsonDecode(r.data) : r.data;
      return Obj.of(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      String msg = 'حصلت مشكلة. جرّب تاني.';
      String code = '';
      Map<String, dynamic> details = {};
      if (body is Map && body['error'] is Map) {
        msg = '${body['error']['message'] ?? msg}';
        code = '${body['error']['code'] ?? ''}';
        if (body['error']['details'] is Map) details = Map<String, dynamic>.from(body['error']['details']);
      } else if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        msg = 'مفيش اتصال بالسيرفر. اتأكد من النت.';
        code = 'offline';
      } else if (status == 429) {
        msg = 'طلبات كتير ورا بعض. استنى دقيقة.';
      } else {
        // say what happened, so a screenshot is enough to find the cause
        msg = 'حصلت مشكلة (${status > 0 ? status : e.type.name}). جرّب تاني.';
        debugPrint('api ${e.requestOptions.method} ${e.requestOptions.path}: $status ${e.type} ${e.error}');
      }
      if (status == 401 && !kDemo) {
        await saveToken(null);
        onUnauthorized?.call();
      }
      throw ApiError(msg, code: code, status: status, details: details);
    }
  }

  /* ---------- demo answers ---------- */
  static Map<String, dynamic>? _fixtures;

  static Future<void> loadDemo() async {
    if (!kDemo) return;
    final raw = await rootBundle.loadString('assets/demo/api.json');
    _fixtures = Map<String, dynamic>.from(jsonDecode(raw));
  }

  Response _demo(RequestOptions o) {
    final path = o.path.startsWith('/') ? o.path.substring(1) : o.path;
    final key = '${o.method} $path';
    dynamic data = _fixtures?[key];
    if (data == null && o.method == 'GET') {
      // list endpoints: ignore query; detail: fall back to the first recorded id of that kind
      final base = path.replaceAll(RegExp(r'/\d+(?=/|$)'), '/{id}');
      data = _fixtures?.entries.firstWhere((e) => e.key.replaceAll(RegExp(r'/\d+(?=/|$)'), '/{id}') == 'GET $base', orElse: () => const MapEntry('', null)).value;
    }
    data ??= o.method == 'GET' ? {'data': []} : {'ok': true, 'message': 'تم (نسخة العرض).'};
    if (kDebugMode) debugPrint('[demo] $key');
    return Response(requestOptions: o, statusCode: 200, data: data);
  }
}
