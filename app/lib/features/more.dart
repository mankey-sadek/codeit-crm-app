import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../ui/data.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';

/// Every module the signed-in person can open, grouped like the web sidebar.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _groups = <(String, List<(String screen, String icon, String label, String path)>)>[
    ('المبيعات', [
      ('leads', 'chart', 'الفرص', '/leads'),
      ('activities', 'calendar', 'الأجندة', '/activities'),
      ('persons', 'users', 'العملاء', '/persons'),
      ('organizations', 'database', 'الشركات', '/organizations'),
      ('quotes', 'invoice', 'عروض الأسعار', '/quotes'),
      ('products', 'folder', 'المنتجات', '/products'),
    ]),
    ('الشغل', [
      ('projects', 'branch', 'المشاريع', '/projects'),
      ('team_tasks', 'tasks', 'المهام', '/tasks'),
      ('tickets', 'bug', 'التذاكر', '/tickets'),
      ('support_packages', 'clock', 'باقات الدعم', '/support-packages'),
      ('invoices', 'invoice', 'الفواتير', '/invoices'),
      ('mail', 'bell', 'البريد', '/mail'),
    ]),
    ('الفريق', [
      ('hr_employees', 'staff', 'الموظفين', '/hr/employees'),
      ('hr_attendance', 'clock', 'الحضور', '/hr/attendance'),
      ('hr_leaves', 'calendar', 'الإجازات', '/hr/leaves'),
      ('hr_payroll', 'chart', 'المرتبات', '/hr/payroll'),
      ('careers', 'users', 'التوظيف', '/careers'),
      ('chat_monitor', 'shield', 'متابعة الشات', '/chat/monitor'),
    ]),
    ('النظام', [
      ('settings', 'gear', 'إعدادات النظام', '/crm-settings'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final s = Session.I;
    final me = s.me;
    return CiPage(
      title: 'المزيد',
      eyebrow: 'modules',
      back: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Panel(
          onTap: () => context.push('/settings'),
          child: Row(children: [
            Avatar(me?.s('name') ?? '', size: 48),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me?.s('name') ?? '', style: context.tt.titleMedium),
              Text([me?.s('role') ?? '', if (me?.has('department') ?? false) me!.s('department')].where((x) => x.isNotEmpty).join(' · '), style: context.tt.bodySmall),
            ])),
            const CiIcon('gear', size: 20),
          ]),
        ),
        for (final g in _groups)
          if (g.$2.any((m) => s.can(m.$1))) ...[
            SectionTitle(g.$1),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [for (final m in g.$2.where((m) => s.can(m.$1))) _Tile(icon: m.$2, label: m.$3, onTap: () => context.push(m.$4))],
            ),
          ],
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});
  final String icon, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.ci.brandSoft, borderRadius: BorderRadius.circular(8)),
            child: CiIcon(icon, size: 19, color: context.ci.brand),
          ),
          const Spacer(),
          Text(label, style: context.tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Session.I;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final me = s.me;
        return CiPage(
          title: 'الإعدادات',
          eyebrow: 'settings',
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                KV('الاسم', me?.s('name') ?? ''),
                KV('الإيميل', me?.s('email') ?? '', monoValue: true),
                KV('الصلاحية', me?.s('role') ?? ''),
                if (me?.has('employee_code') ?? false) KV('كود الموظف', me!.s('employee_code'), monoValue: true),
              ]),
            ),
            const SectionTitle('الشكل'),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('غامق')),
                ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                ButtonSegment(value: ThemeMode.system, label: Text('زي الموبايل')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setTheme(v.first),
            ),
            const SectionTitle('الحساب'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                KV('غيّر كلمة السر', 'من الموقع', onTap: () => openUrl(kApiBase.replaceFirst('/api/mobile/v1', '/admin/account'))),
                KV('الإصدار', 'build $kAppBuild${kDemo ? ' · تجريبي' : ''}', monoValue: true),
              ]),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: context.ci.danger, side: BorderSide(color: context.ci.danger.withValues(alpha: .5))),
              onPressed: () async {
                if (!await confirm(context, 'تسجّل خروج؟', yes: 'خروج', danger: true)) return;
                await s.logout();
                if (context.mounted) context.go('/login');
              },
              child: const Text('تسجيل خروج'),
            ),
            const SizedBox(height: 24),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const CiMark(size: 18), const SizedBox(width: 8), Text('code it', style: mono(context, size: 12))])),
          ]),
        );
      },
    );
  }
}
