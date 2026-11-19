// Arabic labels with Western digits (123), as everywhere in code it.

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _days = ['الاتنين', 'التلات', 'الأربع', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String two(int n) => n.toString().padLeft(2, '0');

String money(num v, {bool short = false, String cur = 'ج.م'}) {
  if (short && v.abs() >= 1000000) return '${_trim(v / 1000000)}M $cur';
  if (short && v.abs() >= 10000) return '${_trim(v / 1000)}K $cur';
  return '${group(v)} $cur';
}

String group(num v) {
  final neg = v < 0;
  final whole = v.abs().truncate();
  final frac = ((v.abs() - whole) * 100).round();
  final s = whole.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${neg ? '-' : ''}$s${frac > 0 ? '.${two(frac)}' : ''}';
}

String _trim(double v) => v.toStringAsFixed(v.abs() >= 100 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '');

String month(int m) => _months[(m - 1).clamp(0, 11)];
String weekday(DateTime d) => _days[d.weekday - 1];

String dateShort(DateTime? d) => d == null ? '—' : '${d.day} ${month(d.month)}${d.year != DateTime.now().year ? ' ${d.year}' : ''}';
String dateLong(DateTime? d) => d == null ? '—' : '${weekday(d)} ${d.day} ${month(d.month)} ${d.year}';
String time(DateTime? d) => d == null ? '—' : '${two(d.hour)}:${two(d.minute)}';
String dateTime(DateTime? d) => d == null ? '—' : '${dateShort(d)} · ${time(d)}';
String monthLabel(String ym) {
  final p = ym.split('-');
  if (p.length != 2) return ym;
  return '${month(int.tryParse(p[1]) ?? 1)} ${p[0]}';
}

String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// "من 5 دقايق" / "امبارح" / "12 نوفمبر"
String ago(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'دلوقتي';
  if (diff.inMinutes < 60) return 'من ${diff.inMinutes} د';
  if (diff.inHours < 24 && d.day == DateTime.now().day) return 'من ${diff.inHours} س';
  final y = DateTime.now().subtract(const Duration(days: 1));
  if (d.year == y.year && d.month == y.month && d.day == y.day) return 'امبارح';
  return dateShort(d);
}

/// SLA / deadline: "فاضل 3 س" or "متأخر 2 يوم"
String left(int minutes) {
  final late = minutes < 0;
  final m = minutes.abs();
  final s = m >= 1440 ? '${(m / 1440).floor()} يوم' : m >= 60 ? '${(m / 60).floor()} س ${m % 60 > 0 ? '${m % 60} د' : ''}'.trim() : '$m د';
  return late ? 'متأخر $s' : 'فاضل $s';
}

String until(DateTime? due) => due == null ? '' : left(due.difference(DateTime.now()).inMinutes);

String initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '·';
  return p.length == 1 ? p.first.characters.first : '${p.first.characters.first}${p[1].characters.first}';
}

String fileSize(int b) => b >= 1048576 ? '${(b / 1048576).toStringAsFixed(1)} MB' : '${(b / 1024).ceil()} KB';

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
