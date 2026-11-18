import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../core/fmt.dart' as f;
import '../core/theme.dart';

/* ------------------------------------------------------------------ brand */

/// The code it mark, drawn so it takes the theme's ink and dot colours.
class CiMark extends StatelessWidget {
  const CiMark({super.key, this.size = 28, this.ink, this.dot});
  final double size;
  final Color? ink, dot;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MarkPainter(ink ?? context.ci.ink, dot ?? context.ci.brand));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.ink, this.dot);
  final Color ink, dot;
  @override
  void paint(Canvas c, Size s) {
    // viewBox 8 6 80 86
    final k = s.height / 86;
    c.save();
    c.translate((s.width - 80 * k) / 2 - 8 * k, -6 * k);
    c.scale(k);
    final p = Path()
      ..moveTo(58, 20)
      ..lineTo(40, 20)
      ..arcToPoint(const Offset(18, 42), radius: const Radius.circular(22), clockwise: false)
      ..lineTo(18, 60)
      ..arcToPoint(const Offset(40, 82), radius: const Radius.circular(22), clockwise: false)
      ..lineTo(62, 82)
      ..arcToPoint(const Offset(78, 66), radius: const Radius.circular(16), clockwise: false)
      ..lineTo(78, 50);
    c.drawPath(p, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 14);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(71, 13, 14, 14), const Radius.circular(2)), Paint()..color = dot);
    c.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.ink != ink || o.dot != dot;
}

/// Brand line icons (code-it-assets/icons), coloured like text.
class CiIcon extends StatelessWidget {
  const CiIcon(this.name, {super.key, this.size = 22, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? context.ci.ink;
    return SvgPicture.asset('assets/icons/$name.svg', width: size, height: size, colorFilter: ColorFilter.mode(c, BlendMode.srcIn));
  }
}

/// Small blinking block caret, the brand's "cursor".
class Caret extends StatefulWidget {
  const Caret({super.key, this.height = 14, this.width = 7});
  final double height, width;
  @override
  State<Caret> createState() => _CaretState();
}

class _CaretState extends State<Caret> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, __) => Opacity(
          opacity: MediaQuery.of(context).disableAnimations || _a.value < .5 ? 1 : 0,
          child: Container(width: widget.width, height: widget.height, color: context.ci.brand),
        ),
      );
}

/* ------------------------------------------------------------------ text bits */

TextStyle mono(BuildContext c, {double size = 12, Color? color, FontWeight w = FontWeight.w500}) =>
    TextStyle(fontFamily: kMono, fontSize: size, color: color ?? c.ci.subtle, fontWeight: w, height: 1.3);

TextStyle numStyle(BuildContext c, {double size = 22, Color? color, FontWeight w = FontWeight.w600}) =>
    TextStyle(fontFamily: kDisplay, fontSize: size, color: color ?? c.ci.ink, fontWeight: w, height: 1.15, fontFeatures: const [FontFeature.tabularFigures()]);

/// "■ label" small mono eyebrow above titles.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color ?? context.ci.brand, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: mono(context, size: 11.5, color: context.ci.subtle), overflow: TextOverflow.ellipsis)),
      ]);
}

/* ------------------------------------------------------------------ tones + pills */

enum Tone { brand, info, attn, danger, warning, muted, success }

(Color, Color) toneColors(BuildContext c, Tone t) => switch (t) {
      Tone.brand => (c.ci.brand, c.ci.brandSoft),
      Tone.success => (c.ci.success, c.ci.successSoft),
      Tone.info => (c.ci.info, c.ci.infoSoft),
      Tone.attn => (c.ci.attn, c.ci.attnSoft),
      Tone.danger => (c.ci.danger, c.ci.dangerSoft),
      Tone.warning => (c.ci.warning, c.ci.warningSoft),
      Tone.muted => (c.ci.muted, c.ci.sunken),
    };

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.muted, this.dense = false});
  final String text;
  final Tone tone;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final (fg, bg) = toneColors(context, tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontFamily: kFont, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w600, color: fg, height: 1.2)),
      ]),
    );
  }
}

Tone taskTone(String s) => switch (s) { 'doing' => Tone.info, 'review' => Tone.attn, 'done' => Tone.success, _ => Tone.muted };
Tone priorityTone(String s) => switch (s) { 'critical' || 'urgent' => Tone.danger, 'high' => Tone.attn, _ => Tone.muted };
Tone ticketTone(String s) => switch (s) { 'open' => Tone.info, 'progress' => Tone.brand, 'waiting' => Tone.warning, 'resolved' => Tone.success, _ => Tone.muted };
Tone leaveTone(String s) => switch (s) { 'pending' => Tone.warning, 'approved' => Tone.success, 'rejected' => Tone.danger, _ => Tone.muted };
Tone invoiceTone(String s) => switch (s) { 'paid' => Tone.success, 'partial' => Tone.info, 'sent' => Tone.attn, _ => Tone.muted };

/* ------------------------------------------------------------------ surfaces */

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.border});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color, border;
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(12);
    return Material(
      color: color ?? context.ci.surface,
      shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: border ?? context.ci.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap == null ? null : () {
        HapticFeedback.selectionClick();
        onTap!();
      }, child: Padding(padding: padding, child: child)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.count});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final int? count;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Text(title, style: context.tt.titleMedium),
          if (count != null) ...[const SizedBox(width: 8), Text('$count', style: mono(context, size: 12))],
          const Spacer(),
          if (action != null) GestureDetector(onTap: onAction, child: Text(action!, style: context.tt.labelMedium!.copyWith(color: context.ci.brand))),
        ]),
      );
}

/// Rounded-square initials avatar.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 36, this.online = false, this.group = false});
  final String name;
  final double size;
  final bool online, group;
  @override
  Widget build(BuildContext context) {
    final hue = name.runes.fold<int>(0, (a, b) => a + b) % 5;
    final palette = [context.ci.brand, context.ci.teal, context.ci.info, context.ci.attn, context.ci.warning];
    final fg = palette[hue];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fg.withValues(alpha: context.ci.dark ? .12 : .14), borderRadius: BorderRadius.circular(size * .28), border: Border.all(color: fg.withValues(alpha: .28))),
          child: group
              ? Icon(Icons.tag_rounded, size: size * .5, color: fg)
              : Text(f.initials(name), style: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: size * .36, color: fg, height: 1)),
        ),
        if (online)
          PositionedDirectional(end: -1, bottom: -1, child: Container(width: size * .3, height: size * .3, decoration: BoxDecoration(color: context.ci.brand, borderRadius: BorderRadius.circular(3), border: Border.all(color: context.ci.surface, width: 2)))),
      ]),
    );
  }
}

/// Segmented 4px progress / stage track.
class StageTrack extends StatelessWidget {
  const StageTrack({super.key, required this.total, required this.done, this.color, this.height = 4});
  final int total, done;
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(total, (i) => Expanded(
              child: Container(
                height: height,
                margin: EdgeInsetsDirectional.only(end: i == total - 1 ? 0 : 3),
                decoration: BoxDecoration(color: i < done ? (color ?? context.ci.brand) : context.ci.line, borderRadius: BorderRadius.circular(1)),
              ),
            )),
      );
}

class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.color, this.height = 4});
  final double value; // 0..1
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            Container(color: context.ci.line),
            FractionallySizedBox(widthFactor: value.clamp(0, 1).toDouble(), alignment: AlignmentDirectional.centerStart, child: Container(color: color ?? context.ci.brand)),
          ]),
        ),
      );
}

/// A row of numbers: the brand's KPI strip (no boxes, thin dividers).
class KpiStrip extends StatelessWidget {
  const KpiStrip(this.items, {super.key});
  final List<(String label, String value, Color? color)> items;
  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: IntrinsicHeight(
          child: Row(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: context.ci.line),
              Expanded(
                child: Column(children: [
                  Text(items[i].$2, style: numStyle(context, size: 21, color: items[i].$3)),
                  const SizedBox(height: 4),
                  Text(items[i].$1, style: context.tt.labelSmall, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ],
          ]),
        ),
      );
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.monoValue = false, this.onTap});
  final String k;
  final String v;
  final bool monoValue;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: context.tt.bodySmall)),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: monoValue ? mono(context, size: 13, color: context.ci.ink) : context.tt.bodyMedium!.copyWith(color: onTap != null ? context.ci.brand : null))),
          ]),
        ),
      );
}

/* ------------------------------------------------------------------ states */

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, {super.key, this.body, this.icon = 'check'});
  final String title;
  final String? body;
  final String icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.ci.line)),
            alignment: Alignment.center,
            child: CiIcon(icon, color: context.ci.subtle),
          ),
          const SizedBox(height: 16),
          Text(title, style: context.tt.titleSmall, textAlign: TextAlign.center),
          if (body != null) ...[const SizedBox(height: 6), Text(body!, style: context.tt.bodySmall, textAlign: TextAlign.center)],
        ]),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.ci.sunken, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.ci.line)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('> ', style: mono(context, size: 13, color: context.ci.brand)),
              Flexible(child: Text('error: $message', style: mono(context, size: 12.5, color: context.ci.danger))),
            ]),
          ),
          if (onRetry != null) ...[const SizedBox(height: 16), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('حاول تاني'))],
        ]),
      );
}

/// Grey placeholder blocks while loading.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.rows = 6});
  final int rows;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .45, end: 1.0).animate(_a),
        child: Column(children: List.generate(widget.rows, (i) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: i == 0 ? 92 : 64,
              decoration: BoxDecoration(color: context.ci.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.ci.line)),
            ))),
      );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  if (msg.isEmpty) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Container(width: 6, height: 6, color: error ? context.ci.danger : context.ci.brand),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      duration: Duration(milliseconds: error ? 4200 : 2600),
    ));
}
