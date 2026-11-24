import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../features/more.dart';
import '../router.dart';
import 'kit.dart';

/// From this width (a Mac window, a tablet on its side) the app shows a sidebar instead of the
/// bottom bar, and pages keep a comfortable reading width.
const kWideFrom = 900.0;
const kPageMax = 880.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= kWideFrom;

/// Wraps every screen. On a narrow window it does nothing (the phone layout). On a wide one:
/// a sidebar with every module the person can open, and the page centred next to it.
class DesktopFrame extends StatefulWidget {
  const DesktopFrame({super.key, required this.child});
  final Widget child;

  @override
  State<DesktopFrame> createState() => _DesktopFrameState();
}

class _DesktopFrameState extends State<DesktopFrame> {
  late final Listenable _changes = Listenable.merge([Session.I, router.routerDelegate, router.routeInformationProvider]);

  // the router tells about a new page while it is still building it: redraw the sidebar after that frame
  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _changes.addListener(_changed);
  }

  @override
  void dispose() {
    _changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (!isWide(context) || !Session.I.signedIn) return child;
    final ci = context.ci;
    return ColoredBox(
      color: ci.bg,
      child: Row(children: [
        _Sidebar(path: _currentPath()),
        VerticalDivider(width: 1, thickness: 1, color: ci.line),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kPageMax),
              child: DecoratedBox(
                decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: ci.line), end: BorderSide(color: ci.line))),
                child: child,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

String _currentPath() {
  try {
    return router.routeInformationProvider.value.uri.path;
  } catch (_) {
    return '/home';
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final s = Session.I;
    final ci = context.ci;
    final main = <(String, String, String, String, int)>[
      ('', 'home', 'الرئيسية', '/home', s.unreadNotices),
      ('team_tasks', 'tasks', 'المهام', '/tasks', 0),
      ('chat', 'chat', 'الشات', '/chat', s.unreadChat),
      ('hr_me', 'staff', 'ملفي', '/me', 0),
    ];
    // the most specific item that the current page belongs to
    final all = [for (final m in main) m.$4, for (final g in MoreScreen.groups) for (final m in g.$2) m.$4, '/settings'];
    final active = all.where((p) => path == p || path.startsWith('$p/')).fold<String>('', (a, b) => b.length > a.length ? b : a);

    Widget item(String icon, String label, String to, {int badge = 0}) => _Item(icon: icon, label: label, active: to == active, badge: badge, onTap: () {
          HapticFeedback.selectionClick();
          router.go(to);
        });

    return Material(
      color: ci.surface,
      child: SizedBox(
        width: 248,
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Row(children: [
                Container(width: 10, height: 10, color: ci.brand),
                const SizedBox(width: 10),
                Text('code it', style: TextStyle(fontFamily: kDisplay, fontSize: 19, fontWeight: FontWeight.w700, color: ci.ink)),
                const SizedBox(width: 6),
                Text('CRM', style: TextStyle(fontFamily: 'FiraCode', fontSize: 12, color: ci.subtle)),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(10, 0, 10, 12), children: [
                for (final m in main)
                  if (m.$1.isEmpty || s.can(m.$1)) item(m.$2, m.$3, m.$4, badge: m.$5),
                for (final g in MoreScreen.groups)
                  if (g.$2.any((m) => s.can(m.$1))) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 18, 12, 6),
                      child: Text(g.$1, style: TextStyle(fontFamily: kFont, fontSize: 11.5, fontWeight: FontWeight.w600, color: ci.subtle, letterSpacing: .2)),
                    ),
                    for (final m in g.$2.where((m) => s.can(m.$1) && m.$4 != '/tasks')) item(m.$2, m.$3, m.$4),
                  ],
              ]),
            ),
            Divider(height: 1, color: ci.line),
            InkWell(
              onTap: () => router.go('/settings'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(children: [
                  Avatar(s.me?.s('name') ?? '', size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.me?.s('name') ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, fontSize: 13.5, fontWeight: FontWeight.w600, color: ci.ink)),
                      Text(s.me?.s('role') ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: ci.muted)),
                    ]),
                  ),
                  CiIcon('gear', size: 18, color: active == '/settings' ? ci.brand : ci.subtle),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.active, required this.onTap, this.badge = 0});
  final String icon, label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ci = context.ci;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? ci.brandSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              CiIcon(icon, size: 18, color: active ? ci.brand : ci.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(fontFamily: kFont, fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? ci.ink : ci.muted)),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: ci.brand, borderRadius: BorderRadius.circular(4)),
                  child: Text(badge > 99 ? '99+' : '$badge', style: TextStyle(fontFamily: kDisplay, fontSize: 10.5, fontWeight: FontWeight.w700, color: ci.onBrand)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
