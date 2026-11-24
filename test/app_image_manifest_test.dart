import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every generated picture the code asks for must be listed in
// avokaido/images.json. Avokaido only makes the pictures listed there; a slot
// the code uses but the manifest lacks stays "Generating picture…" forever.
//
// This scans lib/ for slots written as plain strings:
//
//   appImageUrl('home/hero')   AppImage('home/hero', …)   (either quote)
//
// A slot built at run time (an interpolated string such as
// 'products/${p.slug}', or a variable) cannot be checked here. List every
// value it can take in avokaido/images.json by hand.

/// The helpers themselves: their doc comments show example slots.
const _helpers = <String>{'lib/app_image.dart', 'lib/app_image_base.dart'};

final _patterns = <RegExp>[
  RegExp(r'''\bappImageUrl\(\s*(['"])((?:(?!\1)[^\\\n])*)\1'''),
  RegExp(r'''\bAppImage\(\s*(['"])((?:(?!\1)[^\\\n])*)\1'''),
];

/// The slots [source] names as plain strings, with their line. A string with
/// `$` interpolates, so its value is only known at run time: skipped.
List<({String slot, int line})> findSlots(String source) {
  final found = <({String slot, int line, int at})>[];
  for (final pattern in _patterns) {
    for (final match in pattern.allMatches(source)) {
      final slot = match.group(2)!;
      if (slot.contains(r'$')) continue;
      final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
      found.add((slot: slot, line: line, at: match.start));
    }
  }
  found.sort((a, b) => a.at.compareTo(b.at));
  return [for (final f in found) (slot: f.slot, line: f.line)];
}

void main() {
  group('findSlots', () {
    test('finds appImageUrl and AppImage with either quote', () {
      const source = "final a = appImageUrl('home/hero');\n"
          'final b = appImageUrl("products/wool-coat");\n'
          "const c = AppImage('team/anna', fit: BoxFit.cover);\n"
          'AppImage(\n'
          "  'home/banner',\n"
          ');\n';
      expect(findSlots(source), [
        (slot: 'home/hero', line: 1),
        (slot: 'products/wool-coat', line: 2),
        (slot: 'team/anna', line: 3),
        (slot: 'home/banner', line: 4),
      ]);
    });

    test('skips slots built at run time', () {
      const source = r"appImageUrl('products/${p.slug}');"
          '\n'
          r"AppImage('team/$id');"
          '\n'
          'AppImage(product.slot);\n'
          'AppImagePending();\n';
      expect(findSlots(source), isEmpty);
    });
  });

  test('avokaido/images.json lists every picture slot the code uses', () {
    final manifest = jsonDecode(
      File('avokaido/images.json').readAsStringSync(),
    );
    final listed = <String>{
      if (manifest is List)
        for (final entry in manifest)
          if (entry is Map) '${entry['slot']}',
    };

    final missing = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (_helpers.contains(path)) continue;
      for (final use in findSlots(file.readAsStringSync())) {
        if (!listed.contains(use.slot)) {
          missing.add('  ${use.slot}  ($path:${use.line})');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: [
        'These picture slots are used in the code but not listed in '
            'avokaido/images.json, so Avokaido will never make them:',
        ...missing,
        'Add one entry per slot: {"slot", "prompt", "alt", '
            '"aspect": "1:1" | "4:3" | "16:9" | "3:4"}.',
        'Slots built at run time (interpolated strings, variables) are not '
            'checked here: list every value they can take by hand.',
      ].join('\n'),
    );
  });
}
