import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
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
import 'home.dart' show TaskTile, TicketTile;

final _projectsKey = GlobalKey<PagedListState>(), _ticketsKey = GlobalKey<PagedListState>(), _invoicesKey = GlobalKey<PagedListState>();

/// Open a form; when it saved, show the record again (fresh).
Future<void> editThen(BuildContext c, String form, String back) async {
  if (await c.push<bool>(form) == true && c.mounted) c.pushReplacement(back);
}

/* ================================================================== tasks */

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String col = 'doing';
  String who = 'mine';
  final _key = GlobalKey<LoaderState>();

  static const _cols = ['todo', 'doing', 'review', 'done'];

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'المهام',
        eyebrow: 'team.tasks',
        back: false,
        actions: [IconButton(onPressed: () => context.push('/search'), icon: const CiIcon('search', size: 20))],
        fab: !Session.I.can('task_create') ? null : FloatingActionButton(
          onPressed: () async {
            final ok = await context.push<bool>('/tasks/new');
            if (ok == true) _key.currentState?.reload();
          },
          child: const CiIcon('plus', size: 22),
        ),
        body: Loader(
          key: _key,
          load: () => Api.I.get('tasks', {'who': who == 'mine' ? null : who}),
          builder: (c, d, reload) {
            final cols = d.o('columns');
            final stats = d.o('stats');
            final list = cols.l(col);
            final manager = d.b('manager');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KpiStrip([
                ('مفتوحة', '${stats.i('open')}', null),
                ('متأخرة', '${stats.i('late')}', stats.i('late') > 0 ? c.ci.danger : null),
                ('مراجعة', '${stats.i('review')}', c.ci.attn),
                ('خلصت', '${stats.i('done')}', c.ci.brand),
              ]),
              if (manager) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _chip(c, 'mine', 'مهامي'),
                    _chip(c, 'all', 'كل الفريق'),
                    for (final u in d.l('team')) _chip(c, '${u.i('id')}', u.s('name'), count: u.i('open')),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              _Segments(
                value: col,
                items: [for (final k in _cols) (k, lbl(taskStatus, k), cols.l(k).length)],
                onChanged: (v) => setState(() => col = v),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                EmptyState(col == 'done' ? 'لسه مفيش مهام خلصت' : 'مفيش مهام هنا', body: col == 'todo' ? 'كل حاجة اتبدأت.' : null)
              else
                for (final t in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: TaskTile(t, showAssignee: who != 'mine')),
              if (d.l('queue').isNotEmpty) ...[
                SectionTitle('مستنية توزيع', count: d.l('queue').length),
                for (final t in d.l('queue')) Padding(padding: const EdgeInsets.only(bottom: 10), child: TaskTile(t)),
              ],
            ]);
          },
        ),
      );

  Widget _chip(BuildContext c, String v, String text, {int? count}) {
    final on = who == v;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: CiChip(
        selected: on,
        label: count == null ? text : '$text  $count',
        onSelected: (_) {
          setState(() => who = v);
          _key.currentState?.reload();
        },
      ),
    );
  }
}

/// Segmented tabs in the brand's style: a mint underline on the active one.
class _Segments extends StatelessWidget {
  const _Segments({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<(String, String, int)> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.ci.line)),
        child: Row(children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: it.$1 == value ? context.ci.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: it.$1 == value ? context.ci.line : Colors.transparent),
                  ),
                  child: Column(children: [
                    Text('${it.$3}', style: numStyle(context, size: 15, color: it.$1 == value ? context.ci.brand : context.ci.muted)),
                    const SizedBox(height: 1),
                    Text(it.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.labelSmall!.copyWith(color: it.$1 == value ? context.ci.ink : context.ci.subtle)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

const _moveLabels = {'start': 'ابدأ فيها', 'submit': 'سلّمها للمراجعة', 'approve': 'اعتمدها', 'return': 'رجّعها للتعديل', 'back': 'رجّعها شغال', 'reopen': 'افتحها تاني'};

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key, required this.id});
  final int id;

  /// Same moves the web task page offers: (to, label, primary, note).
  List<(String, String, bool, bool)> _moves(Obj t) {
    final s = t.s('status'), mine = t.b('is_mine'), mgr = t.b('can_manage');
    return [
      if (s == 'todo' && (mine || mgr)) ('doing', 'start', true, false),
      if (s == 'doing' && (mine || mgr)) ('review', 'submit', true, true),
      if (s == 'review' && mgr) ('done', 'approve', true, true),
      if (s == 'review' && mgr) ('doing', 'return', false, true),
      if (s == 'review' && !mgr && mine) ('doing', 'back', false, false),
      if (s == 'done' && mgr) ('doing', 'reopen', false, true),
    ];
  }

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'مهمة',
        eyebrow: 'task #$id',
        actions: [if (Session.I.can('task_edit')) IconButton(tooltip: 'تعديل', onPressed: () => editThen(context, '/tasks/$id/edit', '/tasks/$id'), icon: const CiIcon('edit', size: 20))],
        body: Loader(
          load: () => Api.I.get('tasks/$id'),
          builder: (c, r, reload) {
            final t = r.o('data');
            final due = t.t('due_date');
            final order = {'todo': 0, 'doing': 1, 'review': 2, 'done': 3};
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 8, runSpacing: 6, children: [
                Pill(lbl(taskStatus, t.s('status')), tone: taskTone(t.s('status'))),
                if (t.s('priority') != 'normal') Pill(lbl(taskPriority, t.s('priority')), tone: priorityTone(t.s('priority'))),
                if (t.b('late')) const Pill('متأخرة', tone: Tone.danger),
              ]),
              const SizedBox(height: 12),
              Text(t.s('title'), style: c.tt.headlineSmall),
              const SizedBox(height: 16),
              StageTrack(total: 4, done: (order[t.s('status')] ?? 0) + 1),
              const SizedBox(height: 6),
              Row(children: [for (final k in order.keys) Expanded(child: Text(lbl(taskStatus, k), textAlign: TextAlign.center, style: c.tt.labelSmall!.copyWith(color: k == t.s('status') ? c.ci.brand : null)))]),
              const SizedBox(height: 16),
              for (final m in _moves(t))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: (m.$3 ? FilledButton.new : OutlinedButton.new)(
                    onPressed: () async {
                      String? note;
                      if (m.$4) {
                        note = await askText(c, _moveLabels[m.$2]!, hint: 'ملاحظة (اختياري)', required: false, action: _moveLabels[m.$2]!);
                        if (note == null) return;
                      }
                      if (!c.mounted) return;
                      final ok = await doAction(c, () => Api.I.post('tasks/$id/status', {'status': m.$1, if (note != null && note.isNotEmpty) 'note': note}));
                      if (ok != null) reload();
                    },
                    child: Text(_moveLabels[m.$2]!),
                  ),
                ),
              const SizedBox(height: 8),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  KV('المسؤول', t.ref('assignee', '—')),
                  if (t.has('assignee_title')) KV('الدور', t.s('assignee_title')),
                  if (t.has('department')) KV('القسم', t.s('department')),
                  KV('التسليم', due == null ? '—' : '${f.dateLong(due)} · ${f.time(due)}', monoValue: true),
                  if (t.has('project')) KV('المشروع', t.ref('project'), onTap: () => c.push('/projects/${t.refId('project')}')),
                  KV('أنشأها', t.ref('creator', '—')),
                  if (t.has('link')) KV('لينك', t.s('link'), onTap: () => openUrl(t.s('link'))),
                ]),
              ),
              if (t.s('description').isNotEmpty) ...[
                const SectionTitle('التفاصيل'),
                Panel(child: SelectableText(t.s('description'), style: c.tt.bodyMedium!.copyWith(height: 1.7))),
              ],
              SectionTitle('الملفات', count: t.l('files').length, action: 'ارفع', onAction: () => _upload(c, t, reload)),
              if (t.l('files').isEmpty && t.l('project_files').isEmpty)
                Text('مفيش ملفات.', style: c.tt.bodySmall)
              else
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: [for (final x in [...t.l('files'), ...t.l('project_files')]) FileRow(x)]),
                ),
              SectionTitle('اللي حصل', action: 'علّق', onAction: () async {
                final body = await askText(c, 'تعليق على المهمة', hint: 'اكتب تعليقك');
                if (body == null || !c.mounted) return;
                if (await doAction(c, () => Api.I.post('tasks/$id/comment', {'body': body})) != null) reload();
              }),
              _Timeline(t.l('updates')),
            ]);
          },
        ),
      );

  Future<void> _upload(BuildContext c, Obj t, Future<void> Function() reload) async {
    if (kDemo) return toast(c, 'رفع الملفات مقفول في النسخة التجريبية.');
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !c.mounted) return;
    final max = t.i('max_file_mb', 20) * 1024 * 1024;
    for (final x in files) {
      if (await x.xFile.length() > max) {
        if (c.mounted) toast(c, 'أقصى حجم للملف ${t.i('max_file_mb', 20)} ميجا.', error: true);
        return;
      }
    }
    final form = FormData();
    for (final x in files) {
      if (x.path != null) form.files.add(MapEntry('files[]', await MultipartFile.fromFile(x.path!, filename: x.name)));
    }
    if (!c.mounted) return;
    if (await doAction(c, () => Api.I.post('tasks/$id/files', form), success: 'الملفات اترفعت.') != null) reload();
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.items);
  final List<Obj> items;
  String _line(Obj u) => switch (u.s('type')) {
        'created' => 'أنشأ المهمة',
        'status' => 'غيّر الحالة من ${lbl(taskStatus, u.o('meta').s('from', 'todo'))} لـ ${lbl(taskStatus, u.o('meta').s('to', 'todo'))}',
        'comment' => 'علّق',
        'file' => 'رفع ملفات',
        'edited' => 'عدّل المهمة',
        _ => u.s('type'),
      };
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text('لسه مفيش تحديثات.', style: context.tt.bodySmall);
    return Column(children: [
      for (var i = items.length - 1; i >= 0; i--)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), color: i == items.length - 1 ? context.ci.brand : context.ci.control),
              if (i > 0) Expanded(child: Container(width: 1, color: context.ci.line)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: items[i].ref('user', 'النظام'), style: context.tt.titleSmall),
                    TextSpan(text: '  ${_line(items[i])}', style: context.tt.bodySmall),
                  ])),
                  if (items[i].s('body').isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.ci.line)),
                      child: Text(items[i].s('body'), style: context.tt.bodyMedium),
                    ),
                  const SizedBox(height: 4),
                  Text(f.ago(items[i].t('created_at')), style: mono(context, size: 10.5)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class NewTaskScreen extends StatefulWidget {
  const NewTaskScreen({super.key, this.projectId, this.taskId});
  final int? projectId;
  /// Set when editing an existing task.
  final int? taskId;
  @override
  State<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends State<NewTaskScreen> {
  final title = TextEditingController(), desc = TextEditingController(), link = TextEditingController();
  String priority = 'normal';
  int? assignee, group, project;
  DateTime due = DateTime.now().add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 17, minute: 0);
  Obj? meta;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    project = widget.projectId;
    Api.I.get('tasks', {'who': 'all'}).then((r) => mounted ? setState(() => meta = r) : null).catchError((_) => null);
    if (widget.taskId != null) {
      Api.I.get('tasks/${widget.taskId}/form').then((r) {
        final t = r.o('data');
        if (!mounted) return;
        setState(() {
          title.text = t.s('title');
          desc.text = t.s('description');
          link.text = t.s('link');
          priority = t.s('priority', 'normal');
          assignee = t.i('assignee_id') == 0 ? null : t.i('assignee_id');
          group = t.i('group_id') == 0 ? null : t.i('group_id');
          project = t.i('project_id') == 0 ? null : t.i('project_id');
          due = t.t('due_date') ?? due;
          final hm = t.s('due_time').split(':');
          if (hm.length == 2) time = TimeOfDay(hour: int.tryParse(hm[0]) ?? 17, minute: int.tryParse(hm[1]) ?? 0);
        });
      }).catchError((e) {
        if (mounted) toast(context, '$e', error: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = meta?.l('team') ?? const <Obj>[];
    final groups = meta?.l('groups') ?? const <Obj>[];
    String nameOf(List<Obj> l, int? id, String or) => l.where((x) => x.i('id') == id).firstOrNull?.s('name') ?? or;
    return CiPage(
      title: widget.taskId == null ? 'مهمة جديدة' : 'تعديل المهمة',
      eyebrow: widget.taskId == null ? 'tasks.new' : 'task #${widget.taskId}',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        FieldLabel('العنوان', child: TextField(controller: title, autofocus: true, decoration: const InputDecoration(hintText: 'مثلاً: تصميم صفحة الدفع'))),
        FieldLabel('التفاصيل', child: TextField(controller: desc, minLines: 3, maxLines: 8, decoration: const InputDecoration(hintText: 'المطلوب بالظبط'))),
        if (team.isNotEmpty)
          FieldLabel('مين هيعملها', child: PickBox(
            icon: 'users',
            text: nameOf(team, assignee, 'أنا'),
            placeholder: assignee == null,
            onTap: () async {
              final v = await pickOne(context, 'مين هيعملها', {'0': 'أنا', for (final u in team) '${u.i('id')}': '${u.s('name')}${u.has('title') ? ' · ${u.s('title')}' : ''}'}, current: '${assignee ?? 0}');
              if (v != null) setState(() => assignee = v == '0' ? null : int.parse(v));
            },
          )),
        if (groups.isNotEmpty)
          FieldLabel('القسم', child: PickBox(
            icon: 'folder',
            text: nameOf(groups, group, 'حسب الشخص'),
            placeholder: group == null,
            onTap: () async {
              final v = await pickOne(context, 'القسم', {'0': 'حسب الشخص', for (final g in groups) '${g.i('id')}': g.s('name')}, current: '${group ?? 0}');
              if (v != null) setState(() => group = v == '0' ? null : int.parse(v));
            },
          )),
        FieldLabel('الأهمية', child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final e in taskPriority.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {priority},
          onSelectionChanged: (s) => setState(() => priority = s.first),
        )),
        Row(children: [
          Expanded(child: FieldLabel('التسليم', child: PickBox(text: f.dateShort(due), onTap: () async {
            final d = await pickDate(context, initial: due, first: DateTime.now().subtract(const Duration(days: 1)));
            if (d != null) setState(() => due = d);
          }))),
          const SizedBox(width: 12),
          Expanded(child: FieldLabel('الساعة', child: PickBox(icon: 'clock', text: '${f.two(time.hour)}:${f.two(time.minute)}', onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) setState(() => time = t);
          }))),
        ]),
        FieldLabel('لينك (اختياري)', child: TextField(controller: link, keyboardType: TextInputType.url, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'https://'))),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: busy ? null : _save,
          child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.taskId == null ? 'أضف المهمة' : 'احفظ التعديلات'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return toast(context, 'اكتب عنوان المهمة.', error: true);
    setState(() => busy = true);
    final body = {
          'title': title.text.trim(),
          'description': desc.text.trim(),
          'link': link.text.trim(),
          'priority': priority,
          'assignee_id': assignee ?? Session.I.me?.i('id'),
          'group_id': group,
          'project_id': project,
          'due_date': f.ymd(due),
          'due_time': '${f.two(time.hour)}:${f.two(time.minute)}',
        };
    final r = await doAction(context, () => widget.taskId == null ? Api.I.post('tasks', body) : Api.I.put('tasks/${widget.taskId}', body));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) context.pop(true);
  }
}

/* ================================================================== projects */

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'المشاريع',
        eyebrow: 'projects',
        fab: !Session.I.can('project_create') ? null : FloatingActionButton(onPressed: () => context.push('/projects/new').then((_) => _projectsKey.currentState?.refresh()), child: const CiIcon('plus', size: 22)),
        body: PagedList(
          key: _projectsKey,
          path: 'projects',
          searchHint: 'دوّر باسم المشروع أو الكود',
          empty: 'مفيش مشاريع لسه',
          emptyIcon: 'folder',
          item: (c, p) => _ProjectCard(p),
        ),
      );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.p);
  final Obj p;
  @override
  Widget build(BuildContext context) {
    final stages = projectStage.keys.toList();
    final idx = stages.indexOf(p.s('stage'));
    return Panel(
      onTap: () => context.push('/projects/${p.i('id')}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: context.ci.brandSoft, borderRadius: BorderRadius.circular(4)),
            child: Text(p.s('code'), style: mono(context, size: 11, color: context.ci.brand, w: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(p.s('name'), style: context.tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (p.s('priority') != 'normal') Pill(lbl({...taskPriority, ...ticketPriority}, p.s('priority')), tone: priorityTone(p.s('priority')), dense: true),
        ]),
        const SizedBox(height: 6),
        Text([if (p.has('client')) p.ref('client'), p.s('stage_label', lbl(projectStage, p.s('stage')))].join(' · '), style: context.tt.bodySmall),
        const SizedBox(height: 12),
        StageTrack(total: stages.length - 1, done: p.s('stage') == 'paused' ? 0 : idx + 1, color: p.s('stage') == 'paused' ? context.ci.warning : null),
        const SizedBox(height: 10),
        Row(children: [
          Text('${p.i('progress')}%', style: numStyle(context, size: 14, color: context.ci.brand)),
          const SizedBox(width: 6),
          Text('${p.i('tasks_done')}/${p.i('tasks_open') + p.i('tasks_done')} مهمة', style: context.tt.bodySmall),
          const Spacer(),
          if (p.has('due_date')) ...[CiIcon('calendar', size: 14, color: context.ci.subtle), const SizedBox(width: 4), Text(f.dateShort(p.t('due_date')), style: mono(context, size: 11))],
        ]),
      ]),
    );
  }
}

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'مشروع',
        eyebrow: 'project #$id',
        actions: [
          if (Session.I.can('project_edit')) IconButton(tooltip: 'تعديل', onPressed: () => editThen(context, '/projects/$id/edit', '/projects/$id'), icon: const CiIcon('edit', size: 20)),
          if (Session.I.can('ticket_create') || Session.I.can('invoice_create'))
          PopupMenuButton<String>(
            icon: const CiIcon('plus', size: 20),
            onSelected: (v) => context.push(v),
            itemBuilder: (c) => [
              if (Session.I.can('ticket_create')) PopupMenuItem(value: '/tickets/new?project=$id', child: const Text('تذكرة جديدة')),
              if (Session.I.can('invoice_create')) PopupMenuItem(value: '/invoices/new?project=$id', child: const Text('فاتورة جديدة')),
            ],
          ),
        ],
        body: Loader(
        load: () => Api.I.get('projects/$id'),
        builder: (c, r, reload) {
          final p = r.o('data');
          final stages = projectStage.keys.where((k) => k != 'paused').toList();
          final idx = stages.indexOf(p.s('stage'));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text(p.s('code'), style: mono(c, size: 12, color: c.ci.brand, w: FontWeight.w600)),
              const SizedBox(width: 8),
              Pill(p.s('stage_label', lbl(projectStage, p.s('stage'))), tone: p.s('stage') == 'live' ? Tone.success : Tone.brand),
            ]),
            const SizedBox(height: 8),
            Text(p.s('name'), style: c.tt.headlineSmall),
            if (p.has('client')) Padding(padding: const EdgeInsets.only(top: 4), child: Text(p.ref('client'), style: c.tt.bodyMedium!.copyWith(color: c.ci.muted))),
            const SizedBox(height: 18),
            StageTrack(total: stages.length, done: idx + 1),
            const SizedBox(height: 6),
            Row(children: [for (final s in stages) Expanded(child: Text(lbl(projectStage, s), textAlign: TextAlign.center, style: c.tt.labelSmall!.copyWith(fontSize: 10, color: s == p.s('stage') ? c.ci.brand : null)))]),
            const SizedBox(height: 16),
            KpiStrip([
              ('الإنجاز', '${p.i('progress')}%', c.ci.brand),
              ('مهام مفتوحة', '${p.i('tasks_open')}', null),
              if (p.d('value') > 0) ('القيمة', f.money(p.d('value'), short: true), null) else ('خلصت', '${p.i('tasks_done')}', null),
            ]),
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                KV('مدير المشروع', p.ref('manager', '—')),
                if (p.has('person')) KV('جهة الاتصال', p.ref('person'), onTap: () => c.push('/persons/${p.refId('person')}')),
                if (p.has('client')) KV('العميل', p.ref('client'), onTap: () => c.push('/organizations/${p.refId('client')}')),
                KV('البداية', f.dateShort(p.t('start_date')), monoValue: true),
                KV('التسليم', f.dateShort(p.t('due_date')), monoValue: true),
                if (p.has('next_step')) KV('الخطوة الجاية', '${p.s('next_step')}${p.has('next_date') ? ' · ${f.dateShort(p.t('next_date'))}' : ''}'),
              ]),
            ),
            if (p.l('members').isNotEmpty) ...[
              SectionTitle('الفريق', count: p.l('members').length),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in p.l('members'))
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
                    decoration: BoxDecoration(color: c.ci.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.ci.line)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Avatar(m.s('name'), size: 26), const SizedBox(width: 8), Text(m.s('name'), style: c.tt.labelMedium)]),
                  ),
              ]),
            ],
            if (p.s('description').isNotEmpty) ...[const SectionTitle('عن المشروع'), Panel(child: Text(p.s('description'), style: c.tt.bodyMedium!.copyWith(height: 1.7)))],
            SectionTitle('مهام الفريق', count: p.l('team_tasks').length, action: Session.I.can('task_create') ? 'مهمة جديدة' : null, onAction: () async {
              if (await c.push<bool>('/tasks/new?project=$id') == true) reload();
            }),
            if (p.l('team_tasks').isEmpty) Text('مفيش مهام لسه.', style: c.tt.bodySmall),
            for (final t in p.l('team_tasks')) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(t, showAssignee: true)),
            if (p.l('tasks').isNotEmpty) ...[
              SectionTitle('خطة المشروع', count: p.l('tasks').length),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(children: [for (final t in p.l('tasks')) _PlanRow(t, onChanged: reload)]),
              ),
            ],
            if (p.l('links').isNotEmpty) ...[
              const SectionTitle('لينكات'),
              for (final l in p.l('links'))
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => openUrl(l.s('url')),
                  child: Row(children: [
                    const CiIcon('api', size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.s('label', l.s('url')), style: c.tt.titleSmall, overflow: TextOverflow.ellipsis)),
                    Icon(Icons.open_in_new_rounded, size: 16, color: c.ci.subtle),
                  ]),
                ),
            ],
            if (p.l('deploys').isNotEmpty) ...[
              const SectionTitle('آخر عمليات النشر'),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(children: [
                  for (final d in p.l('deploys'))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Container(width: 8, height: 8, color: d.s('status') == 'ok' ? c.ci.success : (d.s('status') == 'failed' ? c.ci.danger : c.ci.warning)),
                        const SizedBox(width: 10),
                        Text(d.s('version'), style: mono(c, size: 12.5, color: c.ci.ink)),
                        const SizedBox(width: 8),
                        Text(d.s('env'), style: c.tt.bodySmall),
                        const Spacer(),
                        Text(f.ago(d.t('created_at')), style: mono(c, size: 10.5)),
                      ]),
                    ),
                ]),
              ),
            ],
          ]);
        },
      ),
      );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow(this.t, {required this.onChanged});
  final Obj t;
  final Future<void> Function() onChanged;
  @override
  Widget build(BuildContext context) {
    final done = t.s('status') == 'done';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final v = await pickOne(context, t.s('title'), taskStatus, current: t.s('status'));
        if (v == null || v == t.s('status') || !context.mounted) return;
        if (await doAction(context, () => Api.I.put('project-tasks/${t.i('id')}', {'status': v})) != null) onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: done ? context.ci.brand : null, borderRadius: BorderRadius.circular(4), border: Border.all(color: done ? context.ci.brand : context.ci.control, width: 1.5)),
            child: done ? Icon(Icons.check_rounded, size: 13, color: context.ci.onBrand) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(t.s('title'), style: context.tt.bodyMedium!.copyWith(decoration: done ? TextDecoration.lineThrough : null, color: done ? context.ci.subtle : null))),
          if (t.has('user')) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Avatar(t.ref('user'), size: 22)),
          if (t.has('due_date') && !done) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Text(f.dateShort(t.t('due_date')), style: mono(context, size: 11))),
        ]),
      ),
    );
  }
}

/* ================================================================== tickets */

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});
  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  String? status;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'تذاكر الدعم',
        eyebrow: 'support.tickets',
        actions: [IconButton(tooltip: 'باقات الدعم', onPressed: () => context.push('/support-packages'), icon: const CiIcon('clock', size: 20))],
        fab: !Session.I.can('ticket_create') ? null : FloatingActionButton(onPressed: () => context.push('/tickets/new').then((_) => _ticketsKey.currentState?.refresh()), child: const CiIcon('plus', size: 22)),
        body: PagedList(
          key: _ticketsKey,
          path: 'tickets',
          query: {'status': status},
          searchHint: 'رقم التذكرة أو الموضوع',
          empty: 'مفيش تذاكر هنا',
          emptyIcon: 'check',
          header: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 36,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final e in {null: 'الكل', ...ticketStatus}.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: CiChip(selected: status == e.key, label: e.value, onSelected: (_) => setState(() => status = e.key)),
                  ),
              ]),
            ),
          ),
          item: (c, t) => TicketTile(t),
        ),
      );
}

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.id});
  final int id;
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final _key = GlobalKey<LoaderState>();
  final reply = TextEditingController();
  bool internal = false, sending = false;

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'تذكرة',
        eyebrow: 'ticket #${widget.id}',
        bottom: null,
        body: Column(children: [
          Expanded(
            child: Loader(
              key: _key,
              load: () => Api.I.get('tickets/${widget.id}'),
              builder: (c, r, reload) {
                final t = r.o('data');
                final sla = t.j['sla_minutes'];
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text(t.s('number'), style: mono(c, size: 12, color: c.ci.brand, w: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Pill(lbl(ticketType, t.s('type')), dense: true),
                    const Spacer(),
                    if (sla is num) Text('SLA · ${f.left(sla.toInt())}', style: mono(c, size: 11, color: sla < 0 ? c.ci.danger : c.ci.attn)),
                  ]),
                  const SizedBox(height: 8),
                  Text(t.s('subject'), style: c.tt.headlineSmall),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _EditChip(label: 'الحالة', value: lbl(ticketStatus, t.s('status')), tone: ticketTone(t.s('status')), onTap: () => _edit(c, t, 'status', ticketStatus))),
                    const SizedBox(width: 8),
                    Expanded(child: _EditChip(label: 'الأولوية', value: lbl(ticketPriority, t.s('priority')), tone: priorityTone(t.s('priority')), onTap: () => _edit(c, t, 'priority', ticketPriority))),
                    const SizedBox(width: 8),
                    Expanded(child: _EditChip(label: 'المسؤول', value: t.ref('assignee', 'محدش'), onTap: () => _edit(c, t, 'user_id', {'': 'محدش', for (final u in t.l('users')) '${u.i('id')}': u.s('name')}))),
                  ]),
                  const SizedBox(height: 12),
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(children: [
                      if (t.has('client')) KV('العميل', t.ref('client'), onTap: () => c.push('/organizations/${t.refId('client')}')),
                      if (t.has('person')) KV('من', t.ref('person'), onTap: () => c.push('/persons/${t.refId('person')}')),
                      if (t.has('project')) KV('المشروع', t.ref('project'), onTap: () => c.push('/projects/${t.refId('project')}')),
                      KV('اتفتحت', f.dateTime(t.t('created_at')), monoValue: true),
                      if (t.has('first_response_at')) KV('أول رد', f.dateTime(t.t('first_response_at')), monoValue: true),
                      if (t.has('rating')) KV('تقييم العميل', '${'★' * t.i('rating')}${t.has('rating_comment') ? ' · ${t.s('rating_comment')}' : ''}'),
                    ]),
                  ),
                  SectionTitle('المحادثة', count: t.l('messages').length),
                  for (final m in t.l('messages')) _TicketMsg(m),
                  SectionTitle('الساعات', count: t.l('hours').length, action: 'سجّل ساعات', onAction: () => _hours(c)),
                  if (t.l('hours').isEmpty) Text('لسه مفيش ساعات متسجلة.', style: c.tt.bodySmall),
                  for (final h in t.l('hours'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(width: 44, child: Text('${h.s('hours')}س', style: numStyle(c, size: 14, color: c.ci.brand))),
                        Expanded(child: Text('${h.s('what')} · ${h.ref('user')}', style: c.tt.bodySmall)),
                        Text(f.dateShort(h.t('date')), style: mono(c, size: 11)),
                      ]),
                    ),
                ]);
              },
            ),
          ),
          _replyBar(context),
        ]),
      );

  Widget _replyBar(BuildContext c) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(color: c.ci.surface, border: Border(top: BorderSide(color: c.ci.line))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            GestureDetector(
              onTap: () => setState(() => internal = !internal),
              child: Row(children: [
                Icon(internal ? Icons.lock_rounded : Icons.lock_open_rounded, size: 15, color: internal ? c.ci.warning : c.ci.subtle),
                const SizedBox(width: 6),
                Text(internal ? 'ملاحظة داخلية (العميل مش هيشوفها)' : 'رد للعميل', style: c.tt.labelSmall!.copyWith(color: internal ? c.ci.warning : null)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: reply, minLines: 1, maxLines: 5, decoration: InputDecoration(hintText: internal ? 'ملاحظة للفريق' : 'اكتب ردك', isDense: true))),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : () => _send(c),
              icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const CiIcon('arrow', size: 20),
            ),
          ]),
        ]),
      );

  Future<void> _send(BuildContext c) async {
    if (reply.text.trim().isEmpty) return;
    setState(() => sending = true);
    final r = await doAction(c, () => Api.I.post('tickets/${widget.id}/reply', {'text': reply.text.trim(), 'internal': internal}), success: internal ? 'الملاحظة اتحفظت.' : 'الرد اتبعت للعميل.');
    if (!mounted) return;
    setState(() => sending = false);
    if (r != null) {
      reply.clear();
      _key.currentState?.reload();
    }
  }

  Future<void> _edit(BuildContext c, Obj t, String field, Map<String, String> options) async {
    final cur = field == 'user_id' ? '${t.refId('assignee') == 0 ? '' : t.refId('assignee')}' : t.s(field);
    final v = await pickOne(c, field == 'status' ? 'الحالة' : (field == 'priority' ? 'الأولوية' : 'المسؤول'), options, current: cur);
    if (v == null || v == cur || !c.mounted) return;
    final body = {
      'status': t.s('status'),
      'priority': t.s('priority'),
      'type': t.s('type', 'question'),
      'user_id': t.refId('assignee') == 0 ? null : t.refId('assignee'),
      'project_id': t.refId('project') == 0 ? null : t.refId('project'),
      'estimate': t.j['estimate'],
      field: field == 'user_id' ? (v.isEmpty ? null : int.parse(v)) : v,
    };
    if (await doAction(c, () => Api.I.put('tickets/${widget.id}', body)) != null) _key.currentState?.reload();
  }

  Future<void> _hours(BuildContext c) async {
    final h = TextEditingController(text: '1'), what = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: c,
      isScrollControlled: true,
      builder: (s) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(s).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('سجّل ساعات شغل', style: s.tt.titleMedium),
          const SizedBox(height: 12),
          FieldLabel('عدد الساعات', child: TextField(controller: h, keyboardType: const TextInputType.numberWithOptions(decimal: true), textDirection: TextDirection.ltr)),
          FieldLabel('عملت إيه', child: TextField(controller: what, autofocus: true)),
          FilledButton(onPressed: () => Navigator.pop(s, true), child: const Text('سجّل')),
        ]),
      ),
    );
    if (ok != true || !c.mounted) return;
    if (await doAction(c, () => Api.I.post('tickets/${widget.id}/hours', {'hours': h.text.trim(), 'what': what.text.trim(), 'date': f.ymd(DateTime.now())})) != null) {
      _key.currentState?.reload();
    }
  }
}

class _EditChip extends StatelessWidget {
  const _EditChip({required this.label, required this.value, required this.onTap, this.tone});
  final String label, value;
  final Tone? tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final col = tone == null ? context.ci.ink : toneColors(context, tone!).$1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(color: context.ci.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.ci.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.tt.labelSmall),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(child: Text(value, style: context.tt.titleSmall!.copyWith(color: col, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Icon(Icons.expand_more_rounded, size: 16, color: context.ci.subtle),
          ]),
        ]),
      ),
    );
  }
}

class _TicketMsg extends StatelessWidget {
  const _TicketMsg(this.m);
  final Obj m;
  @override
  Widget build(BuildContext context) {
    final client = m.b('from_client'), internal = m.b('internal');
    final bg = internal ? context.ci.warningSoft : (client ? context.ci.surface : context.ci.brandSoft);
    return Align(
      alignment: client ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .84),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: internal ? context.ci.warning.withValues(alpha: .4) : context.ci.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(m.s('author'), style: context.tt.labelMedium!.copyWith(color: client ? context.ci.info : context.ci.brand)),
            if (internal) ...[const SizedBox(width: 6), Text('داخلي', style: context.tt.labelSmall!.copyWith(color: context.ci.warning))],
            const SizedBox(width: 10),
            Text(f.ago(m.t('created_at')), style: mono(context, size: 10)),
          ]),
          const SizedBox(height: 6),
          SelectableText(m.s('body'), style: context.tt.bodyMedium!.copyWith(height: 1.6)),
          for (final x in m.l('files')) FileRow(x),
        ]),
      ),
    );
  }
}

/* ================================================================== invoices */

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String? status;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الفواتير',
        eyebrow: 'billing.invoices',
        fab: FloatingActionButton(onPressed: () => context.push('/invoices/new').then((_) => _invoicesKey.currentState?.refresh()), child: const CiIcon('plus', size: 22)),
        body: PagedList(
          key: _invoicesKey,
          path: 'invoices',
          query: {'status': status},
          searchHint: 'رقم الفاتورة أو العميل',
          empty: 'مفيش فواتير',
          emptyIcon: 'invoice',
          header: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 36,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final e in {null: 'الكل', ...invoiceStatus}.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: CiChip(selected: status == e.key, label: e.value, onSelected: (_) => setState(() => status = e.key)),
                  ),
              ]),
            ),
          ),
          item: (c, i) => Panel(
            onTap: () => c.push('/invoices/${i.i('id')}'),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.s('number'), style: mono(c, size: 12, color: c.ci.brand, w: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(i.ref('client', '—'), style: c.tt.titleSmall),
                  const SizedBox(height: 2),
                  Text('استحقاق ${f.dateShort(i.t('due_date'))}', style: c.tt.bodySmall),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(f.money(i.d('total')), style: numStyle(c, size: 16)),
                const SizedBox(height: 6),
                Pill(lbl(invoiceStatus, i.s('status')), tone: invoiceTone(i.s('status')), dense: true),
              ]),
            ]),
          ),
        ),
      );
}

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'فاتورة',
        eyebrow: 'invoice #$id',
        actions: [if (Session.I.can('invoice_edit')) IconButton(tooltip: 'تعديل', onPressed: () => editThen(context, '/invoices/$id/edit', '/invoices/$id'), icon: const CiIcon('edit', size: 20))],
        body: Loader(
          load: () => Api.I.get('invoices/$id'),
          builder: (c, r, reload) {
            final i = r.o('data');
            final total = i.d('total'), paid = i.d('paid');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(i.s('number'), style: mono(c, size: 13, color: c.ci.brand, w: FontWeight.w600)),
                    const Spacer(),
                    Pill(lbl(invoiceStatus, i.s('status')), tone: invoiceTone(i.s('status'))),
                  ]),
                  const SizedBox(height: 14),
                  Text(f.money(total), style: numStyle(c, size: 32)),
                  const SizedBox(height: 4),
                  Text(i.ref('client', '—'), style: c.tt.bodyMedium!.copyWith(color: c.ci.muted)),
                  const SizedBox(height: 16),
                  Bar(total <= 0 ? 0 : (paid / total).clamp(0, 1).toDouble()),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('اتدفع ${f.money(paid)}', style: c.tt.bodySmall!.copyWith(color: c.ci.success)),
                    const Spacer(),
                    Text('باقي ${f.money(i.d('remaining'))}', style: c.tt.bodySmall!.copyWith(color: i.d('remaining') > 0 ? c.ci.attn : null)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  if (i.has('project')) KV('المشروع', i.ref('project'), onTap: () => c.push('/projects/${i.refId('project')}')),
                  KV('تاريخ الإصدار', f.dateShort(i.t('issue_date')), monoValue: true),
                  KV('الاستحقاق', f.dateShort(i.t('due_date')), monoValue: true),
                  KV('قبل الضريبة', f.money(i.d('subtotal')), monoValue: true),
                  KV('ضريبة ${(i.d('vat_rate') * 100).round()}%', f.money(i.d('vat')), monoValue: true),
                ]),
              ),
              if (i.has('payment_reported_at'))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Panel(
                    color: c.ci.infoSoft,
                    border: c.ci.info.withValues(alpha: .4),
                    child: Text('العميل بلّغ إنه دفع ${f.ago(i.t('payment_reported_at'))}${i.has('payment_report_note') ? ': ${i.s('payment_report_note')}' : ''}', style: c.tt.bodyMedium),
                  ),
                ),
              if (i.l('items').isNotEmpty) ...[
                const SectionTitle('البنود'),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(children: [
                    for (final it in i.l('items'))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Expanded(child: Text(it.s('description', it.s('name')), style: c.tt.bodyMedium)),
                          Text('${it.s('qty', '1')} × ${f.group(it.d('price'))}', style: mono(c, size: 11.5)),
                        ]),
                      ),
                  ]),
                ),
              ],
              SectionTitle('الدفعات', count: i.l('payments').length, action: i.d('remaining') > 0 ? 'سجّل دفعة' : null, onAction: () => _pay(c, i, reload)),
              if (i.l('payments').isEmpty) Text('لسه مفيش دفعات.', style: c.tt.bodySmall),
              for (final p in i.l('payments'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Text(f.money(p.d('amount')), style: numStyle(c, size: 14, color: c.ci.success)),
                    const SizedBox(width: 10),
                    Expanded(child: Text([p.s('method'), if (p.has('reference')) p.s('reference')].join(' · '), style: c.tt.bodySmall)),
                    Text(f.dateShort(p.t('date')), style: mono(c, size: 11)),
                  ]),
                ),
              if (i.has('print_url')) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(onPressed: () => openUrl(i.s('print_url')), icon: const CiIcon('printer', size: 18), label: const Text('افتح للطباعة')),
              ],
            ]);
          },
        ),
      );

  Future<void> _pay(BuildContext c, Obj inv, Future<void> Function() reload) async {
    final amount = TextEditingController(text: inv.d('remaining').toStringAsFixed(0)), ref = TextEditingController();
    String method = 'تحويل بنكي';
    final ok = await showModalBottomSheet<bool>(
      context: c,
      isScrollControlled: true,
      builder: (s) => StatefulBuilder(
        builder: (s, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(s).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('سجّل دفعة', style: s.tt.titleMedium),
            const SizedBox(height: 12),
            FieldLabel('المبلغ', child: TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), textDirection: TextDirection.ltr)),
            FieldLabel('طريقة الدفع', child: Wrap(spacing: 8, children: [
              for (final m in ['تحويل بنكي', 'إنستاباي', 'فودافون كاش', 'كاش', 'شيك'])
                CiChip(selected: method == m, label: m, onSelected: (_) => set(() => method = m)),
            ])),
            FieldLabel('رقم مرجعي (اختياري)', child: TextField(controller: ref, textDirection: TextDirection.ltr)),
            FilledButton(onPressed: () => Navigator.pop(s, true), child: const Text('سجّل الدفعة')),
          ]),
        ),
      ),
    );
    if (ok != true || !c.mounted) return;
    if (await doAction(c, () => Api.I.post('invoices/$id/payments', {'amount': amount.text.trim(), 'method': method, 'reference': ref.text.trim(), 'date': f.ymd(DateTime.now())})) != null) reload();
  }
}
