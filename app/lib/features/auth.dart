import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../ui/kit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false, hide = true;
  String? error;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() => error = 'اكتب الإيميل وكلمة السر.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Session.I.login(email.text, pass.text);
    } on ApiError catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ci = context.ci;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Grid(ci.line.withValues(alpha: ci.dark ? .5 : .7), ci.brandSoft))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: ci.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: ci.line)),
                      child: const CiMark(size: 30),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('code it CRM', style: TextStyle(fontFamily: kDisplay, fontSize: 18, fontWeight: FontWeight.w600, color: ci.ink)),
                      Text('crm.coditvision.com', style: mono(context, size: 11.5)),
                    ]),
                  ]),
                  const SizedBox(height: 44),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(color: ci.sunken, borderRadius: BorderRadius.circular(10), border: Border.all(color: ci.line)),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [for (var i = 0; i < 3; i++) Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: ci.line, borderRadius: BorderRadius.circular(2)))]),
                        const SizedBox(height: 10),
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '> ', style: mono(context, size: 13, color: ci.brand)),
                          TextSpan(text: 'login --team code-it', style: mono(context, size: 13, color: ci.muted)),
                        ])),
                        const SizedBox(height: 4),
                        Row(children: [Text('> ', style: mono(context, size: 13, color: ci.brand)), const Caret(height: 14)]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text.rich(TextSpan(style: context.tt.displaySmall!.copyWith(fontSize: 28), children: [
                    const TextSpan(text: 'أهلاً بيك.\nسجّل دخولك '),
                    TextSpan(text: 'وكمّل شغلك', style: TextStyle(color: ci.brand)),
                  ])),
                  const SizedBox(height: 10),
                  Text('نفس الإيميل وكلمة السر بتوع الـ CRM على الويب.', style: context.tt.bodyMedium!.copyWith(color: ci.muted)),
                  const SizedBox(height: 28),
                  _label(context, 'الإيميل'),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'name@coditvision.com'),
                  ),
                  const SizedBox(height: 16),
                  _label(context, 'كلمة السر'),
                  TextField(
                    controller: pass,
                    obscureText: hide,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: ci.subtle), onPressed: () => setState(() => hide = !hide)),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: error == null
                        ? const SizedBox(height: 0)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: ci.dangerSoft, borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: ci.danger), const SizedBox(width: 8), Expanded(child: Text(error!, style: context.tt.bodyMedium!.copyWith(color: ci.danger)))]),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: ci.onBrand))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('دخول'), SizedBox(width: 10), Icon(Icons.arrow_back_rounded, size: 20)]),
                  ),
                  const SizedBox(height: 40),
                  Center(child: Text('نسيت كلمة السر؟ كلّم مدير النظام.', style: context.tt.bodySmall)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _label(BuildContext c, String t) => Padding(padding: const EdgeInsets.only(bottom: 8, right: 2), child: Text(t, style: c.tt.labelMedium));
}

class _Grid extends CustomPainter {
  _Grid(this.line, this.glow);
  final Color line, glow;
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..shader = RadialGradient(center: const Alignment(0, -1.1), radius: 1.1, colors: [glow, glow.withValues(alpha: 0)]).createShader(Offset.zero & s));
    final p = Paint()..color = line..strokeWidth = 1;
    for (double y = 32; y < s.height; y += 32) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Grid o) => o.line != line;
}
