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

/// Create / edit screens. Each save goes to the CRM's own web form action (same rules as the web),
/// then the app opens what was made.

/* ------------------------------------------------------------------ shared */

/// Choices for the pickers (people, companies, projects, sources ...), loaded once per screen.
Future<Obj> formOptions() async => (await Api.I.get('forms/options')).o('data');

/// A long list with a search box (companies, contacts, projects). Returns the id, 0 for "none".
Future<int?> pickSearch(BuildContext context, String title, List<Obj> items, {int? current, String? none, String Function(Obj)? label}) {
  String name(Obj o) => label?.call(o) ?? o.s('name');
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (c) {
      var q = '';
      return StatefulBuilder(builder: (c, set) {
        final shown = items.where((o) => q.isEmpty || name(o).toLowerCase().contains(q.toLowerCase())).take(200).toList();
        return SizedBox(
          height: MediaQuery.of(c).size.height * .78,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: c.tt.titleMedium),
              const SizedBox(height: 10),
              TextField(
                autofocus: items.length > 8,
                onChanged: (v) => set(() => q = v.trim()),
                decoration: const InputDecoration(hintText: 'دوّر بالاسم', prefixIcon: Padding(padding: EdgeInsets.all(12), child: CiIcon('search', size: 18))),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(children: [
                  if (none != null) _PickRow(text: none, on: current == null || current == 0, onTap: () => Navigator.pop(c, 0)),
                  for (final o in shown) _PickRow(text: name(o), on: o.i('id') == current, onTap: () => Navigator.pop(c, o.i('id'))),
                  if (shown.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('مفيش نتيجة', textAlign: TextAlign.center, style: c.tt.bodyMedium!.copyWith(color: c.ci.muted))),
                ]),
              ),
            ]),
          ),
        );
      });
    },
  );
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.text, required this.on, required this.onTap});
  final String text;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: on ? context.ci.brandSoft : context.ci.sunken,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                Expanded(child: Text(text, style: context.tt.titleSmall!.copyWith(color: on ? context.ci.brand : null))),
                if (on) Icon(Icons.check_rounded, size: 18, color: context.ci.brand),
              ]),
            ),
          ),
        ),
      );
}

String _nameOf(List<Obj> l, int? id, String or) => l.where((x) => x.i('id') == id).firstOrNull?.s('name') ?? or;

/// A picker row for an id from a list.
Widget idPicker(BuildContext context, {required String label, required List<Obj> items, required int? value, required ValueChanged<int?> onChanged, String icon = 'users', String? none, String placeholder = 'اختار', String Function(Obj)? itemLabel}) =>
    FieldLabel(label, child: PickBox(
      icon: icon,
      text: value == null || value == 0 ? (none ?? placeholder) : (itemLabel != null ? itemLabel(items.firstWhere((x) => x.i('id') == value, orElse: () => const Obj({}))) : _nameOf(items, value, placeholder)),
      placeholder: value == null || value == 0,
      onTap: () async {
        final v = await pickSearch(context, label, items, current: value, none: none, label: itemLabel);
        if (v != null) onChanged(v == 0 ? null : v);
      },
    ));

/// A picker row for one of a few fixed values.
Widget choicePicker(BuildContext context, {required String label, required Map<String, String> options, required String value, required ValueChanged<String> onChanged, String icon = 'folder'}) =>
    FieldLabel(label, child: PickBox(
      icon: icon,
      text: options[value] ?? value,
      onTap: () async {
        final v = await pickOne(context, label, options, current: value);
        if (v != null) onChanged(v);
      },
    ));

Widget datePicker(BuildContext context, {required String label, required DateTime? value, required ValueChanged<DateTime?> onChanged, bool clearable = true}) =>
    FieldLabel(label, child: PickBox(
      text: value == null ? 'من غير تاريخ' : f.dateShort(value),
      placeholder: value == null,
      onTap: () async {
        final d = await pickDate(context, initial: value, first: DateTime.now().subtract(const Duration(days: 730)), last: DateTime.now().add(const Duration(days: 1095)));
        if (d != null) {
          onChanged(d);
        } else if (clearable && value != null && context.mounted && await confirm(context, 'تشيل التاريخ؟')) {
          onChanged(null);
        }
      },
    ));

Widget saveButton({required bool busy, required VoidCallback onPressed, required String text}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(text),
      ),
    );

/// The usual body of a form screen: wait for the options, then the fields.
class _FormBody extends StatelessWidget {
  const _FormBody({required this.ready, required this.children});
  final bool ready;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ready
      ? ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: children)
      : const Center(child: CircularProgressIndicator(strokeWidth: 2));
}

mixin _Saving<T extends StatefulWidget> on State<T> {
  bool busy = false;
  Obj? opt;
  String? loadError;

  Future<void> loadOptions([Future<void> Function()? more]) async {
    try {
      final o = await formOptions();
      if (more != null) await more();
      if (mounted) setState(() => opt = o);
    } on ApiError catch (e) {
      if (mounted) setState(() => loadError = e.message);
    }
  }

  /// Save, then open the new record (or go back with true).
  Future<void> save(Future<Obj> Function() call, {String? open}) async {
    setState(() => busy = true);
    final r = await doAction(context, call);
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) return;
    final id = r.o('data').i('id');
    if (open != null && id > 0) {
      context.pushReplacement('$open/$id');
    } else {
      context.pop(true);
    }
  }

  Widget errorOr(Widget w) => loadError == null ? w : EmptyState(loadError!, icon: 'warn');
}

/* ------------------------------------------------------------------ contacts */

class NewPersonScreen extends StatefulWidget {
  const NewPersonScreen({super.key, this.organizationId});
  final int? organizationId;
  @override
  State<NewPersonScreen> createState() => _NewPersonScreenState();
}

class _NewPersonScreenState extends State<NewPersonScreen> with _Saving {
  final name = TextEditingController(), mail = TextEditingController(), phone = TextEditingController(), job = TextEditingController();
  int? org;

  @override
  void initState() {
    super.initState();
    org = widget.organizationId;
    loadOptions();
  }

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'جهة اتصال جديدة',
        eyebrow: 'persons.new',
        body: errorOr(_FormBody(ready: opt != null, children: [
          FieldLabel('الاسم', child: TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words)),
          FieldLabel('الإيميل', child: TextField(controller: mail, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr)),
          FieldLabel('الموبايل', child: TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr)),
          FieldLabel('الوظيفة (اختياري)', child: TextField(controller: job)),
          idPicker(context, label: 'الشركة', items: opt?.l('organizations') ?? const [], value: org, none: 'من غير شركة', icon: 'database', onChanged: (v) => setState(() => org = v)),
          saveButton(busy: busy, text: 'أضف جهة الاتصال', onPressed: () {
            if (name.text.trim().isEmpty || mail.text.trim().isEmpty) return toast(context, 'الاسم والإيميل مطلوبين.', error: true);
            save(() => Api.I.post('persons', {'name': name.text.trim(), 'email': mail.text.trim(), 'phone': phone.text.trim(), 'job_title': job.text.trim(), 'organization_id': org}), open: '/persons');
          }),
        ])),
      );
}

class NewOrganizationScreen extends StatefulWidget {
  const NewOrganizationScreen({super.key});
  @override
  State<NewOrganizationScreen> createState() => _NewOrganizationScreenState();
}

class _NewOrganizationScreenState extends State<NewOrganizationScreen> with _Saving {
  final name = TextEditingController(), address = TextEditingController(), city = TextEditingController();

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'شركة جديدة',
        eyebrow: 'organizations.new',
        body: _FormBody(ready: true, children: [
          FieldLabel('اسم الشركة', child: TextField(controller: name, autofocus: true)),
          FieldLabel('العنوان (اختياري)', child: TextField(controller: address, minLines: 1, maxLines: 3)),
          FieldLabel('المدينة (اختياري)', child: TextField(controller: city)),
          saveButton(busy: busy, text: 'أضف الشركة', onPressed: () {
            if (name.text.trim().isEmpty) return toast(context, 'اكتب اسم الشركة.', error: true);
            save(() => Api.I.post('organizations', {'name': name.text.trim(), 'address': address.text.trim(), 'city': city.text.trim()}), open: '/organizations');
          }),
        ]),
      );
}

/* ------------------------------------------------------------------ leads */

class NewLeadScreen extends StatefulWidget {
  const NewLeadScreen({super.key, this.personId});
  final int? personId;
  @override
  State<NewLeadScreen> createState() => _NewLeadScreenState();
}

class _NewLeadScreenState extends State<NewLeadScreen> with _Saving {
  final title = TextEditingController(), value = TextEditingController(), desc = TextEditingController();
  final pName = TextEditingController(), pMail = TextEditingController(), pPhone = TextEditingController();
  int? person, source, type, stage, owner, org;
  bool newPerson = false;
  DateTime? close;

  @override
  void initState() {
    super.initState();
    person = widget.personId;
    loadOptions().then((_) {
      final o = opt;
      if (o == null) return;
      setState(() {
        source = o.l('lead_sources').firstOrNull?.i('id');
        type = o.l('lead_types').firstOrNull?.i('id');
        stage = o.l('pipelines').firstOrNull?.l('stages').firstOrNull?.i('id');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = opt ?? const Obj({});
    final stages = [for (final p in o.l('pipelines')) for (final s in p.l('stages')) Obj({'id': s.i('id'), 'name': o.l('pipelines').length > 1 ? '${p.s('name')} · ${stageNameAr(s)}' : stageNameAr(s)})];
    return CiPage(
      title: 'عميل محتمل جديد',
      eyebrow: 'leads.new',
      body: errorOr(_FormBody(ready: opt != null, children: [
        FieldLabel('العنوان', child: TextField(controller: title, autofocus: true, decoration: const InputDecoration(hintText: 'مثلاً: موقع لشركة النيل'))),
        FieldLabel('القيمة المتوقعة (ج.م)', child: TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), textDirection: TextDirection.ltr)),
        FieldLabel('جهة الاتصال', child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: false, label: Text('موجودة')), ButtonSegment(value: true, label: Text('جديدة'))],
          selected: {newPerson},
          onSelectionChanged: (s) => setState(() => newPerson = s.first),
        )),
        if (!newPerson)
          idPicker(context, label: 'اختار جهة الاتصال', items: o.l('persons'), value: person, onChanged: (v) => setState(() => person = v))
        else ...[
          FieldLabel('الاسم', child: TextField(controller: pName)),
          FieldLabel('الإيميل', child: TextField(controller: pMail, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr)),
          FieldLabel('الموبايل', child: TextField(controller: pPhone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr)),
          idPicker(context, label: 'الشركة', items: o.l('organizations'), value: org, none: 'من غير شركة', icon: 'database', onChanged: (v) => setState(() => org = v)),
        ],
        idPicker(context, label: 'المرحلة', items: stages, value: stage, icon: 'folder', onChanged: (v) => setState(() => stage = v)),
        Row(children: [
          Expanded(child: idPicker(context, label: 'المصدر', items: o.l('lead_sources'), value: source, icon: 'folder', onChanged: (v) => setState(() => source = v))),
          const SizedBox(width: 12),
          Expanded(child: idPicker(context, label: 'النوع', items: o.l('lead_types'), value: type, icon: 'folder', onChanged: (v) => setState(() => type = v))),
        ]),
        idPicker(context, label: 'المسؤول', items: o.l('users'), value: owner, none: 'أنا', onChanged: (v) => setState(() => owner = v)),
        datePicker(context, label: 'تاريخ الإغلاق المتوقع', value: close, onChanged: (d) => setState(() => close = d)),
        FieldLabel('تفاصيل (اختياري)', child: TextField(controller: desc, minLines: 2, maxLines: 6)),
        saveButton(busy: busy, text: 'أضف العميل المحتمل', onPressed: _save),
      ])),
    );
  }

  void _save() {
    if (title.text.trim().isEmpty) return toast(context, 'اكتب عنوان.', error: true);
    if (!newPerson && person == null) return toast(context, 'اختار جهة الاتصال.', error: true);
    if (newPerson && (pName.text.trim().isEmpty || pMail.text.trim().isEmpty)) return toast(context, 'اكتب اسم وإيميل جهة الاتصال.', error: true);
    if (source == null || type == null) return toast(context, 'اختار المصدر والنوع.', error: true);
    save(() => Api.I.post('leads', {
          'title': title.text.trim(),
          'lead_value': double.tryParse(value.text.trim().replaceAll(',', '')) ?? 0,
          'description': desc.text.trim(),
          'lead_source_id': source,
          'lead_type_id': type,
          'lead_pipeline_stage_id': stage,
          'user_id': owner,
          'expected_close_date': close == null ? null : f.ymd(close!),
          if (!newPerson) 'person_id': person,
          if (newPerson) ...{'person_name': pName.text.trim(), 'person_email': pMail.text.trim(), 'person_phone': pPhone.text.trim(), 'organization_id': org},
        }), open: '/leads');
  }
}

/// Krayin stage codes in Arabic (custom stages keep their own name).
String stageNameAr(Obj s) => const {
      'new': 'جديد', 'follow-up': 'متابعة', 'prospect': 'مهتم', 'negotiation': 'تفاوض', 'won': 'اتكسب', 'lost': 'اتخسر',
    }[s.s('code')] ?? s.s('name');

/* ------------------------------------------------------------------ tickets */

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key, this.organizationId, this.projectId});
  final int? organizationId, projectId;
  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> with _Saving {
  final title = TextEditingController(), text = TextEditingController();
  int? org, person, project, owner;
  String type = 'bug', priority = 'normal';

  @override
  void initState() {
    super.initState();
    org = widget.organizationId;
    project = widget.projectId;
    loadOptions().then((_) {
      if (project != null && org == null) {
        setState(() => org = opt?.l('projects').where((p) => p.i('id') == project).firstOrNull?.i('organization_id'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = opt ?? const Obj({});
    final persons = o.l('persons').where((p) => org == null || p.i('organization_id') == org || p.i('organization_id') == 0).toList();
    final projects = o.l('projects').where((p) => org == null || p.i('organization_id') == org).toList();
    return CiPage(
      title: 'تذكرة جديدة',
      eyebrow: 'tickets.new',
      body: errorOr(_FormBody(ready: opt != null, children: [
        idPicker(context, label: 'العميل (الشركة)', items: o.l('organizations'), value: org, icon: 'database', onChanged: (v) => setState(() {
              org = v;
              person = null;
              if (project != null && !projects.any((p) => p.i('id') == project)) project = null;
            })),
        idPicker(context, label: 'من (جهة الاتصال)', items: persons, value: person, none: 'مش محدد', onChanged: (v) => setState(() => person = v)),
        idPicker(context, label: 'المشروع', items: projects, value: project, none: 'من غير مشروع', icon: 'folder', itemLabel: (p) => '${p.s('code')} · ${p.s('name')}', onChanged: (v) => setState(() => project = v)),
        FieldLabel('النوع', child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final e in ticketType.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {type},
          onSelectionChanged: (s) => setState(() => type = s.first),
        )),
        FieldLabel('الأولوية', child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final e in ticketPriority.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {priority},
          onSelectionChanged: (s) => setState(() => priority = s.first),
        )),
        idPicker(context, label: 'المسؤول', items: o.l('users'), value: owner, none: 'حسب التوزيع', onChanged: (v) => setState(() => owner = v)),
        FieldLabel('العنوان', child: TextField(controller: title)),
        FieldLabel('الوصف', child: TextField(controller: text, minLines: 4, maxLines: 10, decoration: const InputDecoration(hintText: 'إيه اللي حصل بالظبط'))),
        saveButton(busy: busy, text: 'افتح التذكرة', onPressed: () {
          if (org == null) return toast(context, 'اختار العميل.', error: true);
          if (title.text.trim().isEmpty || text.text.trim().isEmpty) return toast(context, 'اكتب العنوان والوصف.', error: true);
          save(() => Api.I.post('tickets', {
                'organization_id': org, 'person_id': person, 'project_id': project, 'user_id': owner,
                'type': type, 'priority': priority, 'title': title.text.trim(), 'text': text.text.trim(),
              }), open: '/tickets');
        }),
      ])),
    );
  }
}

/* ------------------------------------------------------------------ projects */

const projectType = {'web': 'موقع', 'mobile': 'تطبيق موبايل', 'system': 'نظام', 'api': 'API', 'cloud': 'سحابة', 'support': 'دعم فني'};

class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, this.id, this.organizationId});
  final int? id, organizationId;
  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> with _Saving {
  final name = TextEditingController(), desc = TextEditingController(), value = TextEditingController(), next = TextEditingController(), links = TextEditingController();
  int? org, person, manager;
  String type = 'web', priority = 'normal', stage = 'discovery';
  DateTime? start, due, launched, nextDate;
  List<int> members = [];
  String code = '';

  bool get editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    org = widget.organizationId;
    start = DateTime.now();
    loadOptions(editing ? _loadProject : null);
  }

  Future<void> _loadProject() async {
    final p = (await Api.I.get('projects/${widget.id}/form')).o('data');
    code = p.s('code');
    name.text = p.s('name');
    desc.text = p.s('description');
    value.text = p.d('value') > 0 ? p.d('value').toStringAsFixed(0) : '';
    next.text = p.s('next_step');
    links.text = p.s('links_text');
    org = p.i('organization_id');
    person = p.i('person_id') == 0 ? null : p.i('person_id');
    manager = p.i('user_id') == 0 ? null : p.i('user_id');
    type = p.s('type', 'web');
    priority = p.s('priority', 'normal');
    stage = p.s('stage', 'discovery');
    start = p.t('start_date');
    due = p.t('due_date');
    launched = p.t('launched_on');
    nextDate = p.t('next_date');
    members = p.ls('members').map(int.parse).toList();
  }

  @override
  Widget build(BuildContext context) {
    final o = opt ?? const Obj({});
    final users = o.l('users');
    final persons = o.l('persons').where((p) => org == null || p.i('organization_id') == org || p.i('organization_id') == 0).toList();
    return CiPage(
      title: editing ? 'تعديل المشروع' : 'مشروع جديد',
      eyebrow: editing ? code : 'projects.new',
      body: errorOr(_FormBody(ready: opt != null, children: [
        FieldLabel('اسم المشروع', child: TextField(controller: name)),
        idPicker(context, label: 'العميل (الشركة)', items: o.l('organizations'), value: org, icon: 'database', onChanged: (v) => setState(() {
              org = v;
              person = null;
            })),
        idPicker(context, label: 'جهة الاتصال', items: persons, value: person, none: 'مش محدد', onChanged: (v) => setState(() => person = v)),
        Row(children: [
          Expanded(child: choicePicker(context, label: 'النوع', options: projectType, value: type, onChanged: (v) => setState(() => type = v))),
          const SizedBox(width: 12),
          Expanded(child: choicePicker(context, label: 'المرحلة', options: projectStage, value: stage, onChanged: (v) => setState(() => stage = v))),
        ]),
        FieldLabel('الأولوية', child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final e in ticketPriority.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {priority},
          onSelectionChanged: (s) => setState(() => priority = s.first),
        )),
        idPicker(context, label: 'مدير المشروع', items: users, value: manager, none: 'مش محدد', onChanged: (v) => setState(() => manager = v)),
        FieldLabel('الفريق', child: PickBox(
          icon: 'users',
          text: members.isEmpty ? 'محدش لسه' : members.map((id) => _nameOf(users, id, '')).where((n) => n.isNotEmpty).join('، '),
          placeholder: members.isEmpty,
          onTap: () async {
            final v = await _pickMany(context, 'الفريق', users, members);
            if (v != null) setState(() => members = v);
          },
        )),
        FieldLabel('قيمة المشروع (ج.م)', child: TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), textDirection: TextDirection.ltr)),
        Row(children: [
          Expanded(child: datePicker(context, label: 'البداية', value: start, onChanged: (d) => setState(() => start = d))),
          const SizedBox(width: 12),
          Expanded(child: datePicker(context, label: 'التسليم', value: due, onChanged: (d) => setState(() => due = d))),
        ]),
        if (editing) datePicker(context, label: 'اتطلق يوم', value: launched, onChanged: (d) => setState(() => launched = d)),
        FieldLabel('الخطوة الجاية (اختياري)', child: TextField(controller: next)),
        datePicker(context, label: 'ميعاد الخطوة الجاية', value: nextDate, onChanged: (d) => setState(() => nextDate = d)),
        FieldLabel('الوصف (اختياري)', child: TextField(controller: desc, minLines: 2, maxLines: 8)),
        FieldLabel('لينكات (كل لينك في سطر: الاسم | الرابط)', child: TextField(controller: links, minLines: 2, maxLines: 6, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'Figma | https://figma.com/...'))),
        saveButton(busy: busy, text: editing ? 'احفظ التعديلات' : 'أضف المشروع', onPressed: _save),
      ])),
    );
  }

  void _save() {
    if (name.text.trim().isEmpty || org == null) return toast(context, 'اكتب اسم المشروع واختار العميل.', error: true);
    if (start != null && due != null && due!.isBefore(start!)) return toast(context, 'التسليم لازم يكون بعد البداية.', error: true);
    String? d(DateTime? x) => x == null ? null : f.ymd(x);
    final body = {
      'name': name.text.trim(), 'description': desc.text.trim(), 'organization_id': org, 'person_id': person, 'user_id': manager,
      'type': type, 'priority': priority, 'stage': stage, 'value': double.tryParse(value.text.trim().replaceAll(',', '')) ?? 0,
      'start_date': d(start), 'due_date': d(due), 'launched_on': d(launched), 'next_step': next.text.trim(), 'next_date': d(nextDate),
      'links_text': links.text.trim(), 'members': members,
    };
    if (editing) {
      save(() => Api.I.put('projects/${widget.id}', body));
    } else {
      save(() => Api.I.post('projects', body), open: '/projects');
    }
  }
}

Future<List<int>?> _pickMany(BuildContext context, String title, List<Obj> items, List<int> current) {
  final picked = {...current};
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SizedBox(
        height: MediaQuery.of(c).size.height * .7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: c.tt.titleMedium),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(children: [
                for (final u in items)
                  _PickRow(text: u.s('name'), on: picked.contains(u.i('id')), onTap: () => set(() => picked.contains(u.i('id')) ? picked.remove(u.i('id')) : picked.add(u.i('id')))),
              ]),
            ),
            FilledButton(onPressed: () => Navigator.pop(c, picked.toList()), child: Text('تمام (${picked.length})')),
          ]),
        ),
      ),
    ),
  );
}

/* ------------------------------------------------------------------ invoices */

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key, this.id, this.organizationId, this.projectId});
  final int? id, organizationId, projectId;
  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _Item {
  _Item({String d = '', String w = '', String a = ''})
      : desc = TextEditingController(text: d),
        weeks = TextEditingController(text: w),
        amount = TextEditingController(text: a);
  final TextEditingController desc, weeks, amount;
  double get value => double.tryParse(amount.text.trim().replaceAll(',', '')) ?? 0;
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> with _Saving {
  final notes = TextEditingController();
  int? org, project;
  DateTime issue = DateTime.now();
  DateTime? due = DateTime.now().add(const Duration(days: 7));
  bool vat = true;
  double vatRate = 0.14;
  String number = '';
  final items = <_Item>[_Item()];

  bool get editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    org = widget.organizationId;
    project = widget.projectId;
    loadOptions(editing ? _loadInvoice : null).then((_) {
      if (!editing && project != null && org == null) {
        setState(() => org = opt?.l('projects').where((p) => p.i('id') == project).firstOrNull?.i('organization_id'));
      }
    });
  }

  Future<void> _loadInvoice() async {
    final i = (await Api.I.get('invoices/${widget.id}/form')).o('data');
    number = i.s('number');
    org = i.i('organization_id');
    project = i.i('project_id') == 0 ? null : i.i('project_id');
    issue = i.t('issue_date') ?? DateTime.now();
    due = i.t('due_date');
    vatRate = i.d('vat_rate');
    vat = vatRate > 0;
    if (!vat) vatRate = 0.14;
    notes.text = i.s('notes');
    items
      ..clear()
      ..addAll(i.l('items').map((x) => _Item(d: x.s('description'), w: x.has('weeks') ? x.s('weeks') : '', a: x.d('amount').toStringAsFixed(x.d('amount') % 1 == 0 ? 0 : 2))));
    if (items.isEmpty) items.add(_Item());
  }

  @override
  Widget build(BuildContext context) {
    final o = opt ?? const Obj({});
    final projects = o.l('projects').where((p) => org == null || p.i('organization_id') == org).toList();
    final sub = items.fold<double>(0, (s, i) => s + i.value);
    final tax = vat ? sub * vatRate : 0.0;
    return CiPage(
      title: editing ? 'تعديل الفاتورة' : 'فاتورة جديدة',
      eyebrow: editing ? number : 'invoices.new',
      body: errorOr(_FormBody(ready: opt != null, children: [
        idPicker(context, label: 'العميل (الشركة)', items: o.l('organizations'), value: org, icon: 'database', onChanged: (v) => setState(() {
              org = v;
              if (project != null && !o.l('projects').any((p) => p.i('id') == project && p.i('organization_id') == v)) project = null;
            })),
        idPicker(context, label: 'المشروع', items: projects, value: project, none: 'من غير مشروع', icon: 'folder', itemLabel: (p) => '${p.s('code')} · ${p.s('name')}', onChanged: (v) => setState(() => project = v)),
        Row(children: [
          Expanded(child: datePicker(context, label: 'تاريخ الفاتورة', value: issue, clearable: false, onChanged: (d) => setState(() => issue = d ?? issue))),
          const SizedBox(width: 12),
          Expanded(child: datePicker(context, label: 'آخر ميعاد للدفع', value: due, onChanged: (d) => setState(() => due = d))),
        ]),
        Padding(padding: const EdgeInsets.only(bottom: 8, right: 2), child: Text('البنود', style: context.tt.labelMedium)),
        for (final (n, it) in items.indexed)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(children: [
              Row(children: [
                Text('#${n + 1}', style: mono(context, size: 11, color: context.ci.brand)),
                const Spacer(),
                if (items.length > 1) IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => items.removeAt(n)), icon: CiIcon('trash', size: 16, color: context.ci.subtle)),
              ]),
              TextField(controller: it.desc, decoration: const InputDecoration(hintText: 'الوصف، مثلاً: تصميم الموقع')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(flex: 2, child: TextField(controller: it.amount, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'المبلغ'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: it.weeks, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'أسابيع'))),
              ]),
            ]),
          )),
        Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: () => setState(() => items.add(_Item())), icon: const CiIcon('plus', size: 16), label: const Text('بند كمان'))),
        const SizedBox(height: 4),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: vat, onChanged: (v) => setState(() => vat = v), title: Text('ضريبة القيمة المضافة ${(vatRate * 100).round()}%', style: context.tt.titleSmall)),
        Padding(padding: const EdgeInsets.only(bottom: 16), child: Panel(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            KV('قبل الضريبة', f.money(sub)),
            if (vat) KV('الضريبة', f.money(tax)),
            KV('الإجمالي', f.money(sub + tax)),
          ]),
        )),
        FieldLabel('ملاحظات (اختياري)', child: TextField(controller: notes, minLines: 2, maxLines: 5)),
        saveButton(busy: busy, text: editing ? 'احفظ الفاتورة' : 'اعمل الفاتورة (مسودة)', onPressed: _save),
      ])),
    );
  }

  void _save() {
    if (org == null) return toast(context, 'اختار العميل.', error: true);
    final rows = items.where((i) => i.desc.text.trim().isNotEmpty && i.value > 0).toList();
    if (rows.isEmpty) return toast(context, 'اكتب بند واحد على الأقل بوصف ومبلغ.', error: true);
    if (due != null && due!.isBefore(DateTime(issue.year, issue.month, issue.day))) return toast(context, 'ميعاد الدفع لازم يكون بعد تاريخ الفاتورة.', error: true);
    final body = {
      'organization_id': org, 'project_id': project, 'issue_date': f.ymd(issue), 'due_date': due == null ? null : f.ymd(due!),
      'vat_rate': vat ? vatRate : 0, 'notes': notes.text.trim(),
      'items': [for (final i in rows) {'description': i.desc.text.trim(), 'weeks': double.tryParse(i.weeks.text.trim()), 'amount': i.value}],
    };
    if (editing) {
      save(() => Api.I.put('invoices/${widget.id}', body));
    } else {
      save(() => Api.I.post('invoices', body), open: '/invoices');
    }
  }
}

/* ------------------------------------------------------------------ support packages */

class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'باقات الدعم',
        eyebrow: 'support.packages',
        body: Loader(
          load: () => Api.I.get('support-packages'),
          builder: (c, d, reload) {
            final list = d.l('data');
            if (list.isEmpty) return const EmptyState('مفيش باقات دعم لسه', icon: 'clock');
            return Column(children: [for (final p in list) _PackageCard(p, reload)]);
          },
        ),
      );
}

class _PackageCard extends StatelessWidget {
  const _PackageCard(this.p, this.reload);
  final Obj p;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext context) {
    final used = p.d('used'), hours = p.d('hours');
    final ratio = hours > 0 ? (used / hours).clamp(0.0, 1.0) : 0.0;
    final ends = p.t('renew_on');
    final daysLeft = ends == null ? null : ends.difference(DateTime.now()).inDays;
    final hot = ratio >= .85 || (daysLeft != null && daysLeft <= 7);
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.ref('organization', '—'), style: context.tt.titleMedium)),
          Pill(p.b('is_active') ? 'شغالة' : 'متوقفة', tone: p.b('is_active') ? Tone.brand : Tone.muted),
        ]),
        const SizedBox(height: 2),
        Text([p.s('name'), if (p.has('project')) p.ref('project')].join(' · '), style: context.tt.bodySmall),
        const SizedBox(height: 12),
        Row(children: [
          Text('${_n(used)} / ${_n(hours)} ساعة', style: mono(context, size: 13, w: FontWeight.w600)),
          const Spacer(),
          Text(p.b('is_free') ? 'مجانية' : f.money(p.d('price')), style: mono(context, size: 12, color: context.ci.muted)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: context.ci.sunken, color: hot ? context.ci.warning : context.ci.brand),
        ),
        const SizedBox(height: 10),
        Text(
          '${f.dateShort(p.t('period_start'))} ← ${f.dateShort(ends)}${daysLeft != null && daysLeft >= 0 ? ' · باقي $daysLeft يوم' : daysLeft != null ? ' · خلصت' : ''}${p.d('daily_hours') > 0 ? ' · ${_n(p.d('daily_hours'))} ساعة/يوم' : ''}',
          style: context.tt.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(
            onPressed: () async {
              if (!await confirm(context, 'تجدد الباقة؟', body: 'هتبدأ فترة جديدة بنفس عدد الساعات.')) return;
              if (!context.mounted) return;
              if (await doAction(context, () => Api.I.post('support-packages/${p.i('id')}/renew')) != null) reload();
            },
            child: const Text('جدد'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              if (await doAction(context, () => Api.I.post('support-packages/${p.i('id')}/toggle')) != null) reload();
            },
            child: Text(p.b('is_active') ? 'وقّفها' : 'شغّلها'),
          ),
        ]),
      ]),
    ));
  }

  static String _n(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
