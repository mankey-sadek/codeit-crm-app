import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/fmt.dart' as f;
import '../core/labels.dart';
import '../core/obj.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/kit.dart';
import 'hr.dart' show PunchCard;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _hello() {
    final h = DateTime.now().hour;
    return h < 12 ? 'صباح الخير' : (h < 18 ? 'مساء النور' : 'مساء الخير');
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.I;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Loader(
          load: () async {
            final h = await Api.I.get('home');
            s.setBadges(notices: h.i('notifications_unread'), chat: h.i('chat_unread'));
            return h;
          },
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 32),
          builder: (context, h, reload) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Eyebrow(f.dateLong(DateTime.now())),
                    const SizedBox(height: 6),
                    Text('${_hello()}، ${s.firstName}', style: context.tt.headlineSmall),
                  ]),
                ),
                _RoundBtn(icon: 'search', onTap: () => context.push('/search')),
                const SizedBox(width: 8),
                _RoundBtn(icon: 'bell', badge: h.i('notifications_unread'), onTap: () async {
                  await context.push('/notifications');
                  reload();
                }),
              ]),
              const SizedBox(height: 18),
              _Sentence(h.s('sentence')),
              if (h.has('attendance')) ...[const SizedBox(height: 12), PunchCard(today: h.o('attendance'), onDone: reload)],
              if (h.has('tasks')) ..._tasks(context, h.o('tasks')),
              if (h.i('approvals') > 0) ...[
                const SizedBox(height: 12),
                Panel(
                  onTap: () => context.push('/hr/leaves'),
                  color: context.ci.warningSoft,
                  border: context.ci.warning.withValues(alpha: .35),
                  child: Row(children: [
                    CiIcon('calendar', color: context.ci.warning),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${h.i('approvals')} طلب إجازة مستني قرارك', style: context.tt.titleSmall!.copyWith(color: context.ci.warning))),
                    Icon(Icons.chevron_left_rounded, color: context.ci.warning),
                  ]),
                ),
              ],
              if (h.has('tickets')) ..._tickets(context, h.o('tickets')),
              if (h.l('activities').isNotEmpty) ..._activities(context, h.l('activities')),
              if (h.l('pipeline').isNotEmpty) ..._pipeline(context, h.l('pipeline')),
              if (h.has('invoices')) ..._invoices(context, h.o('invoices')),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tasks(BuildContext c, Obj t) => [
        SectionTitle('مهامي', action: 'كل المهام', onAction: () => c.go('/tasks')),
        KpiStrip([
          ('مفتوحة', '${t.i('open')}', null),
          ('متأخرة', '${t.i('late')}', t.i('late') > 0 ? c.ci.danger : null),
          ('النهارده', '${t.i('today')}', t.i('today') > 0 ? c.ci.attn : null),
          ('مراجعة', '${t.i('review')}', null),
        ]),
        const SizedBox(height: 10),
        if (t.l('next').isEmpty) Panel(child: Text('مفيش مهام مفتوحة. 👌', style: c.tt.bodyMedium!.copyWith(color: c.ci.muted))),
        for (final x in t.l('next')) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(x)),
      ];

  List<Widget> _tickets(BuildContext c, Obj t) => [
        SectionTitle('الدعم الفني', action: 'كل التذاكر', onAction: () => c.push('/tickets'), count: t.i('open')),
        if (t.i('late') > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${t.i('late')} تذكرة عدّت وقت الرد', style: c.tt.labelMedium!.copyWith(color: c.ci.danger)),
          ),
        for (final x in t.l('next')) Padding(padding: const EdgeInsets.only(bottom: 8), child: TicketTile(x)),
      ];

  List<Widget> _activities(BuildContext c, List<Obj> a) => [
        SectionTitle('مواعيد النهارده', action: 'الأجندة', onAction: () => c.push('/activities')),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (final x in a)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  SizedBox(width: 48, child: Text(f.time(x.t('schedule_from')), style: mono(c, size: 13, color: c.ci.ink))),
                  Container(width: 2, height: 28, color: c.ci.brand, margin: const EdgeInsetsDirectional.only(end: 12)),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(x.s('title'), style: c.tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(lbl(activityType, x.s('type')), style: c.tt.bodySmall),
                  ])),
                ]),
              ),
          ]),
        ),
      ];

  List<Widget> _pipeline(BuildContext c, List<Obj> st) {
    final open = st.where((s) => s.s('code') != 'won' && s.s('code') != 'lost').toList();
    final max = open.fold<double>(1, (m, s) => s.d('value') > m ? s.d('value') : m);
    final total = open.fold<double>(0, (m, s) => m + s.d('value'));
    return [
      SectionTitle('المبيعات', action: 'الـ Pipeline', onAction: () => c.push('/leads')),
      Panel(
        onTap: () => c.push('/leads'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.money(total), style: numStyle(c, size: 24)),
          Text('قيمة الفرص المفتوحة', style: c.tt.bodySmall),
          const SizedBox(height: 14),
          for (final s in open)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(width: 92, child: Text(s.s('name'), style: c.tt.labelMedium, overflow: TextOverflow.ellipsis)),
                Expanded(child: Bar(s.d('value') / max, height: 6)),
                SizedBox(width: 36, child: Text('${s.i('count')}', textAlign: TextAlign.end, style: mono(c, size: 12, color: c.ci.ink))),
              ]),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _invoices(BuildContext c, Obj i) => [
        SectionTitle('الفلوس', action: 'الفواتير', onAction: () => c.push('/invoices')),
        KpiStrip([
          ('مستحق', f.money(i.d('due'), short: true), null),
          ('متأخر', f.money(i.d('overdue'), short: true), i.d('overdue') > 0 ? c.ci.danger : null),
          ('فواتير', '${i.i('count')}', null),
        ]),
        if (i.i('reported') > 0)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('${i.i('reported')} عميل بلّغ إنه دفع، محتاج تأكيد', style: c.tt.labelMedium!.copyWith(color: c.ci.attn))),
      ];
}

class _Sentence extends StatelessWidget {
  const _Sentence(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.ci.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.ci.line),
        ),
        // the mint bar on the start edge, inside the rounded card
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 3, color: context.ci.brand),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 14, 16, 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('>', style: mono(context, size: 15, color: context.ci.brand, w: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Expanded(child: Text.rich(TextSpan(children: [TextSpan(text: text, style: context.tt.bodyLarge!.copyWith(height: 1.6)), const WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: EdgeInsetsDirectional.only(start: 4), child: Caret(height: 15)))]))),
                ]),
              ),
            ),
          ]),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.badge = 0});
  final String icon;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: context.ci.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.ci.line)),
          child: Stack(alignment: Alignment.center, children: [
            CiIcon(icon, size: 20, color: context.ci.ink),
            if (badge > 0) PositionedDirectional(top: 9, end: 10, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: context.ci.brand, borderRadius: BorderRadius.circular(2)))),
          ]),
        ),
      );
}

/* ------------------------------------------------------------------ shared tiles */

class TaskTile extends StatelessWidget {
  const TaskTile(this.t, {super.key, this.showAssignee = false});
  final Obj t;
  final bool showAssignee;
  @override
  Widget build(BuildContext context) {
    final late = t.b('late');
    final due = t.t('due_date');
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => context.push('/tasks/${t.i('id')}'),
      child: Row(children: [
        Container(width: 3, height: 38, decoration: BoxDecoration(color: late ? context.ci.danger : toneColors(context, taskTone(t.s('status'))).$1, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.s('title'), style: context.tt.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill(lbl(taskStatus, t.s('status')), tone: taskTone(t.s('status')), dense: true),
              if (t.s('priority') != 'normal' && t.s('priority').isNotEmpty) Pill(lbl(taskPriority, t.s('priority')), tone: priorityTone(t.s('priority')), dense: true),
              if (showAssignee && t.has('assignee')) Text(t.ref('assignee'), style: context.tt.bodySmall),
              if (t.has('project')) Text(t.ref('project'), style: context.tt.bodySmall, overflow: TextOverflow.ellipsis),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        if (due != null && t.s('status') != 'done')
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(f.dateShort(due), style: mono(context, size: 11.5, color: late ? context.ci.danger : context.ci.muted)),
            const SizedBox(height: 2),
            Text(f.until(due), style: mono(context, size: 10.5, color: late ? context.ci.danger : context.ci.subtle)),
          ]),
      ]),
    );
  }
}

class TicketTile extends StatelessWidget {
  const TicketTile(this.t, {super.key});
  final Obj t;
  @override
  Widget build(BuildContext context) {
    final sla = t.j['sla_minutes'];
    final slaMin = sla is num ? sla.toInt() : null;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => context.push('/tickets/${t.i('id')}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(t.s('number'), style: mono(context, size: 11.5)),
          const SizedBox(width: 8),
          Pill(lbl(ticketPriority, t.s('priority')), tone: priorityTone(t.s('priority')), dense: true),
          const Spacer(),
          if (slaMin != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: slaMin < 0 ? context.ci.dangerSoft : (slaMin < 60 ? context.ci.attnSoft : context.ci.sunken), borderRadius: BorderRadius.circular(4)),
              child: Text(f.left(slaMin), style: mono(context, size: 11, color: slaMin < 0 ? context.ci.danger : (slaMin < 60 ? context.ci.attn : context.ci.muted))),
            )
          else
            Pill(lbl(ticketStatus, t.s('status')), tone: ticketTone(t.s('status')), dense: true),
        ]),
        const SizedBox(height: 8),
        Text(t.s('subject'), style: context.tt.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (t.has('client')) ...[const SizedBox(height: 3), Text(t.ref('client'), style: context.tt.bodySmall)],
      ]),
    );
  }
}

/* ------------------------------------------------------------------ search */

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Obj? res;
  bool busy = false;
  String q = '';

  Future<void> run(String v) async {
    q = v.trim();
    if (q.length < 2) return setState(() => res = null);
    setState(() => busy = true);
    try {
      final r = await Api.I.get('search', {'q': q});
      if (mounted && v.trim() == q) setState(() => res = r.o('data'));
    } on ApiError catch (_) {
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const groups = {
    'leads': ('فرص البيع', 'chart', '/leads/'),
    'persons': ('العملاء', 'users', '/persons/'),
    'organizations': ('الشركات', 'folder', '/organizations/'),
    'projects': ('المشاريع', 'code', '/projects/'),
    'tickets': ('التذاكر', 'bug', '/tickets/'),
    'tasks': ('المهام', 'tasks', '/tasks/'),
    'employees': ('الموظفين', 'staff', '/hr/employees/'),
  };

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'بحث',
        eyebrow: 'في كل الـ CRM',
        body: ListView(padding: const EdgeInsets.all(16), children: [
          CommandField(hint: 'اسم عميل، مشروع، تذكرة، موظف...', autofocus: true, onChanged: run),
          if (busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2)),
          if (res != null && groups.keys.every((k) => res!.l(k).isEmpty)) EmptyState('مفيش نتايج لـ "$q"', icon: 'search'),
          if (res != null)
            for (final g in groups.entries)
              if (res!.l(g.key).isNotEmpty) ...[
                SectionTitle(g.value.$1, count: res!.l(g.key).length),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final x in res!.l(g.key))
                      ListTile(
                        leading: CiIcon(g.value.$2, size: 20, color: context.ci.muted),
                        title: Text(x.s('name')),
                        subtitle: x.has('code') || x.has('number') ? Text(x.s('code', x.s('number')), style: mono(context)) : null,
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => context.push('${g.value.$3}${x.i('id')}'),
                      ),
                  ]),
                ),
              ],
        ]),
      );
}

/* ------------------------------------------------------------------ notifications */

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final key = GlobalKey<PagedListState>();
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الإشعارات',
        eyebrow: 'الجرس',
        actions: [
          TextButton(
            onPressed: () async {
              await Api.I.post('notifications/read-all');
              Session.I.setBadges(notices: 0);
              key.currentState?.refresh();
            },
            child: const Text('قريت الكل'),
          ),
        ],
        body: PagedList(
          key: key,
          path: 'notifications',
          search: false,
          empty: 'مفيش إشعارات',
          emptyIcon: 'bell',
          separator: 8,
          item: (c, n) => Panel(
            padding: const EdgeInsets.all(14),
            color: n.b('is_read') ? null : c.ci.brandSoft.withValues(alpha: c.ci.dark ? .55 : .6),
            onTap: () async {
              if (!n.b('is_read')) Api.I.post('notifications/${n.i('id')}/read');
              final link = n.s('link');
              final route = crmLinkRoute(link);
              if (route != null) c.push(route);
            },
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 7), decoration: BoxDecoration(color: n.b('is_read') ? c.ci.line : c.ci.brand, borderRadius: BorderRadius.circular(1.5))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.s('title'), style: c.tt.titleSmall),
                if (n.has('body')) ...[const SizedBox(height: 3), Text(n.s('body'), style: c.tt.bodySmall)],
              ])),
              Text(f.ago(n.t('created_at')), style: mono(c, size: 11)),
            ]),
          ),
        ),
      );
}

/// CRM web links in the bell -> screens in the app.
String? crmLinkRoute(String link) {
  final m = <RegExp, String Function(Match)>{
    RegExp(r'team-tasks/(\d+)'): (m) => '/tasks/${m[1]}',
    RegExp(r'tickets/view/(\d+)'): (m) => '/tickets/${m[1]}',
    RegExp(r'projects/view/(\d+)'): (m) => '/projects/${m[1]}',
    RegExp(r'leads/view/(\d+)'): (m) => '/leads/${m[1]}',
    RegExp(r'invoices/view/(\d+)'): (m) => '/invoices/${m[1]}',
    RegExp(r'careers/view/(\d+)'): (m) => '/careers/${m[1]}',
    RegExp(r'employees/leaves'): (m) => '/hr/leaves',
    RegExp(r'employees/payslip/(\d+)'): (m) => '/hr/payslips/${m[1]}',
    RegExp(r'employees/(\d+)'): (m) => '/hr/employees/${m[1]}',
    RegExp(r'employees/me'): (m) => '/me',
    RegExp(r'/chat'): (m) => '/chat',
  };
  for (final e in m.entries) {
    final x = e.key.firstMatch(link);
    if (x != null) return e.value(x);
  }
  return null;
}
