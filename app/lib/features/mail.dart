import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/fmt.dart' as f;
import '../core/obj.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';

const _folders = {'inbox': 'الوارد', 'sent': 'المرسل', 'draft': 'مسودات', 'trash': 'المحذوف'};

String _name(String from) {
  final i = from.indexOf('<');
  return (i > 0 ? from.substring(0, i) : from).trim();
}

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});
  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  String folder = 'inbox';
  final _list = GlobalKey<PagedListState>();
  @override
  Widget build(BuildContext context) => CiPage(
        title: 'البريد',
        eyebrow: 'mail.$folder',
        fab: FloatingActionButton(
          onPressed: () async {
            if (await context.push<bool>('/mail/compose') == true) _list.currentState?.refresh();
          },
          child: const CiIcon('edit', size: 20),
        ),
        body: PagedList(
          key: _list,
          path: 'mail/$folder',
          searchHint: 'دوّر في البريد',
          empty: folder == 'inbox' ? 'الوارد فاضي' : 'مفيش رسايل هنا',
          emptyIcon: 'check',
          separator: 0,
          header: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 36,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final e in _folders.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: CiChip(selected: folder == e.key, label: e.value, onSelected: (_) => setState(() => folder = e.key)),
                  ),
              ]),
            ),
          ),
          item: (c, m) => _MailRow(m, folder: folder),
        ),
      );
}

class _MailRow extends StatelessWidget {
  const _MailRow(this.m, {required this.folder});
  final Obj m;
  final String folder;
  @override
  Widget build(BuildContext context) {
    final unread = !m.b('is_read') && folder == 'inbox';
    final who = folder == 'sent' ? (m.ls('to').isEmpty ? '—' : 'إلى ${m.ls('to').first}') : _name(m.s('from'));
    return InkWell(
      onTap: () => context.push('/mail/$folder/${m.i('id')}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.ci.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Stack(clipBehavior: Clip.none, children: [
              Avatar(who.replaceFirst('إلى ', ''), size: 38),
              if (unread) PositionedDirectional(top: -2, start: -2, child: Container(width: 9, height: 9, color: context.ci.brand)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500))),
                Text(f.ago(m.t('created_at')), style: mono(context, size: 10.5, color: unread ? context.ci.brand : null)),
              ]),
              const SizedBox(height: 2),
              Text(m.s('subject', '(من غير موضوع)'), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium!.copyWith(color: unread ? context.ci.ink : context.ci.muted, fontWeight: unread ? FontWeight.w600 : null)),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(m.s('snippet'), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall)),
                if (m.l('attachments').isNotEmpty) Icon(Icons.attach_file_rounded, size: 14, color: context.ci.subtle),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class MailViewScreen extends StatelessWidget {
  const MailViewScreen({super.key, required this.folder, required this.id});
  final String folder;
  final int id;

  @override
  Widget build(BuildContext context) => CiPage(
        title: _folders[folder] ?? 'البريد',
        eyebrow: 'mail.$folder #$id',
        body: Loader(
          load: () => Api.I.get('mail/$folder/$id'),
          builder: (c, r, reload) {
            final m = r.o('data');
            final all = [m, ...m.l('thread')];
            final last = all.last;
            final replyTo = folder == 'sent' ? (m.ls('to').firstOrNull ?? '') : _addr(last.s('from'));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(m.s('subject', '(من غير موضوع)'), style: c.tt.headlineSmall),
              if (m.has('lead') || m.has('person'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 8, children: [
                    if (m.has('lead')) CiChip(label: m.ref('lead'), selected: false, onSelected: (_) => c.push('/leads/${m.refId('lead')}')),
                    if (m.has('person')) CiChip(label: m.ref('person'), selected: false, onSelected: (_) => c.push('/persons/${m.refId('person')}')),
                  ]),
                ),
              const SizedBox(height: 14),
              for (final x in all) _Message(x),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => c.push('/mail/compose?to=${Uri.encodeComponent(replyTo)}&subject=${Uri.encodeComponent(_re(m.s('subject')))}&parent=$id'),
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: const Text('رد'),
              ),
            ]);
          },
        ),
      );

  static String _addr(String from) {
    final m = RegExp(r'<([^>]+)>').firstMatch(from);
    return (m?.group(1) ?? from).trim();
  }

  static String _re(String s) => s.toLowerCase().startsWith('re:') ? s : 'Re: $s';
}

class _Message extends StatelessWidget {
  const _Message(this.m);
  final Obj m;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(_name(m.s('from')), size: 34),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name(m.s('from')), style: context.tt.titleSmall),
                Text('إلى ${m.ls('to').join(', ')}', style: context.tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr),
              ])),
              Text(f.dateTime(m.t('created_at')), style: mono(context, size: 10.5)),
            ]),
            Divider(height: 24, color: context.ci.line),
            SelectableText(m.s('body', m.s('snippet')), style: context.tt.bodyMedium!.copyWith(height: 1.7)),
            if (m.l('attachments').isNotEmpty) ...[const SizedBox(height: 8), for (final a in m.l('attachments')) FileRow(a)],
          ]),
        ),
      );
}

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.to, this.subject, this.parentId});
  final String? to, subject;
  final int? parentId;
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  late final to = TextEditingController(text: widget.to ?? '');
  late final subject = TextEditingController(text: widget.subject ?? '');
  final cc = TextEditingController(), body = TextEditingController();
  bool showCc = false, busy = false;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  List<String> _split(String s) => s.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) => CiPage(
        title: widget.parentId == null ? 'رسالة جديدة' : 'رد',
        eyebrow: 'mail.compose',
        actions: [
          IconButton(
            onPressed: busy ? null : _send,
            icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : CiIcon('arrow', size: 22, color: context.ci.brand),
          ),
        ],
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
          FieldLabel('إلى', child: TextField(
            controller: to,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: 'name@company.com',
              suffixIcon: TextButton(onPressed: () => setState(() => showCc = !showCc), child: const Text('نسخة')),
            ),
          )),
          if (showCc) FieldLabel('نسخة إلى', child: TextField(controller: cc, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr)),
          FieldLabel('الموضوع', child: TextField(controller: subject)),
          FieldLabel('الرسالة', child: TextField(controller: body, minLines: 10, maxLines: 30, autofocus: widget.to != null && widget.to!.isNotEmpty)),
          Text('هتتبعت من بريد الشركة زي ما بتتبعت من الـ CRM.', style: context.tt.bodySmall),
        ]),
      );

  Future<void> _send() async {
    final tos = _split(to.text), ccs = _split(cc.text);
    final bad = [...tos, ...ccs].where((e) => !_email.hasMatch(e));
    if (tos.isEmpty) return toast(context, 'اكتب إيميل المستلم.', error: true);
    if (bad.isNotEmpty) return toast(context, 'الإيميل ده مش صح: ${bad.first}', error: true);
    if (subject.text.trim().isEmpty || body.text.trim().isEmpty) return toast(context, 'اكتب الموضوع والرسالة.', error: true);
    setState(() => busy = true);
    final r = await doAction(context, () => Api.I.post('mail', {
          'to': tos,
          if (ccs.isNotEmpty) 'cc': ccs,
          'subject': subject.text.trim(),
          'body': body.text.trim(),
          'parent_id': widget.parentId,
        }), success: 'الرسالة اتبعتت.');
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) context.pop(true);
  }
}
