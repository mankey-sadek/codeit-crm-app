import 'dart:io';
import 'dart:math';

import 'package:codeit_crm/core/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG relative luminance / contrast ratio.
double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  group('text is readable in both themes (WCAG AA)', () {
    for (final t in [Ci.darkTokens, Ci.lightTokens]) {
      final name = t.dark ? 'dark' : 'light';
      final backgrounds = {'bg': t.bg, 'surface': t.surface, 'sunken': t.sunken, 'raised': t.raised};
      // body text 4.5:1, small secondary text and icons at least 4.5:1 too (they carry information)
      final texts = {'ink': t.ink, 'muted': t.muted, 'subtle': t.subtle, 'brand': t.brand};
      for (final bg in backgrounds.entries) {
        for (final tx in texts.entries) {
          test('$name: ${tx.key} on ${bg.key}', () {
            expect(contrast(tx.value, bg.value), greaterThanOrEqualTo(4.5), reason: '${tx.key} on ${bg.key} in $name');
          });
        }
      }
      // coloured labels (pills, chips) sit on their soft background
      final pairs = {
        'brand/brandSoft': (t.brand, t.brandSoft), 'success/successSoft': (t.success, t.successSoft), 'attn/attnSoft': (t.attn, t.attnSoft),
        'info/infoSoft': (t.info, t.infoSoft), 'danger/dangerSoft': (t.danger, t.dangerSoft), 'warning/warningSoft': (t.warning, t.warningSoft),
        'onBrand/brand (buttons)': (t.onBrand, t.brand), 'ink/brandSoft': (t.ink, t.brandSoft),
      };
      for (final p in pairs.entries) {
        test('$name: ${p.key}', () => expect(contrast(p.value.$1, p.value.$2), greaterThanOrEqualTo(4.5), reason: '${p.key} in $name'));
      }
    }
  });

  test('every icon the app names has an svg', () {
    final names = <String>{};
    final patterns = [
      RegExp(r"CiIcon\('([a-z_]+)'"), // CiIcon('bell')
      RegExp(r"icon: '([a-z_]+)'"), // EmptyState(..., icon: 'lock'), PickBox(icon: 'users')
      RegExp(r"\(\d+, '([a-z_]+)', '"), // bottom bar tabs: (2, 'chat', 'الشات')
      RegExp(r"\('[a-z_]+', '([a-z_]+)', '[^']*', '/"), // More menu: ('leads', 'chart', 'الفرص', '/leads')
      RegExp(r"': \('([a-z_]+)', '"), // settings sections: 'users': ('users', 'المستخدمين', ...)
    ];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final p in patterns) {
        for (final m in p.allMatches(src)) {
          names.add(m.group(1)!);
        }
      }
    }
    expect(names, isNotEmpty);
    final missing = names.where((n) => !File('assets/icons/$n.svg').existsSync()).toList()..sort();
    expect(missing, isEmpty, reason: 'icons named in the code without assets/icons/<name>.svg');
  });
}
