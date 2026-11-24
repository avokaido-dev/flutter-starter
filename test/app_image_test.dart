import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Relative on purpose: a new app renames this package (pubspec.yaml), and a
// relative import keeps this test compiling under any name.
// ignore: avoid_relative_lib_imports
import '../lib/app_image.dart';

const _base = 'https://storage.googleapis.com/avo-media-stage/apps/m1';

Widget _host(Widget child, {double width = 360, double height = 270}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

void main() {
  group('isValidSlot', () {
    for (final slot in <String>[
      'hero',
      'home/hero',
      'products/wool-coat-black',
      'team/member-2',
      'a/b/c-1/d',
      'x' * maxSlotLength,
    ]) {
      test('accepts "$slot"', () => expect(isValidSlot(slot), isTrue));
    }

    for (final slot in <String>[
      '',
      'Home/hero',
      'home_hero',
      'home hero',
      'home/hero.webp',
      '/home',
      'home/',
      'home//hero',
      '-home',
      'home-',
      'home--hero',
      '../secret',
      'ö',
      'x' * (maxSlotLength + 1),
    ]) {
      test('refuses "$slot"', () => expect(isValidSlot(slot), isFalse));
    }
  });

  group('appImageUrl', () {
    test('puts the slot under the base as WebP', () {
      expect(
        appImageUrl('products/wool-coat-black', base: _base),
        '$_base/products/wool-coat-black.webp',
      );
    });

    test('drops a trailing slash on the base', () {
      expect(
          appImageUrl('home/hero', base: '$_base/'), '$_base/home/hero.webp');
    });

    test('reads AVO_MEDIA_BASE from the build by default', () {
      // `flutter test` is run without --dart-define, so the base is empty.
      expect(avoMediaBase, isEmpty);
      expect(appImageUrl('home/hero'), '/home/hero.webp');
    });

    test('asserts the slot in debug', () {
      expect(
        () => appImageUrl('Home Hero', base: _base),
        throwsA(
          isA<AssertionError>().having(
            (e) => '${e.message}',
            'message',
            contains('Home Hero'),
          ),
        ),
      );
    });
  });

  test('every aspect is one avokaido/images.json accepts', () {
    expect(
      AppImageAspect.values.map((a) => a.manifestValue),
      <String>['1:1', '4:3', '16:9', '3:4'],
    );
    expect(AppImageAspect.wide.ratio, 16 / 9);
  });

  test('avokaido/images.json ships as an empty list for the runner', () {
    final manifest = jsonDecode(
      File('avokaido/images.json').readAsStringSync(),
    );
    expect(manifest, isEmpty);
    expect(manifest, isA<List<dynamic>>());
  });

  group('AppImage', () {
    testWidgets('without a base shows the waiting card and asks for nothing',
        (tester) async {
      await tester.pumpWidget(
        _host(const AppImage('home/hero', semanticLabel: 'A sunny shop')),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text(defaultPendingLabel), findsOneWidget);
      expect(
        find.bySemanticsLabel('A sunny shop$pendingSemanticsSuffix'),
        findsOneWidget,
      );
    });

    testWidgets('shows the waiting card while the picture loads',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const AppImage('home/hero',
              semanticLabel: 'A sunny shop', base: _base),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, '$_base/home/hero.webp');
      expect(find.text(defaultPendingLabel), findsOneWidget);
      expect(
        find.bySemanticsLabel('A sunny shop$pendingSemanticsSuffix'),
        findsOneWidget,
      );
    });

    testWidgets('shows the waiting card, not an error, when the address fails',
        (tester) async {
      // flutter_test answers every HTTP request with 400, like a picture
      // that is not there yet.
      await tester.pumpWidget(
        _host(const AppImage('home/hero', semanticLabel: 'Shop', base: _base)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(defaultPendingLabel), findsOneWidget);
    });

    testWidgets('takes the waiting words in the app\'s language',
        (tester) async {
      await tester.pumpWidget(
        _host(const AppImage('home/hero', pendingLabel: 'Bilden skapas…')),
      );
      expect(find.text('Bilden skapas…'), findsOneWidget);
      expect(find.text(defaultPendingLabel), findsNothing);
    });

    testWidgets('shows only the icon on a thumbnail', (tester) async {
      await tester.pumpWidget(
        _host(const AppImage('home/hero'), width: 96, height: 96),
      );
      expect(find.text(defaultPendingLabel), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('keeps its aspect in a column', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ListView(
                children: const <Widget>[
                  AppImage('home/hero', aspect: AppImageAspect.wide),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppImage)), const Size(320, 180));
    });
  });
}
