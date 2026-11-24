import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/fmt.dart' as f;
import '../core/obj.dart';
import '../core/theme.dart';
import 'kit.dart';

/// Pick one option from a bottom sheet. Returns the key.
Future<String?> pickOne(BuildContext context, String title, Map<String, String> options, {String? current}) => showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(title, style: c.tt.titleMedium)),
            for (final e in options.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: e.key == current ? c.ci.brandSoft : c.ci.sunken,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(c, e.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(children: [
                        Expanded(child: Text(e.value, style: c.tt.titleSmall!.copyWith(color: e.key == current ? c.ci.brand : null))),
                        if (e.key == current) Icon(Icons.check_rounded, size: 18, color: c.ci.brand),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );

/// Ask for a short text (comment, note, reason).
Future<String?> askText(BuildContext context, String title, {String hint = '', String action = 'إرسال', bool required = true, int lines = 4, String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: ctx.tt.titleMedium),
        const SizedBox(height: 12),
        TextField(controller: c, autofocus: true, minLines: 2, maxLines: lines, decoration: InputDecoration(hintText: hint)),
        const SizedBox(height: 14),
        FilledButton(onPressed: () {
          if (required && c.text.trim().isEmpty) return;
          Navigator.pop(ctx, c.text.trim());
        }, child: Text(action)),
      ]),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, {String? body, String yes = 'أيوه', bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: c.ci.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.ci.line)),
        title: Text(title, style: c.tt.titleMedium),
        content: body == null ? null : Text(body, style: c.tt.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('لا', style: TextStyle(color: c.ci.muted))),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: c.ci.danger, foregroundColor: Colors.white, minimumSize: const Size(80, 42)) : FilledButton.styleFrom(minimumSize: const Size(80, 42)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(yes),
          ),
        ],
      ),
    ) ??
    false;

/// Run an API write, show its Arabic message, return the answer (null on error).
Future<Obj?> doAction(BuildContext context, Future<Obj> Function() call, {String? success}) async {
  try {
    final r = await call();
    if (context.mounted) toast(context, success ?? r.s('message', 'تم.'));
    return r;
  } on ApiError catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
    return null;
  }
}

/// Download a CRM file with the login token and open it in the phone's viewer.
Future<void> openFile(BuildContext context, String url, String name) async {
  if (kIsWeb || Api.demo) {
    toast(context, 'فتح الملفات بيشتغل على الموبايل.');
    return;
  }
  toast(context, 'جاري فتح $name...');
  try {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    // on the Mac the file lands in Downloads, where the person can find it again
    final dir = mac ? (await getDownloadsDirectory() ?? await getTemporaryDirectory()) : await getTemporaryDirectory();
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = '${dir.path}/$safe';
    await Api.I.dio.download(url, path, options: Options(headers: Api.I.authHeaders));
    if (mac) {
      if (!await launchUrl(Uri.file(path)) && context.mounted) toast(context, 'الملف اتحفظ في Downloads.');
      return;
    }
    final r = await OpenFilex.open(path);
    if (r.type != ResultType.done && context.mounted) toast(context, 'مفيش برنامج على الموبايل يفتح الملف ده.', error: true);
    if (!await File(path).exists() && context.mounted) toast(context, 'الملف ماتحملش.', error: true);
  } catch (_) {
    if (context.mounted) toast(context, 'الملف ماتحملش. جرّب تاني.', error: true);
  }
}

Future<void> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
Future<void> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
Future<void> whatsapp(String phone) {
  var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('0')) p = '+2$p';
  return launchUrl(Uri.parse('https://wa.me/${p.replaceAll('+', '')}'), mode: LaunchMode.externalApplication);
}

Future<void> email(String to) => launchUrl(Uri(scheme: 'mailto', path: to));

/// A file row: icon, name, size; tap opens it.
class FileRow extends StatelessWidget {
  const FileRow(this.file, {super.key});
  final Obj file;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openFile(context, file.s('url'), file.s('name')),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.ci.line)),
              child: Text(_ext(file.s('name')), style: mono(context, size: 10, color: context.ci.brand, w: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(file.s('name'), style: context.tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (file.i('size') > 0) Text(f.fileSize(file.i('size')), style: mono(context, size: 11)),
            ])),
            Icon(Icons.open_in_new_rounded, size: 18, color: context.ci.subtle),
          ]),
        ),
      );

  static String _ext(String n) {
    final i = n.lastIndexOf('.');
    return i < 0 ? 'FILE' : n.substring(i + 1).toUpperCase().substring(0, (n.length - i - 1).clamp(0, 4));
  }
}

/// Labelled form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, required this.child});
  final String text;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8, right: 2), child: Text(text, style: context.tt.labelMedium)),
          child,
        ]),
      );
}

/// Tappable box showing a picked value (date, option...).
class PickBox extends StatelessWidget {
  const PickBox({super.key, required this.text, required this.onTap, this.icon = 'calendar', this.placeholder = false});
  final String text, icon;
  final VoidCallback onTap;
  final bool placeholder;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.ci.line)),
          child: Row(children: [
            Expanded(child: Text(text, style: context.tt.bodyMedium!.copyWith(color: placeholder ? context.ci.subtle : null))),
            CiIcon(icon, size: 18, color: context.ci.subtle),
          ]),
        ),
      );
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) => showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: first ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: last ?? DateTime.now().add(const Duration(days: 730)),
    );
