import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/session.dart';
import 'core/theme.dart';
import 'features/auth.dart';
import 'features/chat.dart';
import 'features/careers.dart';
import 'features/forms.dart';
import 'features/home.dart';
import 'features/hr.dart';
import 'features/mail.dart';
import 'features/more.dart';
import 'features/sales.dart';
import 'features/settings.dart';
import 'features/work.dart';
import 'ui/kit.dart';

final rootKey = GlobalKey<NavigatorState>();

GoRoute _r(String path, Widget Function(GoRouterState s) b) => GoRoute(path: path, parentNavigatorKey: rootKey, pageBuilder: (c, s) => MaterialPage(child: b(s)));
int _id(GoRouterState s, [String k = 'id']) => int.tryParse(s.pathParameters[k] ?? '') ?? 0;
int? _q(GoRouterState s, String k) => int.tryParse(s.uri.queryParameters[k] ?? '');

final router = GoRouter(
  navigatorKey: rootKey,
  initialLocation: '/home',
  refreshListenable: Session.I,
  redirect: (c, s) {
    final inLogin = s.matchedLocation == '/login';
    if (Session.I.booting) return null;
    if (!Session.I.signedIn) return inLogin ? null : '/login';
    if (inLogin) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    StatefulShellRoute.indexedStack(
      builder: (c, s, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/chat', builder: (c, s) => const ChatListScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/me', builder: (c, s) => const MyFileScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (c, s) => const MoreScreen())]),
      ],
    ),
    _r('/search', (s) => const SearchScreen()),
    _r('/notifications', (s) => const NotificationsScreen()),
    _r('/settings', (s) => const SettingsScreen()),
    _r('/tasks/new', (s) => NewTaskScreen(projectId: int.tryParse(s.uri.queryParameters['project'] ?? ''))),
    _r('/tasks/:id', (s) => TaskScreen(id: _id(s))),
    _r('/tasks/:id/edit', (s) => NewTaskScreen(taskId: _id(s))),
    _r('/projects', (s) => const ProjectsScreen()),
    _r('/projects/new', (s) => ProjectFormScreen(organizationId: _q(s, 'organization'))),
    _r('/projects/:id', (s) => ProjectScreen(id: _id(s))),
    _r('/projects/:id/edit', (s) => ProjectFormScreen(id: _id(s))),
    _r('/tickets', (s) => const TicketsScreen()),
    _r('/tickets/new', (s) => NewTicketScreen(organizationId: _q(s, 'organization'), projectId: _q(s, 'project'))),
    _r('/tickets/:id', (s) => TicketScreen(id: _id(s))),
    _r('/support-packages', (s) => const PackagesScreen()),
    _r('/crm-settings', (s) => const CrmSettingsScreen()),
    _r('/crm-settings/:kind', (s) => settingsSection(s.pathParameters['kind'] ?? '')),
    _r('/invoices', (s) => const InvoicesScreen()),
    _r('/invoices/new', (s) => InvoiceFormScreen(organizationId: _q(s, 'organization'), projectId: _q(s, 'project'))),
    _r('/invoices/:id', (s) => InvoiceScreen(id: _id(s))),
    _r('/invoices/:id/edit', (s) => InvoiceFormScreen(id: _id(s))),
    _r('/leads', (s) => const LeadsBoardScreen()),
    _r('/leads/new', (s) => NewLeadScreen(personId: _q(s, 'person'))),
    _r('/leads/:id', (s) => LeadScreen(id: _id(s))),
    _r('/persons', (s) => const PersonsScreen()),
    _r('/persons/new', (s) => NewPersonScreen(organizationId: _q(s, 'organization'))),
    _r('/persons/:id', (s) => PersonScreen(id: _id(s))),
    _r('/organizations', (s) => const OrganizationsScreen()),
    _r('/organizations/new', (s) => const NewOrganizationScreen()),
    _r('/organizations/:id', (s) => OrganizationScreen(id: _id(s))),
    _r('/activities', (s) => const ActivitiesScreen()),
    _r('/activities/new', (s) => NewActivityScreen(leadId: int.tryParse(s.uri.queryParameters['lead'] ?? ''), personId: int.tryParse(s.uri.queryParameters['person'] ?? ''))),
    _r('/quotes', (s) => const QuotesScreen()),
    _r('/quotes/:id', (s) => QuoteScreen(id: _id(s))),
    _r('/products', (s) => const ProductsScreen()),
    _r('/mail', (s) => const MailScreen()),
    _r('/mail/compose', (s) => ComposeScreen(to: s.uri.queryParameters['to'], subject: s.uri.queryParameters['subject'], parentId: int.tryParse(s.uri.queryParameters['parent'] ?? ''))),
    _r('/mail/:folder/:id', (s) => MailViewScreen(folder: s.pathParameters['folder'] ?? 'inbox', id: _id(s))),
    _r('/chat/new', (s) => const NewChatScreen()),
    _r('/chat/monitor', (s) => const ChatMonitorScreen()),
    _r('/chat/monitor/:id', (s) => MonitorConversationScreen(id: _id(s), title: s.uri.queryParameters['t'] ?? '')),
    _r('/chat/:id', (s) => ConversationScreen(id: _id(s), title: s.uri.queryParameters['t'] ?? '')),
    _r('/hr/leaves', (s) => const LeavesScreen()),
    _r('/hr/leaves/new', (s) => const NewLeaveScreen()),
    _r('/hr/employees', (s) => const EmployeesScreen()),
    _r('/hr/employees/:id', (s) => EmployeeScreen(id: _id(s))),
    _r('/hr/attendance', (s) => const AttendanceScreen()),
    _r('/hr/payroll', (s) => const PayrollScreen()),
    _r('/hr/payslips/:id', (s) => PayslipScreen(id: _id(s))),
    _r('/careers', (s) => const CareersScreen()),
    _r('/careers/:id', (s) => ApplicationScreen(id: _id(s))),
  ],
);

/// Bottom bar: الرئيسية · المهام · الشات · ملفي · المزيد (tabs the person can't open are hidden).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final s = Session.I;
    final tabs = <(int, String, String)>[
      (0, 'home', 'الرئيسية'),
      if (s.can('team_tasks')) (1, 'tasks', 'المهام'),
      if (s.can('chat')) (2, 'chat', 'الشات'),
      if (s.can('hr_me')) (3, 'staff', 'ملفي'),
      (4, 'dots', 'المزيد'),
    ];
    final current = tabs.indexWhere((t) => t.$1 == shell.currentIndex);
    return Scaffold(
      body: shell,
      bottomNavigationBar: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Container(
          decoration: BoxDecoration(color: context.ci.surface, border: Border(top: BorderSide(color: context.ci.line))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _Tab(
                      icon: tabs[i].$2,
                      label: tabs[i].$3,
                      active: i == (current < 0 ? 0 : current),
                      badge: tabs[i].$1 == 2 ? s.unreadChat : (tabs[i].$1 == 0 ? s.unreadNotices : 0),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        shell.goBranch(tabs[i].$1, initialLocation: tabs[i].$1 == shell.currentIndex);
                      },
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.active, required this.onTap, this.badge = 0});
  final String icon, label;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = active ? context.ci.ink : context.ci.subtle;
    return InkWell(
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 18 : 0,
          height: 3,
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(color: context.ci.brand, borderRadius: BorderRadius.circular(1)),
        ),
        Stack(clipBehavior: Clip.none, children: [
          CiIcon(icon, size: 22, color: active ? context.ci.brand : color),
          if (badge > 0)
            PositionedDirectional(
              end: -9,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(color: context.ci.brand, borderRadius: BorderRadius.circular(4), border: Border.all(color: context.ci.surface, width: 1.5)),
                child: Text(badge > 99 ? '99+' : '$badge', textAlign: TextAlign.center, style: TextStyle(fontFamily: kDisplay, fontSize: 9.5, fontWeight: FontWeight.w700, color: context.ci.onBrand, height: 1.3)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontFamily: kFont, fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: color)),
      ]),
    );
  }
}
