import 'dart:async';

import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/fmt.dart' as f;
import '../core/obj.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';

/* ================================================================== list */

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Obj>? convs;
  String? error;
  String q = '';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.I.get('chat');
      if (!mounted) return;
      final list = r.l('conversations')..sort((a, b) => (b.t('at') ?? DateTime(2000)).compareTo(a.t('at') ?? DateTime(2000)));
      Session.I.setBadges(chat: list.fold<int>(0, (s, c) => s + c.i('unread')));
      setState(() {
        convs = list;
        error = null;
      });
    } on ApiError catch (e) {
      if (mounted && convs == null) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = (convs ?? const <Obj>[]).where((c) => q.isEmpty || c.s('name').contains(q)).toList();
    return CiPage(
      title: 'الشات',
      eyebrow: 'team.chat',
      back: false,
      actions: [if (Session.I.can('chat_monitor')) IconButton(tooltip: 'متابعة كل المحادثات', onPressed: () => context.push('/chat/monitor'), icon: const Icon(Icons.visibility_outlined, size: 21))],
      fab: FloatingActionButton(onPressed: () => context.push('/chat/new').then((_) => _load()), child: const CiIcon('edit', size: 20)),
      body: convs == null
          ? (error != null ? ErrorState(error!, onRetry: _load) : const Padding(padding: EdgeInsets.all(16), child: Skeleton()))
          : RefreshIndicator(
              onRefresh: _load,
              color: context.ci.brand,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                CommandField(hint: 'دوّر في المحادثات', onChanged: (v) => setState(() => q = v.trim())),
                const SizedBox(height: 8),
                if (list.isEmpty) const EmptyState('مفيش محادثات لسه', body: 'ابدأ محادثة مع حد من الفريق.', icon: 'users'),
                for (final c in list) _ConvRow(c, onBack: _load),
              ]),
            ),
    );
  }
}

class _ConvRow extends StatelessWidget {
  const _ConvRow(this.c, {required this.onBack});
  final Obj c;
  final Future<void> Function() onBack;
  @override
  Widget build(BuildContext context) {
    final unread = c.i('unread');
    final last = c.o('last');
    final group = c.s('type') == 'group';
    String preview;
    if (!c.has('last')) {
      preview = 'محادثة جديدة';
    } else if (last.b('deleted')) {
      preview = 'رسالة اتمسحت';
    } else if (last.s('kind') == 'system') {
      preview = 'تحديث في الجروب';
    } else {
      final body = last.has('body') ? last.s('body') : (last.has('file') ? '📎 ملف' : '');
      final who = last.i('user_id') == Session.I.me?.i('id') ? 'إنت' : (group ? last.s('sender').split(' ').first : '');
      preview = who.isEmpty ? body : '$who: $body';
    }
    return InkWell(
      onTap: () => context.push('/chat/${c.i('id')}?t=${Uri.encodeComponent(c.s('name'))}').then((_) => onBack()),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.ci.line))),
        child: Row(children: [
          Avatar(c.s('name'), size: 46, group: group),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall!.copyWith(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500))),
                Text(_when(c.t('at')), style: mono(context, size: 10.5, color: unread > 0 ? context.ci.brand : null)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall!.copyWith(color: unread > 0 ? context.ci.ink : null))),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsetsDirectional.only(start: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: context.ci.brand, borderRadius: BorderRadius.circular(4)),
                    child: Text('$unread', style: numStyle(context, size: 11, color: context.ci.onBrand)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _when(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return f.time(d);
  if (now.difference(d).inDays < 7) return f.weekday(d);
  return f.dateShort(d);
}

/* ================================================================== new chat */

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool group = false;
  final picked = <int>{};
  final title = TextEditingController();
  String q = '';

  @override
  Widget build(BuildContext context) => CiPage(
        title: group ? 'جروب جديد' : 'محادثة جديدة',
        eyebrow: 'chat.new',
        actions: [TextButton(onPressed: () => setState(() => group = !group), child: Text(group ? 'محادثة فردية' : 'اعمل جروب'))],
        fab: group && picked.isNotEmpty ? FloatingActionButton.extended(onPressed: _makeGroup, label: Text('اعمل الجروب (${picked.length})')) : null,
        body: Loader(
          load: () => Api.I.get('chat/users'),
          builder: (c, r, reload) {
            final users = r.l('users').where((u) => u.b('active') && (q.isEmpty || u.s('name').contains(q))).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (group) ...[FieldLabel('اسم الجروب', child: TextField(controller: title, decoration: const InputDecoration(hintText: 'مثلاً: فريق مشروع ذهبي'))), const SizedBox(height: 4)],
              CommandField(hint: 'دوّر على حد', onChanged: (v) => setState(() => q = v.trim())),
              const SizedBox(height: 8),
              for (final u in users)
                InkWell(
                  onTap: () => group ? setState(() => picked.contains(u.i('id')) ? picked.remove(u.i('id')) : picked.add(u.i('id'))) : _direct(u),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Avatar(u.s('name'), size: 42),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u.s('name'), style: c.tt.titleSmall), Text(u.s('role'), style: c.tt.bodySmall)])),
                      if (group) Checkbox(value: picked.contains(u.i('id')), onChanged: (_) => setState(() => picked.contains(u.i('id')) ? picked.remove(u.i('id')) : picked.add(u.i('id')))),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );

  Future<void> _direct(Obj u) async {
    final r = await doAction(context, () => Api.I.post('chat/conversations', {'type': 'direct', 'user_id': u.i('id')}), success: '');
    final conv = r?.o('conversation');
    if (conv == null || !mounted) return;
    context.pushReplacement('/chat/${conv.i('id')}?t=${Uri.encodeComponent(u.s('name'))}');
  }

  Future<void> _makeGroup() async {
    if (title.text.trim().isEmpty) return toast(context, 'اكتب اسم الجروب.', error: true);
    final r = await doAction(context, () => Api.I.post('chat/conversations', {'type': 'group', 'title': title.text.trim(), 'user_ids': picked.toList()}), success: 'الجروب اتعمل.');
    final conv = r?.o('conversation');
    if (conv == null || !mounted) return;
    context.pushReplacement('/chat/${conv.i('id')}?t=${Uri.encodeComponent(title.text.trim())}');
  }
}

/* ================================================================== conversation */

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.id, required this.title});
  final int id;
  final String title;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> with WidgetsBindingObserver {
  final msgs = <Obj>[];
  final input = TextEditingController();
  final _scroll = ScrollController();
  bool loading = true, older = false, hasMore = false, sending = false;
  String? error;
  Timer? _poll;

  int get _lastId => msgs.isEmpty ? 0 : msgs.map((m) => m.i('id')).reduce((a, b) => a > b ? a : b);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _first();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _older();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _tick();
      _start();
    } else {
      _poll?.cancel();
    }
  }

  void _start() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _merge(List<Obj> list) {
    final ids = msgs.map((m) => m.i('id')).toSet();
    for (final m in list) {
      if (!ids.contains(m.i('id'))) msgs.add(m);
    }
    msgs.sort((a, b) => a.i('id').compareTo(b.i('id')));
  }

  Future<void> _first() async {
    try {
      final r = await Api.I.get('chat/${widget.id}/messages');
      if (!mounted) return;
      setState(() {
        _merge(r.l('messages'));
        hasMore = r.b('has_more');
        loading = false;
      });
      _tick(seen: true);
      _start();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  Future<void> _tick({bool seen = true}) async {
    try {
      final r = await Api.I.get('chat', {'conversation': widget.id, 'after': _lastId, 'seen': seen ? 1 : null});
      if (!mounted) return;
      final fresh = r.l('messages');
      Session.I.setBadges(chat: r.l('conversations').where((c) => c.i('id') != widget.id).fold<int>(0, (s, c) => s + c.i('unread')));
      if (fresh.isNotEmpty) {
        if (fresh.any((m) => !m.b('mine'))) HapticFeedback.lightImpact();
        setState(() => _merge(fresh));
      }
    } on ApiError catch (_) {}
  }

  Future<void> _older() async {
    if (older || !hasMore || msgs.isEmpty) return;
    older = true;
    try {
      final r = await Api.I.get('chat/${widget.id}/messages', {'before': msgs.first.i('id')});
      if (mounted) {
        setState(() {
          _merge(r.l('messages'));
          hasMore = r.b('has_more');
        });
      }
    } on ApiError catch (_) {
    } finally {
      older = false;
    }
  }

  Future<void> _attach() async {
    if (sending) return;
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || files.first.path == null || !mounted) return;
    final x = files.first;
    if (await x.xFile.length() > 20 * 1024 * 1024) {
      if (mounted) toast(context, 'الملف أكبر من 20 ميجا.', error: true);
      return;
    }
    await _send(file: await MultipartFile.fromFile(x.path!, filename: x.name));
  }

  Future<void> _send({MultipartFile? file}) async {
    final text = input.text.trim();
    if ((text.isEmpty && file == null) || sending) return;
    setState(() => sending = true);
    try {
      final r = await Api.I.post('chat/${widget.id}/messages', file == null ? {'body': text} : FormData.fromMap({'body': text, 'file': file}));
      input.clear();
      if (r.has('message') && mounted) setState(() => _merge([r.o('message')]));
      HapticFeedback.selectionClick();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = msgs.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: context.ci.line)),
        title: Row(children: [
          Avatar(widget.title.isEmpty ? 'محادثة' : widget.title, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title.isEmpty ? 'محادثة' : widget.title, style: context.tt.titleMedium, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : error != null
                    ? ErrorState(error!, onRetry: _first)
                    : msgs.isEmpty
                        ? const EmptyState('لسه مفيش رسايل', body: 'ابدأ إنت.', icon: 'edit')
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            itemCount: items.length,
                            itemBuilder: (c, i) {
                              final m = items[i];
                              final prev = i + 1 < items.length ? items[i + 1] : null;
                              final newDay = prev == null || f.ymd(prev.t('at') ?? DateTime.now()) != f.ymd(m.t('at') ?? DateTime.now());
                              final sameSender = !newDay && prev.i('user_id') == m.i('user_id') && prev.s('kind') != 'system';
                              return Column(children: [
                                if (newDay) _DayChip(m.t('at')),
                                _Bubble(m, convId: widget.id, showName: !sameSender && !m.b('mine')),
                              ]);
                            },
                          ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(color: context.ci.surface, border: Border(top: BorderSide(color: context.ci.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(tooltip: 'ابعت ملف أو صورة', onPressed: sending ? null : _attach, icon: Icon(Icons.attach_file_rounded, size: 21, color: context.ci.muted)),
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(hintText: 'اكتب رسالة', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : () => _send(),
                icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const CiIcon('arrow', size: 20),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.d);
  final DateTime? d;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = d != null && f.ymd(d!) == f.ymd(now);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.ci.line)),
          child: Text(today ? 'النهارده' : f.dateLong(d), style: mono(context, size: 10.5)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.convId, required this.showName});
  final Obj m;
  final int convId;
  final bool showName;
  @override
  Widget build(BuildContext context) {
    if (m.s('kind') == 'system') {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Center(child: Text(m.s('body', 'تحديث في الجروب'), style: context.tt.labelSmall)));
    }
    final mine = m.b('mine');
    final deleted = m.b('deleted');
    final file = m.on('file');
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        margin: EdgeInsets.only(top: showName ? 8 : 2, bottom: 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? context.ci.brandSoft : context.ci.surface,
          border: Border.all(color: mine ? context.ci.brand.withValues(alpha: .25) : context.ci.line),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(12),
            topEnd: const Radius.circular(12),
            bottomStart: Radius.circular(mine ? 12 : 3),
            bottomEnd: Radius.circular(mine ? 3 : 12),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (showName) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(m.s('sender'), style: context.tt.labelSmall!.copyWith(color: context.ci.teal, fontWeight: FontWeight.w600))),
          if (deleted)
            Text('الرسالة دي اتمسحت', style: context.tt.bodySmall!.copyWith(fontStyle: FontStyle.italic))
          else ...[
            if (file != null)
              InkWell(
                onTap: () => openFile(context, file.s('url'), file.s('name')),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(file.b('image') ? Icons.image_rounded : Icons.insert_drive_file_rounded, size: 20, color: context.ci.brand),
                    const SizedBox(width: 8),
                    Flexible(child: Text(file.s('name'), style: context.tt.bodyMedium!.copyWith(decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
            if (m.has('body')) SelectableText(m.s('body'), style: context.tt.bodyMedium!.copyWith(height: 1.5)),
          ],
          const SizedBox(height: 2),
          Align(alignment: AlignmentDirectional.centerEnd, child: Text(f.time(m.t('at')), style: mono(context, size: 9.5))),
        ]),
      ),
    );
  }
}


/* ================================================================== monitor (admins) */

class ChatMonitorScreen extends StatefulWidget {
  const ChatMonitorScreen({super.key});
  @override
  State<ChatMonitorScreen> createState() => _ChatMonitorScreenState();
}

class _ChatMonitorScreenState extends State<ChatMonitorScreen> {
  String q = '';
  Timer? _deb;
  final _key = GlobalKey<LoaderState>();

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CiPage(
        title: 'متابعة المحادثات',
        eyebrow: 'chat.monitor',
        body: Loader(
          key: _key,
          load: () async {
            final r = await Api.I.get('chat/monitor', {if (q.isNotEmpty) 'q': q});
            final u = await Api.I.get('chat/users');
            return Obj({'conversations': r.j['conversations'], 'users': u.j['users']});
          },
          builder: (c, d, reload) {
            final names = {for (final u in d.l('users')) u.i('id'): u.s('name')};
            final list = d.l('conversations');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CommandField(hint: 'دوّر في الرسايل أو الأسماء', onChanged: (v) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 450), () {
                  q = v.trim();
                  _key.currentState?.reload();
                });
              }),
              const SizedBox(height: 10),
              Text('بتشوف كل المحادثات للقراءة بس. محدش بيعرف إنك فتحتها.', style: c.tt.bodySmall),
              const SizedBox(height: 10),
              if (list.isEmpty) const EmptyState('مفيش محادثات', icon: 'users'),
              for (final cv in list) _MonitorRow(cv, names),
            ]);
          },
        ),
      );
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow(this.c, this.names);
  final Obj c;
  final Map<int, String> names;
  @override
  Widget build(BuildContext context) {
    final people = c.ls('members').map((id) => names[int.tryParse(id) ?? 0] ?? '').where((n) => n.isNotEmpty).toList();
    final title = c.s('type') == 'group' && c.has('title') ? c.s('title') : people.join(' و ');
    final last = c.on('last');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        onTap: () => context.push('/chat/monitor/${c.i('id')}?t=${Uri.encodeComponent(title)}'),
        child: Row(children: [
          Avatar(title.isEmpty ? '؟' : title, size: 40, group: c.s('type') == 'group'),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (last != null)
              Text('${names[last.i('user_id')] ?? ''}: ${last.b('deleted') ? 'رسالة اتمسحت' : last.on('file') != null ? '📎 ${last.o('file').s('name')}' : last.s('body')}',
                  style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(f.ago(c.t('at')), style: mono(context, size: 10.5, color: context.ci.subtle)),
            const SizedBox(height: 4),
            Text('${c.i('count')} رسالة', style: mono(context, size: 10.5, color: context.ci.muted)),
          ]),
        ]),
      ),
    );
  }
}

class MonitorConversationScreen extends StatefulWidget {
  const MonitorConversationScreen({super.key, required this.id, this.title = ''});
  final int id;
  final String title;
  @override
  State<MonitorConversationScreen> createState() => _MonitorConversationScreenState();
}

class _MonitorConversationScreenState extends State<MonitorConversationScreen> {
  final msgs = <Obj>[];
  bool loading = true, more = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool older = false}) async {
    try {
      final r = await Api.I.get('chat/monitor/${widget.id}', {if (older && msgs.isNotEmpty) 'before': msgs.first.i('id')});
      final got = r.l('messages');
      if (!mounted) return;
      setState(() {
        msgs.insertAll(0, got.where((m) => !msgs.any((x) => x.i('id') == m.i('id'))));
        more = got.length >= 30;
        loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => (error = e.message, loading = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = msgs.reversed.toList();
    return CiPage(
      title: widget.title.isEmpty ? 'محادثة' : widget.title,
      eyebrow: 'monitor #${widget.id} · قراءة بس',
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : error != null
              ? ErrorState(error!, onRetry: _load)
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: items.length + (more ? 1 : 0),
                  itemBuilder: (c, i) {
                    if (i == items.length) {
                      return Center(child: TextButton(onPressed: () => _load(older: true), child: const Text('رسايل أقدم')));
                    }
                    final m = items[i];
                    final prev = i + 1 < items.length ? items[i + 1] : null;
                    final newDay = prev == null || f.ymd(prev.t('at') ?? DateTime(2000)) != f.ymd(m.t('at') ?? DateTime(2000));
                    final showName = newDay || prev.i('user_id') != m.i('user_id');
                    final view = Obj({...m.j, 'mine': false});
                    return Column(children: [
                      if (newDay) _DayChip(m.t('at')),
                      _Bubble(view, convId: widget.id, showName: showName),
                    ]);
                  },
                ),
    );
  }
}
