import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/fmt.dart' as f;
import '../core/labels.dart';
import '../core/obj.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';

Color attColor(BuildContext c, String s) => switch (s) {
      'present' => c.ci.success,
      'late' => c.ci.attn,
      'absent' => c.ci.danger,
      'excused' => c.ci.info,
      'remote' => c.ci.teal,
      'leave' => c.ci.info,
      'holiday' || 'off' => c.ci.control,
      _ => Colors.transparent,
    };

String _ym(DateTime d) => '${d.year}-${f.two(d.month)}';
DateTime _parseYm(String ym) => DateTime.tryParse('$ym-01') ?? DateTime.now();

/* ================================================================== punch */

/// Check in / check out card (home + my file). Same action as the web punch button.
class PunchCard extends StatefulWidget {
  const PunchCard({super.key, required this.today, this.onDone});
  final Obj today;
  final Future<void> Function()? onDone;
  @override
  State<PunchCard> createState() => _PunchCardState();
}

class _PunchCardState extends State<PunchCard> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.today;
    final inAt = t.t('check_in'), outAt = t.t('check_out');
    final done = inAt != null && outAt != null;
    final label = inAt == null ? 'سجّل حضور' : (outAt == null ? 'سجّل انصراف' : 'يومك خلص');
    final worked = inAt == null ? null : (outAt ?? DateTime.now()).difference(inAt);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('attendance.today'),
            const SizedBox(height: 8),
            // shrinks instead of overflowing when the phone uses large text
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(children: [
                _Stamp('حضور', inAt, warn: t.i('late_minutes') > 0),
                Container(width: 18, height: 1, margin: const EdgeInsets.symmetric(horizontal: 10), color: context.ci.line),
                _Stamp('انصراف', outAt),
              ]),
            ),
            if (worked != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${worked.inHours} س ${worked.inMinutes % 60} د شغل${t.i('late_minutes') > 0 ? ' · متأخر ${t.i('late_minutes')} د' : ''}', style: context.tt.bodySmall)),
            if (inAt == null && t.has('work_start')) Padding(padding: const EdgeInsets.only(top: 6), child: Text('اليوم بيبدأ ${t.s('work_start')}', style: context.tt.bodySmall)),
          ]),
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 48), backgroundColor: outAt == null && inAt != null ? context.ci.ink : null, foregroundColor: outAt == null && inAt != null ? context.ci.bg : null),
          onPressed: done || busy
              ? null
              : () async {
                  final ok = await confirm(context, inAt == null ? 'تسجّل حضور دلوقتي؟' : 'تسجّل انصراف دلوقتي؟', yes: label);
                  if (!ok || !context.mounted) return;
                  setState(() => busy = true);
                  final r = await doAction(context, () => Api.I.post('hr/punch'));
                  if (r != null) HapticFeedback.mediumImpact();
                  if (mounted) setState(() => busy = false);
                  if (r != null) await widget.onDone?.call();
                },
          child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
        ),
      ]),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.label, this.at, {this.warn = false});
  final String label;
  final DateTime? at;
  final bool warn;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(at == null ? '--:--' : f.time(at), style: numStyle(context, size: 20, color: at == null ? context.ci.subtle : (warn ? context.ci.attn : context.ci.ink))),
        Text(label, style: context.tt.labelSmall),
      ]);
}

/* ================================================================== my file + employee */

class MyFileScreen extends StatefulWidget {
  const MyFileScreen({super.key});
  @override
  State<MyFileScreen> createState() => _MyFileScreenState();
}

class _MyFileScreenState extends State<MyFileScreen> {
  String month = _ym(DateTime.now());
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'ملفي',
        eyebrow: 'hr.me',
        back: false,
        actions: [IconButton(onPressed: () => context.push('/settings'), icon: const CiIcon('gear', size: 20))],
        body: Loader(
          key: ValueKey(month),
          load: () => Api.I.get('hr/me', {'month': month}),
          builder: (c, d, reload) => d.b('no_file')
              ? Column(children: [
                  const EmptyState('إنت لسه مالكش ملف موظف', icon: 'staff'),
                  Text('اعمل لنفسك ملف لو عايز تسجّل حضورك وتشوف إجازاتك.', style: c.tt.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (await doAction(c, () => Api.I.post('hr/me', {})) != null) reload();
                    },
                    child: const Text('اعمل ملفي'),
                  ),
                ])
              : EmployeeFile(d, onMonth: (m) => setState(() => month = m), reload: reload),
        ),
      );
}

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key, required this.id});
  final int id;
  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  String month = _ym(DateTime.now());
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'ملف موظف',
        eyebrow: 'hr.employee #${widget.id}',
        body: Loader(
          key: ValueKey(month),
          load: () => Api.I.get('hr/employees/${widget.id}', {'month': month}),
          builder: (c, d, reload) => EmployeeFile(d, onMonth: (m) => setState(() => month = m), reload: reload),
        ),
      );
}

/// Shared body of "ملفي" and an employee's file: header, today, month calendar, leave balance, payslips.
class EmployeeFile extends StatelessWidget {
  const EmployeeFile(this.d, {super.key, required this.onMonth, required this.reload});
  final Obj d;
  final ValueChanged<String> onMonth;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final e = d.o('employee');
    final self = d.b('self');
    final sum = d.o('summary').o('sum');
    final bal = d.o('balance');
    final m = _parseYm(d.s('month'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Avatar(e.s('name'), size: 58),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.s('name'), style: context.tt.headlineSmall),
          const SizedBox(height: 2),
          Text([if (d.has('job_title')) d.s('job_title'), d.o('department').s('name')].where((x) => x.isNotEmpty).join(' · '), style: context.tt.bodyMedium!.copyWith(color: context.ci.muted)),
          const SizedBox(height: 4),
          Text(e.s('code'), style: mono(context, size: 11.5, color: context.ci.brand, w: FontWeight.w600)),
        ])),
      ]),
      const SizedBox(height: 16),
      if (self) PunchCard(today: d.o('today').j.isEmpty ? const Obj({}) : Obj({...d.o('today').j, 'work_start': d.s('work_start')}), onDone: reload),
      if (!self && (e.has('phone') || e.has('email')))
        Row(children: [
          if (e.has('phone')) Expanded(child: OutlinedButton.icon(onPressed: () => call(e.s('phone')), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('اتصل'))),
          if (e.has('phone') && e.has('email')) const SizedBox(width: 8),
          if (e.has('email')) Expanded(child: OutlinedButton.icon(onPressed: () => email(e.s('email')), icon: const Icon(Icons.alternate_email_rounded, size: 18), label: const Text('إيميل'))),
        ]),
      const SizedBox(height: 4),
      Row(children: [
        IconButton(tooltip: 'الشهر اللي فات', onPressed: () => onMonth(_ym(DateTime(m.year, m.month - 1))), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(child: Text(d.s('month_label'), textAlign: TextAlign.center, style: context.tt.titleMedium)),
        IconButton(tooltip: 'الشهر الجاي', onPressed: () => onMonth(_ym(DateTime(m.year, m.month + 1))), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      KpiStrip([
        ('حضور', '${sum.i('present')}', context.ci.success),
        ('تأخير', '${sum.i('late')}', sum.i('late') > 0 ? context.ci.attn : null),
        ('غياب', '${sum.i('absent')}', sum.i('absent') > 0 ? context.ci.danger : null),
        ('إجازة', '${sum.i('leave')}', null),
      ]),
      const SizedBox(height: 12),
      MonthCalendar(d.l('calendar')),
      const SizedBox(height: 8),
      _Legend(),
      SectionTitle('رصيد الإجازات', action: self ? 'اطلب إجازة' : null, onAction: () => context.push('/hr/leaves/new').then((_) => reload())),
      Panel(
        child: Column(children: [
          Row(children: [
            Text('${bal.i('left')}', style: numStyle(context, size: 30, color: context.ci.brand)),
            const SizedBox(width: 6),
            Text('يوم فاضلين من ${bal.i('allow')}', style: context.tt.bodyMedium),
          ]),
          const SizedBox(height: 10),
          Bar(bal.i('allow') == 0 ? 0 : (bal.i('taken') / bal.i('allow')).clamp(0, 1).toDouble()),
          const SizedBox(height: 8),
          Row(children: [
            Text('خدت ${bal.i('taken')}', style: context.tt.bodySmall),
            const Spacer(),
            if (bal.i('pending') > 0) Text('${bal.i('pending')} مستنية موافقة', style: context.tt.bodySmall!.copyWith(color: context.ci.warning)),
          ]),
        ]),
      ),
      if (d.l('leaves').isNotEmpty) ...[
        SectionTitle('طلبات الإجازة', count: d.l('leaves').length),
        for (final l in d.l('leaves')) Padding(padding: const EdgeInsets.only(bottom: 8), child: LeaveTile(l, onChanged: reload, mine: self)),
      ],
      if (d.l('tasks').isNotEmpty) ...[
        SectionTitle('مهام مفتوحة', count: d.l('tasks').length),
        for (final t in d.l('tasks'))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(
            onTap: () => context.push('/tasks/${t.i('id')}'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(t.s('title'), style: context.tt.titleSmall)),
              Pill(lbl(taskStatus, t.s('status')), tone: taskTone(t.s('status')), dense: true),
            ]),
          )),
      ],
      if (d.l('payslips').isNotEmpty) ...[
        const SectionTitle('المرتبات'),
        for (final p in d.l('payslips'))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(
            onTap: () => context.push('/hr/payslips/${p.i('id')}'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(p.s('month_label', f.monthLabel(p.s('month'))), style: context.tt.titleSmall)),
              Text(f.money(p.d('net')), style: numStyle(context, size: 15)),
              const SizedBox(width: 10),
              Pill(lbl(slipStatus, p.s('status')), tone: p.s('status') == 'paid' ? Tone.success : (p.s('status') == 'approved' ? Tone.info : Tone.muted), dense: true),
            ]),
          )),
      ],
      if (!self || e.has('hire_date')) ...[
        const SectionTitle('البيانات'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            KV('تاريخ التعيين', f.dateShort(e.t('hire_date')), monoValue: true),
            KV('نوع العقد', e.s('contract_label', '—')),
            if (d.o('department').has('manager')) KV('المدير', d.o('department').s('manager')),
            if (e.has('phone')) KV('تليفون', e.s('phone'), monoValue: true),
            if (e.has('email')) KV('إيميل', e.s('email'), monoValue: true),
            KV('مواعيد الشغل', '${d.s('work_start')} - ${d.s('work_end')}', monoValue: true),
          ]),
        ),
      ],
    ]);
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 6, children: [
        for (final k in ['present', 'late', 'absent', 'leave', 'remote', 'holiday'])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, color: attColor(context, k)),
            const SizedBox(width: 5),
            Text(lbl(attStatus, k), style: context.tt.labelSmall),
          ]),
      ]);
}

/// Month grid, Saturday first (the Egyptian work week). Square dots, the brand's mark.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar(this.days, {super.key, this.onTap});
  final List<Obj> days;
  final void Function(Obj day)? onTap;
  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final lead = (days.first.i('dow') + 1) % 7; // Sat = 0
    final today = f.ymd(DateTime.now());
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(children: [
        Row(children: [for (final n in ['سبت', 'حد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة']) Expanded(child: Text(n, textAlign: TextAlign.center, style: context.tt.labelSmall!.copyWith(fontSize: 10)))]),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: .9,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (final d in days) _DayCell(d, isToday: d.s('date') == today, onTap: onTap == null ? null : () => onTap!(d)),
          ],
        ),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(this.d, {required this.isToday, this.onTap});
  final Obj d;
  final bool isToday;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = d.s('status');
    final col = attColor(context, s);
    final day = DateTime.tryParse(d.s('date'))?.day ?? 0;
    final faded = s == 'future' || s == 'before';
    return InkWell(
      onTap: onTap ?? (faded ? null : () => _show(context)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: col == Colors.transparent ? null : col.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isToday ? context.ci.brand : Colors.transparent, width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$day', style: numStyle(context, size: 13, color: faded ? context.ci.subtle : context.ci.ink, w: FontWeight.w500)),
          const SizedBox(height: 3),
          Container(width: 5, height: 5, color: col),
        ]),
      ),
    );
  }

  void _show(BuildContext context) {
    final lines = [
      lbl(attStatus, d.s('status')),
      if (d.has('in')) 'حضور ${f.time(d.t('in'))}',
      if (d.has('out')) 'انصراف ${f.time(d.t('out'))}',
      if (d.i('late') > 0) 'تأخير ${d.i('late')} د',
      if (d.has('holiday')) d.s('holiday'),
      if (d.has('note')) d.s('note'),
    ];
    toast(context, '${f.dateShort(DateTime.tryParse(d.s('date')))}: ${lines.join(' · ')}');
  }
}

/* ================================================================== leaves */

class LeaveTile extends StatelessWidget {
  const LeaveTile(this.l, {super.key, this.onChanged, this.mine = true, this.decide = false});
  final Obj l;
  final Future<void> Function()? onChanged;
  final bool mine, decide;
  @override
  Widget build(BuildContext context) {
    final from = DateTime.tryParse(l.s('from')), to = DateTime.tryParse(l.s('to'));
    final range = from == to || to == null ? f.dateShort(from) : '${f.dateShort(from)} ← ${f.dateShort(to)}';
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (l.has('employee')) ...[Avatar(l.ref('employee'), size: 30), const SizedBox(width: 10)],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.has('employee') ? l.ref('employee') : 'إجازة ${l.s('type_label', lbl(leaveType, l.s('type')))}', style: context.tt.titleSmall),
            Text('${l.has('employee') ? '${l.s('type_label')} · ' : ''}$range · ${l.i('days')} يوم', style: context.tt.bodySmall),
          ])),
          Pill(l.s('status_label', lbl(leaveStatus, l.s('status'))), tone: leaveTone(l.s('status')), dense: true),
        ]),
        if (l.s('reason').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.s('reason'), style: context.tt.bodyMedium)),
        if (l.has('manager_note')) Padding(padding: const EdgeInsets.only(top: 6), child: Text('رد المدير: ${l.s('manager_note')}', style: context.tt.bodySmall!.copyWith(color: context.ci.info))),
        if (decide && l.s('status') == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton(onPressed: () => _decide(context, 'approved'), child: const Text('وافق'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _decide(context, 'rejected'), child: const Text('ارفض'))),
          ]),
        ],
        if (mine && !decide && l.s('status') == 'pending')
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () async {
                if (!await confirm(context, 'تلغي طلب الإجازة؟', yes: 'ألغيه', danger: true) || !context.mounted) return;
                if (await doAction(context, () => Api.I.post('hr/leaves/${l.i('id')}/cancel')) != null) onChanged?.call();
              },
              child: Text('ألغي الطلب', style: TextStyle(color: context.ci.danger)),
            ),
          ),
      ]),
    );
  }

  Future<void> _decide(BuildContext c, String decision) async {
    final note = await askText(c, decision == 'approved' ? 'موافقة على الإجازة' : 'رفض الإجازة', hint: 'ملاحظة للموظف (اختياري)', required: decision == 'rejected', action: decision == 'approved' ? 'وافق' : 'ارفض');
    if (note == null || !c.mounted) return;
    if (await doAction(c, () => Api.I.post('hr/leaves/${l.i('id')}/decide', {'decision': decision, 'note': note})) != null) onChanged?.call();
  }
}

class LeavesScreen extends StatelessWidget {
  const LeavesScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الإجازات',
        eyebrow: 'hr.leaves',
        fab: FloatingActionButton.extended(onPressed: () => context.push('/hr/leaves/new'), icon: const CiIcon('plus', size: 18), label: const Text('اطلب إجازة')),
        body: Loader(
          load: () => Api.I.get('hr/leaves'),
          builder: (c, d, reload) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (d.b('deciding')) ...[
              SectionTitle('مستنية قرارك', count: d.l('inbox').length),
              if (d.l('inbox').isEmpty) Text('مفيش طلبات مستنية.', style: c.tt.bodySmall),
              for (final l in d.l('inbox')) Padding(padding: const EdgeInsets.only(bottom: 8), child: LeaveTile(l, decide: true, mine: false, onChanged: reload)),
            ],
            SectionTitle('طلباتي', count: d.l('mine').length),
            if (d.l('mine').isEmpty) Text('مفيش طلبات.', style: c.tt.bodySmall),
            for (final l in d.l('mine')) Padding(padding: const EdgeInsets.only(bottom: 8), child: LeaveTile(l, onChanged: reload)),
            if (d.l('history').isNotEmpty) ...[
              const SectionTitle('اللي اتقرر'),
              for (final l in d.l('history')) Padding(padding: const EdgeInsets.only(bottom: 8), child: LeaveTile(l, mine: false, decide: true, onChanged: reload)),
            ],
          ]),
        ),
      );
}

class NewLeaveScreen extends StatefulWidget {
  const NewLeaveScreen({super.key});
  @override
  State<NewLeaveScreen> createState() => _NewLeaveScreenState();
}

class _NewLeaveScreenState extends State<NewLeaveScreen> {
  String type = 'annual';
  DateTime from = DateTime.now().add(const Duration(days: 1));
  DateTime to = DateTime.now().add(const Duration(days: 1));
  final reason = TextEditingController();
  bool busy = false;

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'طلب إجازة',
        eyebrow: 'hr.leaves.new',
        body: Loader(
          load: () => Api.I.get('hr/leaves'),
          builder: (c, d, reload) {
            final bal = d.o('balance');
            final types = d.o('types').j.isEmpty ? leaveType : d.o('types').j.map((k, v) => MapEntry(k, '$v'));
            final days = to.difference(from).inDays + 1;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Panel(
                color: c.ci.brandSoft,
                border: c.ci.brand.withValues(alpha: .25),
                child: Row(children: [
                  Text('${bal.i('left')}', style: numStyle(c, size: 26, color: c.ci.brand)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('يوم فاضلين في رصيد الاعتيادي', style: c.tt.bodyMedium)),
                ]),
              ),
              const SizedBox(height: 16),
              FieldLabel('نوع الإجازة', child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in types.entries) CiChip(selected: type == e.key, label: e.value, onSelected: (_) => setState(() => type = e.key)),
              ])),
              Row(children: [
                Expanded(child: FieldLabel('من', child: PickBox(text: f.dateShort(from), onTap: () async {
                  final x = await pickDate(c, initial: from);
                  if (x != null) {
                    setState(() {
                      from = x;
                      if (to.isBefore(x)) to = x;
                    });
                  }
                }))),
                const SizedBox(width: 12),
                Expanded(child: FieldLabel('لحد', child: PickBox(text: f.dateShort(to), onTap: () async {
                  final x = await pickDate(c, initial: to, first: from);
                  if (x != null) setState(() => to = x);
                }))),
              ]),
              Text('$days يوم (الجمعة والإجازات الرسمية مش بتتحسب)', style: c.tt.bodySmall),
              const SizedBox(height: 16),
              FieldLabel('السبب', child: TextField(controller: reason, minLines: 2, maxLines: 5)),
              FilledButton(onPressed: busy ? null : _save, child: const Text('ابعت الطلب')),
            ]);
          },
        ),
      );

  Future<void> _save() async {
    setState(() => busy = true);
    final r = await doAction(context, () => Api.I.post('hr/leaves', {'type': type, 'start_date': f.ymd(from), 'end_date': f.ymd(to), 'reason': reason.text.trim()}), success: 'الطلب اتبعت لمديرك.');
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) context.pop(true);
  }
}

/* ================================================================== employees + attendance */

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الموظفين',
        eyebrow: 'hr.employees',
        actions: [
          if (Session.I.can('hr_attendance')) IconButton(tooltip: 'الحضور', onPressed: () => context.push('/hr/attendance'), icon: const CiIcon('calendar', size: 20)),
        ],
        body: Loader(
          load: () => Api.I.get('hr/employees'),
          builder: (c, d, reload) {
            final st = d.o('stats');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KpiStrip([
                ('موجودين', '${st.i('in')}', c.ci.success),
                ('متأخرين', '${st.i('late')}', st.i('late') > 0 ? c.ci.attn : null),
                ('إجازة', '${st.i('leave')}', null),
                ('لسه ماجوش', '${st.i('missing')}', st.i('missing') > 0 && d.b('workday') ? c.ci.danger : null),
              ]),
              const SizedBox(height: 12),
              CommandField(hint: 'دوّر بالاسم أو الكود', onChanged: (v) => setState(() => q = v.trim())),
              for (final dep in d.l('departments'))
                if (dep.l('people').any(_match)) ...[
                  SectionTitle(dep.s('name'), count: dep.l('people').where(_match).length),
                  for (final p in dep.l('people').where(_match)) Padding(padding: const EdgeInsets.only(bottom: 8), child: _PersonRow(p)),
                ],
            ]);
          },
        ),
      );

  bool _match(Obj p) => q.isEmpty || p.s('name').contains(q) || p.s('code').toLowerCase().contains(q.toLowerCase());
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(this.p);
  final Obj p;
  @override
  Widget build(BuildContext context) {
    final today = p.s('today');
    final (label, col) = switch (today) {
      'in' => ('موجود ${f.time(p.t('today_in'))}', context.ci.success),
      'late' => ('متأخر ${f.time(p.t('today_in'))}', context.ci.attn),
      'out' => ('مشي', context.ci.subtle),
      'leave' => ('إجازة', context.ci.info),
      'remote' => ('من البيت', context.ci.teal),
      _ => ('لسه', context.ci.subtle),
    };
    return Panel(
      onTap: () => context.push('/hr/employees/${p.i('id')}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Avatar(p.s('name'), size: 40, online: today == 'in' || today == 'late'),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.s('name'), style: context.tt.titleSmall),
          Text('${p.s('code')}${p.has('job_title') ? ' · ${p.s('job_title')}' : ''}', style: context.tt.bodySmall),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, color: col), const SizedBox(width: 5), Text(label, style: context.tt.labelSmall!.copyWith(color: col))]),
          if (p.i('tasks_open') > 0) Text('${p.i('tasks_open')} مهمة${p.i('tasks_late') > 0 ? ' · ${p.i('tasks_late')} متأخرة' : ''}', style: context.tt.labelSmall!.copyWith(color: p.i('tasks_late') > 0 ? context.ci.danger : null)),
        ]),
      ]),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String month = _ym(DateTime.now());
  int? group;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الحضور والانصراف',
        eyebrow: 'hr.attendance',
        body: Loader(
          key: ValueKey('$month$group'),
          load: () => Api.I.get('hr/attendance', {'month': month, 'group': group}),
          builder: (c, d, reload) {
            final m = _parseYm(d.s('month', month));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                IconButton(onPressed: () => setState(() => month = _ym(DateTime(m.year, m.month - 1))), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Text(f.monthLabel(d.s('month', month)), textAlign: TextAlign.center, style: c.tt.titleMedium)),
                IconButton(onPressed: () => setState(() => month = _ym(DateTime(m.year, m.month + 1))), icon: const Icon(Icons.chevron_right_rounded)),
              ]),
              SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final g in [const Obj({'id': null, 'name': 'كل الأقسام'}), ...d.l('departments')])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: CiChip(selected: group == (g.j['id'] as int?), label: g.s('name'), onSelected: (_) => setState(() => group = g.j['id'] as int?)),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              _Legend(),
              for (final r in d.l('rows')) ...[
                SectionTitle(r.o('employee').s('name'), action: 'الملف', onAction: () => c.push('/hr/employees/${r.o('employee').i('id')}')),
                MonthCalendar(r.l('days'), onTap: (day) => _edit(c, r.o('employee'), day, reload)),
              ],
            ]);
          },
        ),
      );

  Future<void> _edit(BuildContext c, Obj emp, Obj day, Future<void> Function() reload) async {
    if (day.s('status') == 'future' || day.s('status') == 'before') return;
    final opts = {for (final k in ['present', 'late', 'absent', 'excused', 'remote']) k: lbl(attStatus, k)};
    final v = await pickOne(c, '${emp.s('name')} · ${f.dateShort(DateTime.tryParse(day.s('date')))}', opts, current: day.s('status'));
    if (v == null || v == day.s('status') || !c.mounted) return;
    String hm(DateTime? t) => t == null ? '' : '${f.two(t.hour)}:${f.two(t.minute)}';
    if (await doAction(c, () => Api.I.post('hr/attendance', {
          'user_id': emp.i('id'),
          'date': day.s('date'),
          'status': v,
          'check_in': hm(day.t('in')),
          'check_out': hm(day.t('out')),
          'note': day.s('note'),
        })) != null) {
      reload();
    }
  }
}

/* ================================================================== payroll */

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  String month = _ym(DateTime.now());
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'المرتبات',
        eyebrow: 'hr.payroll',
        body: Loader(
          key: ValueKey(month),
          load: () => Api.I.get('hr/payroll', {'month': month}),
          builder: (c, d, reload) {
            final t = d.o('totals');
            final rows = d.l('rows');
            Future<void> run(String action, String q, {List<int>? ids}) async {
              if (!await confirm(c, q) || !c.mounted) return;
              if (await doAction(c, () => Api.I.post('hr/payroll/$action', {'month': d.s('month'), 'ids': ?ids})) != null) reload();
            }

            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                IconButton(onPressed: () => setState(() => month = d.s('prev')), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Text(d.s('month_label'), textAlign: TextAlign.center, style: c.tt.titleMedium)),
                IconButton(onPressed: () => setState(() => month = d.s('next')), icon: const Icon(Icons.chevron_right_rounded)),
              ]),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Eyebrow('net.total'),
                  const SizedBox(height: 6),
                  Text(f.money(t.d('net')), style: numStyle(c, size: 30)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text('أساسي ${f.money(t.d('base'), short: true)}', style: c.tt.bodySmall),
                    const SizedBox(width: 12),
                    Text('+ ${f.money(t.d('add'), short: true)}', style: c.tt.bodySmall!.copyWith(color: c.ci.success)),
                    const SizedBox(width: 12),
                    Text('- ${f.money(t.d('ded'), short: true)}', style: c.tt.bodySmall!.copyWith(color: c.ci.danger)),
                  ]),
                  const SizedBox(height: 12),
                  StageTrack(total: 3, done: t.i('paid') > 0 && t.i('draft') == 0 && t.i('approved') == 0 ? 3 : (t.i('approved') > 0 && t.i('draft') == 0 ? 2 : 1)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('مسودة ${t.i('draft')}', style: c.tt.labelSmall)),
                    Expanded(child: Text('اتعتمد ${t.i('approved')}', textAlign: TextAlign.center, style: c.tt.labelSmall)),
                    Expanded(child: Text('اتصرف ${t.i('paid')}', textAlign: TextAlign.end, style: c.tt.labelSmall)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => run('refresh', 'تحسب المرتبات من جديد من الحضور والإجازات؟'), child: const Text('احسب تاني'))),
                const SizedBox(width: 8),
                if (t.i('draft') > 0) Expanded(child: FilledButton(onPressed: () => run('approve', 'تعتمد كل المسودات؟'), child: const Text('اعتمد الكل'))),
                if (t.i('draft') == 0 && t.i('approved') > 0) Expanded(child: FilledButton(onPressed: () => run('paid', 'تعلّم إن المرتبات المعتمدة اتصرفت؟'), child: const Text('اتصرفت'))),
              ]),
              SectionTitle('الموظفين', count: rows.length),
              for (final p in rows)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(
                  onTap: () => c.push('/hr/payslips/${p.i('id')}'),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    Avatar(p.ref('employee'), size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.ref('employee'), style: c.tt.titleSmall),
                      Text('${p.s('code')} · ${p.s('department')}', style: c.tt.bodySmall),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(f.money(p.d('net')), style: numStyle(c, size: 14)),
                      if (p.d('deductions') > 0) Text('- ${f.group(p.d('deductions'))}', style: mono(c, size: 10.5, color: c.ci.danger)),
                    ]),
                  ]),
                )),
              if (d.l('no_salary').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${d.l('no_salary').length} موظف من غير مرتب أساسي متسجل.', style: c.tt.bodySmall!.copyWith(color: c.ci.warning))),
            ]);
          },
        ),
      );
}

class PayslipScreen extends StatelessWidget {
  const PayslipScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'قسيمة مرتب',
        eyebrow: 'payslip #$id',
        body: Loader(
          load: () => Api.I.get('hr/payslips/$id'),
          builder: (c, r, reload) {
            final s = r.o('data');
            final a = s.o('attendance');
            final adds = s.l('lines').where((l) => l.s('group') == 'add').toList();
            final deds = s.l('lines').where((l) => l.s('group') == 'ded').toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(s.s('month_label'), style: c.tt.titleMedium),
                    const Spacer(),
                    Pill(lbl(slipStatus, s.s('status')), tone: s.s('status') == 'paid' ? Tone.success : (s.s('status') == 'approved' ? Tone.info : Tone.muted)),
                  ]),
                  Text(s.ref('employee'), style: c.tt.bodyMedium!.copyWith(color: c.ci.muted)),
                  const SizedBox(height: 16),
                  const Eyebrow('net'),
                  const SizedBox(height: 4),
                  Text(f.money(s.d('net')), style: numStyle(c, size: 34, color: c.ci.brand)),
                ]),
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  KV('الأساسي', f.money(s.d('base')), monoValue: true),
                  for (final l in adds) KV(l.s('label'), '+ ${f.money(l.d('amount'))}', monoValue: true),
                  for (final l in deds) KV('${l.s('label')}${l.has('note') ? ' (${l.s('note')})' : ''}', '- ${f.money(l.d('amount'))}', monoValue: true),
                  KV('الصافي', f.money(s.d('net')), monoValue: true),
                ]),
              ),
              const SectionTitle('حضور الشهر'),
              KpiStrip([
                ('أيام شغل', '${a.i('workdays')}', null),
                ('حضور', '${a.i('present')}', c.ci.success),
                ('غياب', '${a.i('absent')}', a.i('absent') > 0 ? c.ci.danger : null),
                ('دقايق تأخير', '${a.i('late_minutes')}', a.i('late_minutes') > 0 ? c.ci.attn : null),
              ]),
              if (s.has('paid_at')) Padding(padding: const EdgeInsets.only(top: 12), child: Text('اتصرف ${f.dateShort(s.t('paid_at'))}', style: c.tt.bodySmall)),
            ]);
          },
        ),
      );
}
