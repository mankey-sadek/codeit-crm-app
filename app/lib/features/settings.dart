import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/obj.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import 'forms.dart' show pickMany, saveButton;

/// CRM settings (the web's Settings menu): users, roles, groups, pipelines, lead sources and types, tags.
/// Every save runs the web's own action, so the same rules and checks apply.

const _sections = <String, (String icon, String title, String sub)>{
  'users': ('users', 'المستخدمين', 'مين يدخل الـ CRM، الدور والأقسام'),
  'roles': ('shield', 'الأدوار والصلاحيات', 'كل دور يقدر يفتح إيه'),
  'groups': ('staff', 'الأقسام (المجموعات)', 'تقسيم الفريق'),
  'pipelines': ('chart', 'مراحل البيع', 'الـ pipelines ومراحلها'),
  'sources': ('branch', 'مصادر العملاء', 'العميل جه منين'),
  'types': ('folder', 'أنواع الفرص', 'تصنيف الفرص'),
  'tags': ('check', 'الوسوم', 'علامات على الفرص'),
};

class CrmSettingsScreen extends StatelessWidget {
  const CrmSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'إعدادات النظام',
        eyebrow: 'settings',
        body: Loader(
          load: () => Api.I.get('settings'),
          builder: (c, d, reload) {
            final keys = d.ls('data');
            if (keys.isEmpty) return const EmptyState('مش مسموحلك تفتح الإعدادات', icon: 'lock');
            return Column(children: [
              for (final k in keys)
                if (_sections[k] case final s?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      onTap: () => c.push('/crm-settings/$k'),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.ci.brandSoft, borderRadius: BorderRadius.circular(9)),
                          child: CiIcon(s.$1, size: 19, color: c.ci.brand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.$2, style: c.tt.titleSmall),
                          Text(s.$3, style: c.tt.bodySmall),
                        ])),
                        Icon(Icons.chevron_left_rounded, color: c.ci.subtle),
                      ]),
                    ),
                  ),
            ]);
          },
        ),
      );
}

/// Opens the right screen for a settings key.
Widget settingsSection(String kind) => switch (kind) {
      'users' => const UsersSettingsScreen(),
      'roles' => const RolesSettingsScreen(),
      'pipelines' => const PipelinesSettingsScreen(),
      _ => SimpleSettingsScreen(kind: kind),
    };

Widget _row(BuildContext c, {required String title, String? sub, Widget? lead, Widget? trail, VoidCallback? onTap}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          if (lead != null) ...[lead, const SizedBox(width: 12)],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: c.tt.titleSmall),
            if (sub != null && sub.isNotEmpty) Text(sub, style: c.tt.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          ?trail,
        ]),
      ),
    );

Future<bool> _delete(BuildContext context, String what, String path) async {
  if (!await confirm(context, 'تمسح $what؟', body: 'مش هينفع ترجّعه.', yes: 'امسح', danger: true)) return false;
  if (!context.mounted) return false;
  return await doAction(context, () => Api.I.delete(path)) != null;
}

/* ------------------------------------------------------------------ groups, sources, types, tags */

class SimpleSettingsScreen extends StatefulWidget {
  const SimpleSettingsScreen({super.key, required this.kind});
  final String kind;
  @override
  State<SimpleSettingsScreen> createState() => _SimpleSettingsScreenState();
}

const _tagColors = ['#2BFF88', '#3DD9C1', '#4C9AFF', '#A06BFF', '#FF5C93', '#FF7A45', '#FFC53D', '#8C8C8C'];

Color _hex(String h) {
  final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
  return v == null ? const Color(0xFF8C8C8C) : Color(0xFF000000 | v);
}

class _SimpleSettingsScreenState extends State<SimpleSettingsScreen> {
  final _key = GlobalKey<LoaderState>();
  String get kind => widget.kind;
  String get title => _sections[kind]?.$2 ?? kind;

  @override
  Widget build(BuildContext context) => CiPage(
        title: title,
        eyebrow: 'settings.$kind',
        fab: FloatingActionButton(onPressed: () => _edit(null), child: const CiIcon('plus', size: 22)),
        body: Loader(
          key: _key,
          load: () => Api.I.get('settings/$kind'),
          builder: (c, d, reload) {
            final rows = d.l('data');
            if (rows.isEmpty) return const EmptyState('لسه مفيش حاجة هنا', icon: 'folder');
            return Column(children: [
              for (final r in rows)
                _row(
                  c,
                  title: r.s('name'),
                  sub: [
                    if (kind == 'groups' && r.s('description') != r.s('name')) r.s('description'),
                    if (kind == 'groups') '${r.i('count')} شخص' else '${r.i('count')} فرصة',
                  ].where((x) => x.isNotEmpty).join(' · '),
                  lead: kind == 'tags' ? Container(width: 14, height: 14, decoration: BoxDecoration(color: _hex(r.s('color')), borderRadius: BorderRadius.circular(3))) : null,
                  trail: IconButton(
                    onPressed: () async {
                      if (await _delete(c, r.s('name'), 'settings/$kind/${r.i('id')}')) reload();
                    },
                    icon: CiIcon('trash', size: 18, color: c.ci.subtle),
                  ),
                  onTap: () => _edit(r),
                ),
            ]);
          },
        ),
      );

  Future<void> _edit(Obj? r) async {
    final name = TextEditingController(text: r?.s('name') ?? ''), desc = TextEditingController(text: r?.s('description') ?? '');
    var color = r?.s('color', _tagColors.first) ?? _tagColors.first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r == null ? 'إضافة: $title' : 'تعديل: ${r.s('name')}', style: c.tt.titleMedium),
            const SizedBox(height: 12),
            FieldLabel('الاسم', child: TextField(controller: name, autofocus: true)),
            if (kind == 'groups') FieldLabel('الوصف', child: TextField(controller: desc)),
            if (kind == 'tags')
              FieldLabel('اللون', child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final h in _tagColors)
                  InkWell(
                    onTap: () => set(() => color = h),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: _hex(h), borderRadius: BorderRadius.circular(8), border: Border.all(color: color == h ? c.ci.ink : Colors.transparent, width: 2)),
                    ),
                  ),
              ])),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final body = {'name': name.text.trim(), if (kind == 'groups') 'description': desc.text.trim(), if (kind == 'tags') 'color': color};
                final res = await doAction(c, () => r == null ? Api.I.post('settings/$kind', body) : Api.I.put('settings/$kind/${r.i('id')}', body));
                if (res != null && c.mounted) Navigator.pop(c, true);
              },
              child: Text(r == null ? 'أضف' : 'احفظ'),
            ),
          ]),
        ),
      ),
    );
    if (ok == true) _key.currentState?.reload();
  }
}

/* ------------------------------------------------------------------ users */

class UsersSettingsScreen extends StatefulWidget {
  const UsersSettingsScreen({super.key});
  @override
  State<UsersSettingsScreen> createState() => _UsersSettingsScreenState();
}

const _viewPerm = {'global': 'كل حاجة', 'group': 'قسمه بس', 'individual': 'حاجته بس'};

class _UsersSettingsScreenState extends State<UsersSettingsScreen> {
  final _key = GlobalKey<LoaderState>();
  Obj? last;

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'المستخدمين',
        eyebrow: 'settings.users',
        fab: FloatingActionButton(onPressed: () => _open(null), child: const CiIcon('plus', size: 22)),
        body: Loader(
          key: _key,
          load: () => Api.I.get('settings/users'),
          builder: (c, d, reload) {
            last = d;
            final users = d.l('data');
            return Column(children: [
              for (final u in users)
                _row(
                  c,
                  title: u.s('name') + (u.b('is_me') ? ' (إنت)' : ''),
                  sub: '${u.s('email')} · ${u.s('role')} · يشوف ${_viewPerm[u.s('view_permission')] ?? ''}',
                  lead: Avatar(u.s('name'), size: 38),
                  trail: u.b('status') ? null : const Pill('متوقف', tone: Tone.muted, dense: true),
                  onTap: () => _open(u),
                ),
            ]);
          },
        ),
      );

  Future<void> _open(Obj? u) async {
    final d = last;
    if (d == null) return;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => UserFormScreen(user: u, roles: d.l('roles'), groups: d.l('groups'))));
    if (ok == true) _key.currentState?.reload();
  }
}

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user, required this.roles, required this.groups});
  final Obj? user;
  final List<Obj> roles, groups;
  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  late final name = TextEditingController(text: widget.user?.s('name') ?? ''), mail = TextEditingController(text: widget.user?.s('email') ?? '');
  final pass = TextEditingController();
  late int? role = widget.user?.i('role_id') ?? widget.roles.where((r) => r.s('permission_type') != 'all').firstOrNull?.i('id');
  late bool active = widget.user?.b('status') ?? true;
  late String view = widget.user?.s('view_permission', 'individual') ?? 'individual';
  late List<int> groups = widget.user?.ls('groups').map(int.parse).toList() ?? [];
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return CiPage(
      title: u == null ? 'مستخدم جديد' : u.s('name'),
      eyebrow: u == null ? 'users.new' : 'user #${u.i('id')}',
      actions: [
        if (u != null && !u.b('is_me'))
          IconButton(
            onPressed: () async {
              if (await _delete(context, u.s('name'), 'settings/users/${u.i('id')}') && context.mounted) Navigator.pop(context, true);
            },
            icon: const CiIcon('trash', size: 20),
          ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        FieldLabel('الاسم', child: TextField(controller: name)),
        FieldLabel('الإيميل', child: TextField(controller: mail, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr)),
        FieldLabel(u == null ? 'كلمة السر' : 'كلمة سر جديدة (سيبها فاضية لو مش هتغيرها)', child: TextField(controller: pass, obscureText: true, textDirection: TextDirection.ltr)),
        FieldLabel('الدور', child: PickBox(
          icon: 'shield',
          text: widget.roles.where((r) => r.i('id') == role).firstOrNull?.s('name') ?? 'اختار',
          placeholder: role == null,
          onTap: () async {
            final v = await pickOne(context, 'الدور', {for (final r in widget.roles) '${r.i('id')}': r.s('name')}, current: '$role');
            if (v != null) setState(() => role = int.parse(v));
          },
        )),
        FieldLabel('يشوف', child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final e in _viewPerm.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {view},
          onSelectionChanged: (s) => setState(() => view = s.first),
        )),
        FieldLabel('الأقسام', child: PickBox(
          icon: 'staff',
          text: groups.isEmpty ? 'من غير قسم' : widget.groups.where((g) => groups.contains(g.i('id'))).map((g) => g.s('name')).join('، '),
          placeholder: groups.isEmpty,
          onTap: () async {
            final v = await pickMany(context, 'الأقسام', widget.groups, groups);
            if (v != null) setState(() => groups = v);
          },
        )),
        if (!(u?.b('is_me') ?? false))
          SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setState(() => active = v), title: Text('الحساب شغال', style: context.tt.titleSmall), subtitle: Text(active ? 'يقدر يدخل' : 'مش هيقدر يدخل', style: context.tt.bodySmall)),
        saveButton(busy: busy, text: u == null ? 'أضف المستخدم' : 'احفظ', onPressed: _save),
      ]),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty || mail.text.trim().isEmpty || role == null) return toast(context, 'الاسم والإيميل والدور مطلوبين.', error: true);
    if (view == 'group' && groups.isEmpty) return toast(context, 'اختار قسم واحد على الأقل.', error: true);
    if (widget.user == null && pass.text.length < 6) return toast(context, 'كلمة السر 6 حروف على الأقل.', error: true);
    setState(() => busy = true);
    final body = {
      'name': name.text.trim(), 'email': mail.text.trim(), 'role_id': role, 'status': active, 'view_permission': view, 'groups': groups,
      if (pass.text.isNotEmpty) 'password': pass.text,
    };
    final u = widget.user;
    final r = await doAction(context, () => u == null ? Api.I.post('settings/users', body) : Api.I.put('settings/users/${u.i('id')}', body));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) Navigator.pop(context, true);
  }
}

/* ------------------------------------------------------------------ roles */

class RolesSettingsScreen extends StatefulWidget {
  const RolesSettingsScreen({super.key});
  @override
  State<RolesSettingsScreen> createState() => _RolesSettingsScreenState();
}

class _RolesSettingsScreenState extends State<RolesSettingsScreen> {
  final _key = GlobalKey<LoaderState>();
  List<Obj> acl = const [];

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'الأدوار والصلاحيات',
        eyebrow: 'settings.roles',
        fab: FloatingActionButton(onPressed: () => _open(null), child: const CiIcon('plus', size: 22)),
        body: Loader(
          key: _key,
          load: () => Api.I.get('settings/roles'),
          builder: (c, d, reload) {
            acl = d.l('acl');
            return Column(children: [
              for (final r in d.l('data'))
                _row(
                  c,
                  title: r.s('name'),
                  sub: '${r.s('permission_type') == 'all' ? 'كل الصلاحيات' : '${r.ls('permissions').length} صلاحية'} · ${r.i('users')} شخص',
                  lead: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: r.s('permission_type') == 'all' ? c.ci.brandSoft : c.ci.sunken, borderRadius: BorderRadius.circular(9)),
                    child: CiIcon('shield', size: 18, color: r.s('permission_type') == 'all' ? c.ci.brand : c.ci.muted),
                  ),
                  onTap: () => _open(r),
                ),
            ]);
          },
        ),
      );

  Future<void> _open(Obj? r) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RoleFormScreen(role: r, acl: acl)));
    if (ok == true) _key.currentState?.reload();
  }
}

class RoleFormScreen extends StatefulWidget {
  const RoleFormScreen({super.key, this.role, required this.acl});
  final Obj? role;
  final List<Obj> acl;
  @override
  State<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends State<RoleFormScreen> {
  late final name = TextEditingController(text: widget.role?.s('name') ?? ''), desc = TextEditingController(text: widget.role?.s('description') ?? '');
  late String type = widget.role?.s('permission_type', 'custom') ?? 'custom';
  late final Set<String> perms = {...?widget.role?.ls('permissions')};
  bool busy = false;

  /// Children of an item = the items right after it with a deeper level.
  List<String> _children(int i) {
    final d = widget.acl[i].i('depth');
    final out = <String>[];
    for (var j = i + 1; j < widget.acl.length && widget.acl[j].i('depth') > d; j++) {
      out.add(widget.acl[j].s('key'));
    }
    return out;
  }

  String? _parent(int i) {
    final d = widget.acl[i].i('depth');
    for (var j = i - 1; j >= 0; j--) {
      if (widget.acl[j].i('depth') < d) return widget.acl[j].s('key');
    }
    return null;
  }

  void _toggle(int i, bool on) => setState(() {
        final key = widget.acl[i].s('key');
        if (on) {
          perms.add(key);
          perms.addAll(_children(i));
          // turning on a child needs its parents on too, like the web tree
          for (var k = i, p = _parent(k); p != null; k = widget.acl.indexWhere((x) => x.s('key') == p), p = _parent(k)) {
            perms.add(p);
          }
        } else {
          perms.remove(key);
          perms.removeAll(_children(i));
        }
      });

  @override
  Widget build(BuildContext context) {
    final r = widget.role;
    return CiPage(
      title: r == null ? 'دور جديد' : r.s('name'),
      eyebrow: r == null ? 'roles.new' : 'role #${r.i('id')}',
      actions: [
        if (r != null && r.i('users') == 0)
          IconButton(
            onPressed: () async {
              if (await _delete(context, r.s('name'), 'settings/roles/${r.i('id')}') && context.mounted) Navigator.pop(context, true);
            },
            icon: const CiIcon('trash', size: 20),
          ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        FieldLabel('اسم الدور', child: TextField(controller: name)),
        FieldLabel('الوصف', child: TextField(controller: desc)),
        FieldLabel('الصلاحيات', child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'custom', label: Text('أختار بنفسي')), ButtonSegment(value: 'all', label: Text('كل حاجة'))],
          selected: {type},
          onSelectionChanged: (s) => setState(() => type = s.first),
        )),
        if (type == 'custom') ...[
          Row(children: [
            Text('${perms.length} صلاحية متعلمة', style: context.tt.bodySmall),
            const Spacer(),
            TextButton(onPressed: () => setState(() => perms.addAll(widget.acl.map((a) => a.s('key')))), child: const Text('علّم الكل')),
            TextButton(onPressed: () => setState(perms.clear), child: const Text('شيل الكل')),
          ]),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final (i, a) in widget.acl.indexed)
                InkWell(
                  onTap: () => _toggle(i, !perms.contains(a.s('key'))),
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 8.0 + a.i('depth') * 18, end: 8, top: 2, bottom: 2),
                    child: Row(children: [
                      Checkbox(value: perms.contains(a.s('key')), onChanged: (v) => _toggle(i, v ?? false), visualDensity: VisualDensity.compact),
                      Expanded(child: Text(a.s('name'), style: a.i('depth') == 0 ? context.tt.titleSmall : context.tt.bodyMedium)),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        saveButton(busy: busy, text: r == null ? 'أضف الدور' : 'احفظ', onPressed: _save),
      ]),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return toast(context, 'اكتب اسم الدور.', error: true);
    if (type == 'custom' && perms.isEmpty) return toast(context, 'علّم صلاحية واحدة على الأقل.', error: true);
    setState(() => busy = true);
    final body = {'name': name.text.trim(), 'description': desc.text.trim(), 'permission_type': type, if (type == 'custom') 'permissions': perms.toList()};
    final r = widget.role;
    final res = await doAction(context, () => r == null ? Api.I.post('settings/roles', body) : Api.I.put('settings/roles/${r.i('id')}', body));
    if (!mounted) return;
    setState(() => busy = false);
    if (res != null) Navigator.pop(context, true);
  }
}

/* ------------------------------------------------------------------ pipelines */

class PipelinesSettingsScreen extends StatefulWidget {
  const PipelinesSettingsScreen({super.key});
  @override
  State<PipelinesSettingsScreen> createState() => _PipelinesSettingsScreenState();
}

class _PipelinesSettingsScreenState extends State<PipelinesSettingsScreen> {
  final _key = GlobalKey<LoaderState>();

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'مراحل البيع',
        eyebrow: 'settings.pipelines',
        fab: FloatingActionButton(onPressed: () => _open(null), child: const CiIcon('plus', size: 22)),
        body: Loader(
          key: _key,
          load: () => Api.I.get('settings/pipelines'),
          builder: (c, d, reload) => Column(children: [
            for (final p in d.l('data'))
              _row(
                c,
                title: p.s('name'),
                sub: p.l('stages').map((s) => s.s('name')).join(' ← '),
                trail: p.b('is_default') ? const Pill('الأساسي', tone: Tone.brand, dense: true) : null,
                onTap: () => _open(p),
              ),
          ]),
        ),
      );

  Future<void> _open(Obj? p) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PipelineFormScreen(pipeline: p)));
    if (ok == true) _key.currentState?.reload();
  }
}

class _Stage {
  _Stage({this.id, this.code = '', String name = '', int probability = 0, this.leads = 0})
      : name = TextEditingController(text: name),
        prob = TextEditingController(text: '$probability');
  final int? id;
  final String code;
  final int leads;
  final TextEditingController name, prob;
  bool get fixed => code == 'won' || code == 'lost' || code == 'new';
}

class PipelineFormScreen extends StatefulWidget {
  const PipelineFormScreen({super.key, this.pipeline});
  final Obj? pipeline;
  @override
  State<PipelineFormScreen> createState() => _PipelineFormScreenState();
}

class _PipelineFormScreenState extends State<PipelineFormScreen> {
  late final name = TextEditingController(text: widget.pipeline?.s('name') ?? ''), rotten = TextEditingController(text: '${widget.pipeline?.i('rotten_days', 30) ?? 30}');
  late bool isDefault = widget.pipeline?.b('is_default') ?? false;
  late final List<_Stage> stages = widget.pipeline == null
      ? [_Stage(code: 'new', name: 'جديد', probability: 10), _Stage(name: 'متابعة', probability: 30), _Stage(name: 'تفاوض', probability: 60), _Stage(code: 'won', name: 'اتكسب', probability: 100), _Stage(code: 'lost', name: 'اتخسر')]
      : widget.pipeline!.l('stages').map((s) => _Stage(id: s.i('id'), code: s.s('code'), name: s.s('name'), probability: s.i('probability'), leads: s.i('leads'))).toList();
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pipeline;
    return CiPage(
      title: p == null ? 'مراحل بيع جديدة' : p.s('name'),
      eyebrow: p == null ? 'pipelines.new' : 'pipeline #${p.i('id')}',
      actions: [
        if (p != null && !p.b('is_default'))
          IconButton(
            onPressed: () async {
              if (await _delete(context, p.s('name'), 'settings/pipelines/${p.i('id')}') && context.mounted) Navigator.pop(context, true);
            },
            icon: const CiIcon('trash', size: 20),
          ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        FieldLabel('الاسم', child: TextField(controller: name)),
        FieldLabel('الفرصة تبقى "بايتة" بعد كام يوم من غير حركة', child: TextField(controller: rotten, keyboardType: TextInputType.number, textDirection: TextDirection.ltr)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: isDefault, onChanged: (v) => setState(() => isDefault = v), title: Text('الأساسي (الفرص الجديدة تدخل فيه)', style: context.tt.titleSmall)),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.only(bottom: 8, right: 2), child: Text('المراحل بالترتيب', style: context.tt.labelMedium)),
        for (final (i, s) in stages.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(children: [
                Text('${i + 1}', style: mono(context, size: 12, color: context.ci.brand)),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: TextField(controller: s.name, decoration: const InputDecoration(isDense: true, hintText: 'اسم المرحلة'))),
                const SizedBox(width: 8),
                SizedBox(width: 82, child: TextField(controller: s.prob, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(isDense: true, suffixText: '%'))),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: context.ci.subtle),
                  onSelected: (v) => setState(() {
                    if (v == 'up' && i > 0) stages.insert(i - 1, stages.removeAt(i));
                    if (v == 'down' && i < stages.length - 1) stages.insert(i + 1, stages.removeAt(i));
                    if (v == 'del') stages.removeAt(i);
                  }),
                  itemBuilder: (c) => [
                    if (i > 0) const PopupMenuItem(value: 'up', child: Text('طلّعها فوق')),
                    if (i < stages.length - 1) const PopupMenuItem(value: 'down', child: Text('نزّلها تحت')),
                    if (!s.fixed) PopupMenuItem(value: 'del', child: Text(s.leads > 0 ? 'امسحها (${s.leads} فرصة هتروح لأول مرحلة)' : 'امسحها')),
                  ],
                ),
              ]),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => setState(() => stages.insert(stages.indexWhere((s) => s.code == 'won').clamp(0, stages.length), _Stage(probability: 50))),
            icon: const CiIcon('plus', size: 16),
            label: const Text('مرحلة كمان'),
          ),
        ),
        saveButton(busy: busy, text: p == null ? 'أضف' : 'احفظ', onPressed: _save),
      ]),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return toast(context, 'اكتب الاسم.', error: true);
    final list = stages.where((s) => s.name.text.trim().isNotEmpty).toList();
    if (list.length < 2) return toast(context, 'لازم مرحلتين على الأقل.', error: true);
    setState(() => busy = true);
    final body = {
      'name': name.text.trim(),
      'rotten_days': int.tryParse(rotten.text.trim()) ?? 30,
      'is_default': isDefault,
      'stages': [for (final s in list) {'id': s.id, 'code': s.code, 'name': s.name.text.trim(), 'probability': (int.tryParse(s.prob.text.trim()) ?? 0).clamp(0, 100)}],
    };
    final p = widget.pipeline;
    final r = await doAction(context, () => p == null ? Api.I.post('settings/pipelines', body) : Api.I.put('settings/pipelines/${p.i('id')}', body));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) Navigator.pop(context, true);
  }
}
