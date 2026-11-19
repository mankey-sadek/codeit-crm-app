import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/fmt.dart' as f;
import '../core/labels.dart';
import '../core/obj.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';

final _personsKey = GlobalKey<PagedListState>(), _orgsKey = GlobalKey<PagedListState>(), _boardKey = GlobalKey<LoaderState>();

/// Krayin's default stage codes, in the CRM's Arabic wording.
const stageNames = {'new': 'جديد', 'follow-up': 'متابعة', 'prospect': 'محتمل', 'negotiation': 'تفاوض', 'won': 'اتكسب', 'lost': 'اتخسر'};
String stageName(Obj s) => stageNames[s.s('code')] ?? s.s('name');

Color stageColor(BuildContext c, String code) => switch (code) {
      'won' => c.ci.success,
      'lost' => c.ci.danger,
      'negotiation' => c.ci.attn,
      'prospect' => c.ci.info,
      _ => c.ci.brand,
    };

/* ================================================================== leads board */

class LeadsBoardScreen extends StatefulWidget {
  const LeadsBoardScreen({super.key});
  @override
  State<LeadsBoardScreen> createState() => _LeadsBoardScreenState();
}

class _LeadsBoardScreenState extends State<LeadsBoardScreen> {
  int stage = -1;
  String q = '';

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الفرص',
        eyebrow: 'sales.pipeline',
        fab: FloatingActionButton(onPressed: () => context.push('/leads/new').then((_) => _boardKey.currentState?.reload()), child: const CiIcon('plus', size: 22)),
        body: Loader(
          key: _boardKey,
          load: () => Api.I.get('leads/board', {if (q.isNotEmpty) 'q': q}),
          builder: (c, d, reload) {
            final stages = d.l('stages');
            final open = stages.where((s) => s.s('code') != 'won' && s.s('code') != 'lost');
            final pipeValue = open.fold<double>(0, (a, s) => a + s.d('value'));
            final won = stages.where((s) => s.s('code') == 'won').firstOrNull;
            final sel = stage < 0 || stage >= stages.length ? stages.indexWhere((s) => s.i('count') > 0).clamp(0, 99) : stage;
            final cur = stages.isEmpty ? null : stages[sel.clamp(0, stages.length - 1)];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KpiStrip([
                ('في الطريق', f.money(pipeValue, short: true), null),
                ('فرص مفتوحة', '${open.fold<int>(0, (a, s) => a + s.i('count'))}', null),
                ('اتكسبت', f.money(won?.d('value') ?? 0, short: true), c.ci.success),
              ]),
              const SizedBox(height: 14),
              // Funnel: every stage as a bar sized by its value; tap to open.
              Panel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(children: [
                  for (var i = 0; i < stages.length; i++) _FunnelRow(stages[i], max: stages.fold<double>(1, (a, s) => s.d('value') > a ? s.d('value') : a), active: stages[i] == cur, onTap: () => setState(() => stage = i)),
                ]),
              ),
              if (cur != null) ...[
                SectionTitle(stageName(cur), count: cur.i('count')),
                if (cur.l('leads').isEmpty) Text('مفيش فرص في المرحلة دي.', style: c.tt.bodySmall),
                for (final l in cur.l('leads')) Padding(padding: const EdgeInsets.only(bottom: 10), child: LeadTile(l)),
              ],
            ]);
          },
        ),
      );
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow(this.s, {required this.max, required this.active, required this.onTap});
  final Obj s;
  final double max;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final col = stageColor(context, s.s('code'));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 64, child: Text(stageName(s), style: context.tt.labelMedium!.copyWith(color: active ? context.ci.ink : context.ci.muted, fontWeight: active ? FontWeight.w600 : null))),
          Expanded(
            child: Stack(children: [
              Container(height: 22, decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                widthFactor: (s.d('value') / max).clamp(.02, 1).toDouble(),
                child: Container(height: 22, decoration: BoxDecoration(color: active ? col : col.withValues(alpha: .35), borderRadius: BorderRadius.circular(4))),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 22, child: Text('${s.i('count')}', textAlign: TextAlign.end, style: numStyle(context, size: 13, color: active ? context.ci.ink : context.ci.muted))),
        ]),
      ),
    );
  }
}

class LeadTile extends StatelessWidget {
  const LeadTile(this.l, {super.key});
  final Obj l;
  @override
  Widget build(BuildContext context) {
    final rotten = l.i('rotten_days') > 0;
    return Panel(
      onTap: () => context.push('/leads/${l.i('id')}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.s('title'), style: context.tt.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text([if (l.has('organization')) l.ref('organization'), if (l.has('person')) l.ref('person')].join(' · '), style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (rotten) Padding(padding: const EdgeInsets.only(top: 4), child: Text('واقفة من ${l.i('rotten_days')} يوم', style: context.tt.labelSmall!.copyWith(color: context.ci.attn))),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(f.money(l.d('value'), short: true), style: numStyle(context, size: 15)),
          if (l.has('expected_close_date')) Text(f.dateShort(l.t('expected_close_date')), style: mono(context, size: 10.5)),
        ]),
      ]),
    );
  }
}

class LeadScreen extends StatelessWidget {
  const LeadScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'فرصة',
        eyebrow: 'lead #$id',
        body: Loader(
          load: () => Api.I.get('leads/$id'),
          builder: (c, r, reload) {
            final l = r.o('data');
            final stages = l.o('pipeline').l('stages');
            final open = stages.where((s) => s.s('code') != 'won' && s.s('code') != 'lost').toList();
            final idx = open.indexWhere((s) => s.i('id') == l.refId('stage'));
            final code = l.o('stage').s('code');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Pill(stageNames[code] ?? l.ref('stage'), tone: code == 'won' ? Tone.success : (code == 'lost' ? Tone.danger : Tone.brand)),
                const Spacer(),
                if (l.has('source')) Text(l.s('source'), style: mono(c, size: 11)),
              ]),
              const SizedBox(height: 10),
              Text(l.s('title'), style: c.tt.headlineSmall),
              const SizedBox(height: 6),
              Text(f.money(l.d('value')), style: numStyle(c, size: 26, color: c.ci.brand)),
              const SizedBox(height: 18),
              if (code != 'won' && code != 'lost') ...[
                StageTrack(total: open.length, done: idx + 1),
                const SizedBox(height: 6),
                Row(children: [for (final s in open) Expanded(child: Text(stageName(s), textAlign: TextAlign.center, style: c.tt.labelSmall!.copyWith(fontSize: 10, color: s.i('id') == l.refId('stage') ? c.ci.brand : null)))]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: FilledButton(
                    onPressed: () async {
                      final v = await pickOne(c, 'انقلها لمرحلة', {for (final s in stages) '${s.i('id')}': stageName(s)}, current: '${l.refId('stage')}');
                      if (v == null || !c.mounted) return;
                      final target = stages.firstWhere((s) => '${s.i('id')}' == v);
                      String? reason;
                      if (target.s('code') == 'lost') {
                        reason = await askText(c, 'ليه اتخسرت؟', hint: 'السبب', action: 'سجّل');
                        if (reason == null) return;
                      }
                      if (!c.mounted) return;
                      if (await doAction(c, () => Api.I.post('leads/$id/stage', {'stage_id': int.parse(v), 'lost_reason': ?reason})) != null) reload();
                    },
                    child: const Text('غيّر المرحلة'),
                  )),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => c.push('/activities/new?lead=$id${l.refId('person') > 0 ? '&person=${l.refId('person')}' : ''}').then((_) => reload()), child: const Text('نشاط')),
                ]),
              ],
              if (code == 'lost' && l.has('lost_reason')) Panel(color: c.ci.dangerSoft, child: Text('سبب الخسارة: ${l.s('lost_reason')}', style: c.tt.bodyMedium)),
              const SizedBox(height: 12),
              if (l.has('phone') || l.has('email')) _ContactActions(phone: l.sn('phone'), email: l.sn('email')),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  if (l.has('person')) KV('العميل', l.ref('person'), onTap: () => c.push('/persons/${l.refId('person')}')),
                  if (l.has('organization')) KV('الشركة', l.ref('organization'), onTap: () => c.push('/organizations/${l.refId('organization')}')),
                  KV('المسؤول', l.ref('owner', '—')),
                  if (l.has('type')) KV('النوع', l.s('type')),
                  KV('الإغلاق المتوقع', f.dateShort(l.t('expected_close_date')), monoValue: true),
                  KV('اتفتحت', f.dateShort(l.t('created_at')), monoValue: true),
                ]),
              ),
              if (l.s('description').isNotEmpty) ...[const SectionTitle('التفاصيل'), Panel(child: Text(l.s('description'), style: c.tt.bodyMedium!.copyWith(height: 1.7)))],
              if (l.l('products').isNotEmpty) ...[
                const SectionTitle('المنتجات'),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(children: [
                    for (final p in l.l('products'))
                      Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
                        Expanded(child: Text(p.s('name'), style: c.tt.bodyMedium)),
                        Text('${p.s('quantity')} × ${f.group(p.d('price'))}', style: mono(c, size: 11.5)),
                      ])),
                  ]),
                ),
              ],
              if (l.l('quotes').isNotEmpty) ...[
                const SectionTitle('عروض الأسعار'),
                for (final q in l.l('quotes'))
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(
                    onTap: () => c.push('/quotes/${q.i('id')}'),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [Expanded(child: Text(q.s('subject'), style: c.tt.titleSmall)), Text(f.money(q.d('grand_total')), style: numStyle(c, size: 14))]),
                  )),
              ],
              SectionTitle('الأنشطة', count: l.l('activities').length),
              ActivityList(l.l('activities'), onChanged: reload),
            ]);
          },
        ),
      );
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({this.phone, this.email});
  final String? phone, email;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          if (phone != null) ...[
            Expanded(child: _Act(icon: Icons.call_rounded, label: 'اتصل', onTap: () => call(phone!))),
            const SizedBox(width: 8),
            Expanded(child: _Act(icon: Icons.chat_rounded, label: 'واتساب', onTap: () => whatsapp(phone!))),
            const SizedBox(width: 8),
          ],
          if (email != null) Expanded(child: _Act(icon: Icons.alternate_email_rounded, label: 'إيميل', onTap: () => context.push('/mail/compose?to=${Uri.encodeComponent(email!)}'))),
        ]),
      );
}

class _Act extends StatelessWidget {
  const _Act({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [Icon(icon, size: 20, color: context.ci.brand), const SizedBox(height: 4), Text(label, style: context.tt.labelMedium)]),
      );
}

/* ================================================================== people */

class PersonsScreen extends StatelessWidget {
  const PersonsScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'العملاء',
        eyebrow: 'contacts.persons',
        fab: FloatingActionButton(onPressed: () => context.push('/persons/new').then((_) => _personsKey.currentState?.refresh()), child: const CiIcon('plus', size: 22)),
        body: PagedList(
          key: _personsKey,
          path: 'persons',
          searchHint: 'اسم، تليفون أو إيميل',
          empty: 'مفيش عملاء',
          emptyIcon: 'users',
          separator: 8,
          item: (c, p) => Panel(
            onTap: () => c.push('/persons/${p.i('id')}'),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              Avatar(p.s('name'), size: 40),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.s('name'), style: c.tt.titleSmall),
                Text([if (p.has('job_title')) p.s('job_title'), if (p.has('organization')) p.ref('organization')].join(' · '), style: c.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              if (p.ls('phones').isNotEmpty) IconButton(onPressed: () => call(p.ls('phones').first), icon: Icon(Icons.call_rounded, size: 20, color: c.ci.brand)),
            ]),
          ),
        ),
      );
}

class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'عميل',
        eyebrow: 'person #$id',
        actions: [IconButton(tooltip: 'فرصة جديدة', onPressed: () => context.push('/leads/new?person=$id'), icon: const CiIcon('plus', size: 20))],
        body: Loader(
          load: () => Api.I.get('persons/$id'),
          builder: (c, r, reload) {
            final p = r.o('data');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar(p.s('name'), size: 56),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.s('name'), style: c.tt.headlineSmall),
                  Text([if (p.has('job_title')) p.s('job_title'), if (p.has('organization')) p.ref('organization')].join(' · '), style: c.tt.bodyMedium!.copyWith(color: c.ci.muted)),
                ])),
              ]),
              const SizedBox(height: 16),
              _ContactActions(phone: p.ls('phones').firstOrNull, email: p.ls('emails').firstOrNull),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  for (final x in p.ls('phones')) KV('تليفون', x, monoValue: true, onTap: () => call(x)),
                  for (final x in p.ls('emails')) KV('إيميل', x, monoValue: true, onTap: () => c.push('/mail/compose?to=${Uri.encodeComponent(x)}')),
                  if (p.has('organization')) KV('الشركة', p.ref('organization'), onTap: () => c.push('/organizations/${p.refId('organization')}')),
                ]),
              ),
              SectionTitle('الفرص', count: p.l('leads').length),
              for (final l in p.l('leads'))
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(
                  onTap: () => c.push('/leads/${l.i('id')}'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.s('title'), style: c.tt.titleSmall), Text(l.s('stage'), style: c.tt.bodySmall)])),
                    Text(f.money(l.d('value'), short: true), style: numStyle(c, size: 14)),
                  ]),
                )),
              SectionTitle('الأنشطة', action: 'نشاط جديد', onAction: () => c.push('/activities/new?person=$id').then((_) => reload())),
              ActivityList(p.l('activities'), onChanged: reload),
            ]);
          },
        ),
      );
}

class OrganizationsScreen extends StatelessWidget {
  const OrganizationsScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الشركات',
        eyebrow: 'contacts.organizations',
        fab: FloatingActionButton(onPressed: () => context.push('/organizations/new').then((_) => _orgsKey.currentState?.refresh()), child: const CiIcon('plus', size: 22)),
        body: PagedList(
          key: _orgsKey,
          path: 'organizations',
          searchHint: 'اسم الشركة',
          empty: 'مفيش شركات',
          emptyIcon: 'database',
          separator: 8,
          item: (c, o) => Panel(
            onTap: () => c.push('/organizations/${o.i('id')}'),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              Avatar(o.s('name'), size: 40, group: true),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.s('name'), style: c.tt.titleSmall),
                if (o.s('address').isNotEmpty) Text(o.s('address'), style: c.tt.bodySmall),
              ])),
              Text('${o.i('persons_count')}', style: numStyle(c, size: 14, color: c.ci.muted)),
              const SizedBox(width: 4),
              CiIcon('users', size: 16, color: c.ci.subtle),
            ]),
          ),
        ),
      );
}

class OrganizationScreen extends StatelessWidget {
  const OrganizationScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'شركة',
        eyebrow: 'organization #$id',
        actions: [
          PopupMenuButton<String>(
            icon: const CiIcon('plus', size: 20),
            onSelected: (v) => context.push(v),
            itemBuilder: (c) => [
              PopupMenuItem(value: '/persons/new?organization=$id', child: const Text('جهة اتصال جديدة')),
              PopupMenuItem(value: '/tickets/new?organization=$id', child: const Text('تذكرة جديدة')),
              PopupMenuItem(value: '/projects/new?organization=$id', child: const Text('مشروع جديد')),
              PopupMenuItem(value: '/invoices/new?organization=$id', child: const Text('فاتورة جديدة')),
            ],
          ),
        ],
        body: Loader(
          load: () => Api.I.get('organizations/$id'),
          builder: (c, r, reload) {
            final o = r.o('data');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar(o.s('name'), size: 56, group: true),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.s('name'), style: c.tt.headlineSmall),
                  if (o.s('address').isNotEmpty) Text(o.s('address'), style: c.tt.bodyMedium!.copyWith(color: c.ci.muted)),
                ])),
              ]),
              SectionTitle('الأشخاص', count: o.l('persons').length),
              for (final p in o.l('persons'))
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(
                  onTap: () => c.push('/persons/${p.i('id')}'),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    Avatar(p.s('name'), size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.s('name'), style: c.tt.titleSmall), if (p.has('job_title')) Text(p.s('job_title'), style: c.tt.bodySmall)])),
                    if (p.ls('phones').isNotEmpty) IconButton(onPressed: () => call(p.ls('phones').first), icon: Icon(Icons.call_rounded, size: 20, color: c.ci.brand)),
                  ]),
                )),
              if (o.l('projects').isNotEmpty) ...[
                SectionTitle('المشاريع', count: o.l('projects').length),
                for (final p in o.l('projects'))
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(
                    onTap: () => c.push('/projects/${p.i('id')}'),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Text(p.s('code'), style: mono(c, size: 11.5, color: c.ci.brand, w: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p.s('name'), style: c.tt.titleSmall)),
                      Pill(lbl(projectStage, p.s('stage')), dense: true, tone: Tone.brand),
                    ]),
                  )),
              ],
            ]);
          },
        ),
      );
}

/* ================================================================== activities */

class ActivityList extends StatelessWidget {
  const ActivityList(this.items, {super.key, this.onChanged});
  final List<Obj> items;
  final Future<void> Function()? onChanged;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text('لسه مفيش أنشطة.', style: context.tt.bodySmall);
    return Column(children: [for (final a in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: ActivityTile(a, onChanged: onChanged))]);
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile(this.a, {super.key, this.onChanged});
  final Obj a;
  final Future<void> Function()? onChanged;
  static const _icons = {'call': Icons.call_rounded, 'meeting': Icons.groups_rounded, 'lunch': Icons.restaurant_rounded, 'note': Icons.sticky_note_2_rounded, 'task': Icons.task_alt_rounded, 'email': Icons.mail_rounded, 'file': Icons.attach_file_rounded, 'system': Icons.bolt_rounded};
  @override
  Widget build(BuildContext context) {
    final done = a.b('is_done');
    final schedulable = ['call', 'meeting', 'lunch', 'task'].contains(a.s('type'));
    final from = a.t('schedule_from');
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: done ? context.ci.sunken : context.ci.brandSoft, borderRadius: BorderRadius.circular(8)),
          child: Icon(_icons[a.s('type')] ?? Icons.circle, size: 17, color: done ? context.ci.subtle : context.ci.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.s('title', lbl(activityType, a.s('type'))), style: context.tt.titleSmall!.copyWith(decoration: done && schedulable ? TextDecoration.lineThrough : null)),
            if (a.s('comment').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(a.s('comment'), style: context.tt.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 4),
            Wrap(spacing: 10, children: [
              Text(from != null ? f.dateTime(from) : f.ago(a.t('created_at')), style: mono(context, size: 10.5)),
              if (a.has('lead')) GestureDetector(onTap: () => context.push('/leads/${a.refId('lead')}'), child: Text(a.ref('lead'), style: context.tt.labelSmall!.copyWith(color: context.ci.brand))),
              if (a.has('user')) Text(a.ref('user'), style: context.tt.labelSmall),
            ]),
          ]),
        ),
        if (schedulable && onChanged != null)
          IconButton(
            tooltip: done ? 'رجّعها' : 'خلصت',
            onPressed: () async {
              if (await doAction(context, () => Api.I.put('activities/${a.i('id')}', {'is_done': done ? 0 : 1}), success: done ? 'رجعت مفتوحة.' : 'تمام، اتعلّمت إنها خلصت.') != null) onChanged!();
            },
            icon: Icon(done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: done ? context.ci.brand : context.ci.control),
          ),
      ]),
    );
  }
}

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});
  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final _key = GlobalKey<LoaderState>();
  bool showDone = false;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الأجندة',
        eyebrow: 'activities',
        actions: [
          TextButton(onPressed: () => setState(() => showDone = !showDone), child: Text(showDone ? 'اخفي اللي خلص' : 'اعرض اللي خلص')),
        ],
        fab: FloatingActionButton(onPressed: () => context.push('/activities/new').then((_) => _key.currentState?.reload()), child: const CiIcon('plus', size: 22)),
        body: Loader(
          key: _key,
          load: () => Api.I.get('activities'),
          builder: (c, r, reload) {
            final all = r.l('data').where((a) => showDone || !a.b('is_done')).toList();
            if (all.isEmpty) return const EmptyState('الأجندة فاضية', body: 'مفيش مكالمات أو اجتماعات في الأسبوعين الجايين.', icon: 'calendar');
            final byDay = <String, List<Obj>>{};
            for (final a in all) {
              byDay.putIfAbsent(f.ymd(a.t('schedule_from') ?? DateTime.now()), () => []).add(a);
            }
            final today = f.ymd(DateTime.now());
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final e in byDay.entries) ...[
                SectionTitle(e.key == today ? 'النهارده' : f.dateLong(DateTime.parse(e.key)), count: e.value.length),
                ActivityList(e.value, onChanged: reload),
              ],
            ]);
          },
        ),
      );
}

class NewActivityScreen extends StatefulWidget {
  const NewActivityScreen({super.key, this.leadId, this.personId});
  final int? leadId, personId;
  @override
  State<NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends State<NewActivityScreen> {
  String type = 'call';
  final title = TextEditingController(), comment = TextEditingController(), location = TextEditingController();
  DateTime day = DateTime.now();
  TimeOfDay from = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))).replacing(minute: 0);
  int minutes = 30;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final note = type == 'note';
    return CiPage(
      title: 'نشاط جديد',
      eyebrow: 'activities.new',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        FieldLabel('النوع', child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in ['call', 'meeting', 'lunch', 'task', 'note'])
            CiChip(selected: type == k, label: lbl(activityType, k), onSelected: (_) => setState(() => type = k)),
        ])),
        if (!note) FieldLabel('العنوان', child: TextField(controller: title, decoration: InputDecoration(hintText: type == 'call' ? 'مكالمة متابعة مع...' : 'اجتماع عن...'))),
        if (!note) ...[
          Row(children: [
            Expanded(child: FieldLabel('اليوم', child: PickBox(text: f.dateShort(day), onTap: () async {
              final d = await pickDate(context, initial: day);
              if (d != null) setState(() => day = d);
            }))),
            const SizedBox(width: 12),
            Expanded(child: FieldLabel('الساعة', child: PickBox(icon: 'clock', text: '${f.two(from.hour)}:${f.two(from.minute)}', onTap: () async {
              final t = await showTimePicker(context: context, initialTime: from);
              if (t != null) setState(() => from = t);
            }))),
          ]),
          FieldLabel('المدة', child: Wrap(spacing: 8, children: [
            for (final m in [15, 30, 60, 90, 120]) CiChip(selected: minutes == m, label: m < 60 ? '$m دقيقة' : '${m / 60 == (m ~/ 60) ? m ~/ 60 : m / 60} ساعة', onSelected: (_) => setState(() => minutes = m)),
          ])),
          if (type == 'meeting' || type == 'lunch') FieldLabel('المكان', child: TextField(controller: location)),
        ],
        FieldLabel(note ? 'الملاحظة' : 'ملاحظات', child: TextField(controller: comment, minLines: 3, maxLines: 8)),
        FilledButton(onPressed: busy ? null : _save, child: const Text('احفظ')),
      ]),
    );
  }

  Future<void> _save() async {
    if (type != 'note' && title.text.trim().isEmpty) return toast(context, 'اكتب عنوان النشاط.', error: true);
    if (type == 'note' && comment.text.trim().isEmpty) return toast(context, 'اكتب الملاحظة.', error: true);
    setState(() => busy = true);
    final start = DateTime(day.year, day.month, day.day, from.hour, from.minute);
    String ts(DateTime d) => '${f.ymd(d)} ${f.two(d.hour)}:${f.two(d.minute)}:00';
    final r = await doAction(context, () => Api.I.post('activities', {
          'type': type,
          'title': title.text.trim(),
          'comment': comment.text.trim(),
          if (type != 'note') 'schedule_from': ts(start),
          if (type != 'note') 'schedule_to': ts(start.add(Duration(minutes: minutes))),
          'location': location.text.trim(),
          'lead_id': widget.leadId,
          'person_id': widget.personId,
        }));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) context.pop(true);
  }
}

/* ================================================================== quotes + products */

class QuotesScreen extends StatelessWidget {
  const QuotesScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'عروض الأسعار',
        eyebrow: 'sales.quotes',
        body: PagedList(
          path: 'quotes',
          searchHint: 'موضوع العرض',
          empty: 'مفيش عروض أسعار',
          emptyIcon: 'invoice',
          item: (c, q) {
            final expired = q.t('expired_at')?.isBefore(DateTime.now()) ?? false;
            return Panel(
              onTap: () => c.push('/quotes/${q.i('id')}'),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(q.s('subject'), style: c.tt.titleSmall),
                  const SizedBox(height: 3),
                  Text([if (q.has('person')) q.ref('person'), if (q.has('lead')) q.ref('lead')].join(' · '), style: c.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(f.money(q.d('grand_total')), style: numStyle(c, size: 15)),
                  if (q.has('expired_at')) Text(expired ? 'انتهى' : 'لحد ${f.dateShort(q.t('expired_at'))}', style: mono(c, size: 10.5, color: expired ? c.ci.danger : null)),
                ]),
              ]),
            );
          },
        ),
      );
}

class QuoteScreen extends StatelessWidget {
  const QuoteScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'عرض سعر',
        eyebrow: 'quote #$id',
        body: Loader(
          load: () => Api.I.get('quotes/$id'),
          builder: (c, r, reload) {
            final q = r.o('data');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(q.s('subject'), style: c.tt.headlineSmall),
              const SizedBox(height: 6),
              Text(f.money(q.d('grand_total')), style: numStyle(c, size: 28, color: c.ci.brand)),
              const SizedBox(height: 14),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  if (q.has('person')) KV('العميل', q.ref('person'), onTap: () => c.push('/persons/${q.refId('person')}')),
                  if (q.has('lead')) KV('الفرصة', q.ref('lead'), onTap: () => c.push('/leads/${q.refId('lead')}')),
                  KV('المسؤول', q.ref('owner', '—')),
                  KV('صالح لحد', f.dateShort(q.t('expired_at')), monoValue: true),
                ]),
              ),
              const SectionTitle('البنود'),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(children: [
                  for (final it in q.l('items'))
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(it.s('name'), style: c.tt.bodyMedium), if (it.has('sku')) Text(it.s('sku'), style: mono(c, size: 10.5))])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(f.group(it.d('total')), style: numStyle(c, size: 13)),
                        Text('${it.s('quantity')} × ${f.group(it.d('price'))}', style: mono(c, size: 10.5)),
                      ]),
                    ])),
                  Divider(color: c.ci.line),
                  KV('المجموع', f.money(q.d('sub_total')), monoValue: true),
                  if (q.d('discount') > 0) KV('خصم', '- ${f.money(q.d('discount'))}', monoValue: true),
                  if (q.d('tax') > 0) KV('ضريبة', f.money(q.d('tax')), monoValue: true),
                  KV('الإجمالي', f.money(q.d('grand_total')), monoValue: true),
                ]),
              ),
              if (q.s('description').isNotEmpty) ...[const SectionTitle('ملاحظات'), Panel(child: Text(q.s('description'), style: c.tt.bodyMedium))],
            ]);
          },
        ),
      );
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'المنتجات والخدمات',
        eyebrow: 'products',
        body: PagedList(
          path: 'products',
          searchHint: 'اسم أو كود',
          empty: 'مفيش منتجات',
          emptyIcon: 'database',
          separator: 8,
          item: (c, p) => Panel(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.s('name'), style: c.tt.titleSmall),
                if (p.has('sku')) Text(p.s('sku'), style: mono(c, size: 10.5)),
                if (p.s('description').isNotEmpty) Text(p.s('description'), style: c.tt.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
              Text(f.money(p.d('price')), style: numStyle(c, size: 14)),
            ]),
          ),
        ),
      );
}
