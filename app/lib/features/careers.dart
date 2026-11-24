import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/fmt.dart' as f;
import '../core/labels.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';

const positions = {
  'designer': 'مصمم UI/UX',
  'frontend': 'Frontend',
  'backend': 'Backend',
  'mobile': 'مطوّر موبايل',
  'devops': 'DevOps',
  'qa': 'اختبار جودة',
  'marketing': 'تسويق',
  'sales': 'مبيعات',
  'pm': 'إدارة مشاريع',
  'support': 'دعم فني',
  'other': 'أخرى',
};

Tone appTone(String s) => switch (s) { 'new' => Tone.brand, 'interview' => Tone.info, 'offer' => Tone.attn, 'hired' => Tone.success, 'rejected' => Tone.danger, _ => Tone.muted };

class CareersScreen extends StatefulWidget {
  const CareersScreen({super.key});
  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen> {
  String? status;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'طلبات التوظيف',
        eyebrow: 'careers',
        body: PagedList(
          path: 'careers',
          query: {'status': status},
          searchHint: 'اسم، إيميل أو رقم الطلب',
          empty: 'مفيش طلبات',
          emptyIcon: 'staff',
          header: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 36,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final e in {null: 'الكل', ...appStatus}.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: CiChip(selected: status == e.key, label: e.value, onSelected: (_) => setState(() => status = e.key)),
                  ),
              ]),
            ),
          ),
          item: (c, a) => Panel(
            onTap: () => c.push('/careers/${a.i('id')}'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(children: [
              Avatar(a.s('name'), size: 42),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.s('name'), style: c.tt.titleSmall),
                const SizedBox(height: 2),
                Text('${positions[a.s('position')] ?? a.s('position')} · ${a.s('experience')} سنين', style: c.tt.bodySmall),
                const SizedBox(height: 2),
                Text('${a.s('number')} · ${f.ago(a.t('created_at'))}', style: mono(c, size: 10.5)),
              ])),
              Pill(a.s('status_label', lbl(appStatus, a.s('status'))), tone: appTone(a.s('status')), dense: true),
            ]),
          ),
        ),
      );
}

class ApplicationScreen extends StatelessWidget {
  const ApplicationScreen({super.key, required this.id});
  final int id;
  static const _next = {'reviewing': 'ابدأ المراجعة', 'interview': 'حدد مقابلة', 'offer': 'اعرض عليه الشغل', 'hired': 'اتعيّن'};
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'طلب توظيف',
        eyebrow: 'application #$id',
        body: Loader(
          load: () => Api.I.get('careers/$id'),
          builder: (c, r, reload) {
            final a = r.o('data');
            final flow = ['new', 'reviewing', 'interview', 'offer', 'hired'];
            final idx = flow.indexOf(a.s('status'));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar(a.s('name'), size: 56),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.s('name'), style: c.tt.headlineSmall),
                  Text('${positions[a.s('position')] ?? a.s('position')} · ${a.s('experience')} سنين خبرة', style: c.tt.bodyMedium!.copyWith(color: c.ci.muted)),
                  Text(a.s('number'), style: mono(c, size: 11.5, color: c.ci.brand, w: FontWeight.w600)),
                ])),
              ]),
              const SizedBox(height: 18),
              if (a.s('status') != 'rejected') ...[
                StageTrack(total: flow.length, done: idx + 1),
                const SizedBox(height: 6),
                Row(children: [for (final s in flow) Expanded(child: Text(lbl(appStatus, s), textAlign: TextAlign.center, style: c.tt.labelSmall!.copyWith(fontSize: 10, color: s == a.s('status') ? c.ci.brand : null)))]),
                const SizedBox(height: 14),
              ] else
                Padding(padding: const EdgeInsets.only(bottom: 14), child: Pill(lbl(appStatus, 'rejected'), tone: Tone.danger)),
              Row(children: [
                if (idx >= 0 && idx < flow.length - 1)
                  Expanded(child: FilledButton(onPressed: () => _set(c, flow[idx + 1], reload), child: Text(_next[flow[idx + 1]] ?? lbl(appStatus, flow[idx + 1])))),
                if (idx >= 0 && idx < flow.length - 1) const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: () async {
                    final v = await pickOne(c, 'حالة الطلب', appStatus, current: a.s('status'));
                    if (v != null && v != a.s('status') && c.mounted) _set(c, v, reload);
                  },
                  child: const Text('غيّر الحالة'),
                )),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                if (a.has('phone')) Expanded(child: OutlinedButton.icon(onPressed: () => call(a.s('phone')), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('اتصل'))),
                if (a.has('phone')) const SizedBox(width: 8),
                if (a.has('whatsapp') || a.has('phone')) Expanded(child: OutlinedButton.icon(onPressed: () => whatsapp(a.has('whatsapp') ? a.s('whatsapp') : a.s('phone')), icon: const Icon(Icons.chat_rounded, size: 18), label: const Text('واتساب'))),
              ]),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  KV('إيميل', a.s('email'), monoValue: true, onTap: () => c.push('/mail/compose?to=${Uri.encodeComponent(a.s('email'))}')),
                  if (a.has('phone')) KV('تليفون', a.s('phone'), monoValue: true),
                  if (a.has('portfolio_url')) KV('أعماله', a.s('portfolio_url'), onTap: () => openUrl(a.s('portfolio_url'))),
                  KV('قدّم', f.dateTime(a.t('created_at')), monoValue: true),
                ]),
              ),
              if (a.l('files').isNotEmpty) ...[
                SectionTitle('الملفات', count: a.l('files').length),
                Panel(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Column(children: [for (final x in a.l('files')) FileRow(x)])),
              ],
              if (a.l('answers').isNotEmpty) ...[
                const SectionTitle('إجاباته'),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(children: [for (final x in a.l('answers')) KV(x.s('key'), x.s('value'))]),
                ),
              ],
              SectionTitle('ملاحظات الفريق', action: 'عدّل', onAction: () async {
                final n = await askText(c, 'ملاحظات على المتقدم', initial: a.s('notes'), required: false, action: 'احفظ', lines: 8);
                if (n == null || !c.mounted) return;
                if (await doAction(c, () => Api.I.put('careers/$id', {'notes': n}), success: 'الملاحظات اتحفظت.') != null) reload();
              }),
              Panel(child: Text(a.s('notes').isEmpty ? 'مفيش ملاحظات لسه.' : a.s('notes'), style: c.tt.bodyMedium!.copyWith(color: a.s('notes').isEmpty ? c.ci.subtle : null, height: 1.7))),
            ]);
          },
        ),
      );

  Future<void> _set(BuildContext c, String status, Future<void> Function() reload) async {
    if (status == 'rejected' && !await confirm(c, 'ترفض الطلب ده؟', yes: 'ارفض', danger: true)) return;
    if (!c.mounted) return;
    if (await doAction(c, () => Api.I.put('careers/$id', {'status': status}), success: 'الحالة بقت ${lbl(appStatus, status)}.') != null) reload();
  }
}
