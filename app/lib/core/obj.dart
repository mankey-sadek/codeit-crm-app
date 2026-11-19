/// A JSON object from the code it mobile API, read with forgiving typed getters.
/// Screens read the API keys directly, so a new server field never breaks an old app.
class Obj {
  const Obj(this.j);
  final Map<String, dynamic> j;

  static Obj of(dynamic v) => Obj(v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});
  static List<Obj> list(dynamic v) => v is List ? v.whereType<Map>().map((e) => Obj(Map<String, dynamic>.from(e))).toList() : const [];

  dynamic operator [](String k) => j[k];
  bool has(String k) => j[k] != null && j[k] != '';

  String s(String k, [String or = '']) {
    final v = j[k];
    if (v == null) return or;
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  String? sn(String k) {
    final v = j[k];
    if (v == null || v.toString().isEmpty) return null;
    return v.toString();
  }

  int i(String k, [int or = 0]) {
    final v = j[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? or;
  }

  double d(String k, [double or = 0]) {
    final v = j[k];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? or;
  }

  bool b(String k) {
    final v = j[k];
    return v == true || v == 1 || v == '1' || v == 'true';
  }

  DateTime? t(String k) {
    final v = j[k];
    if (v == null || v == '') return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  Obj o(String k) => Obj.of(j[k]);
  Obj? on(String k) => j[k] is Map ? Obj.of(j[k]) : null;
  List<Obj> l(String k) => Obj.list(j[k]);
  List<String> ls(String k) => j[k] is List ? (j[k] as List).map((e) => e.toString()).toList() : const [];

  /// name of a {id, name} reference
  String ref(String k, [String or = '']) => on(k)?.s('name', or) ?? or;
  int refId(String k) => on(k)?.i('id') ?? 0;
}
