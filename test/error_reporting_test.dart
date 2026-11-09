import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/errors/error_hooks.dart';
import 'package:flutter_starter/errors/error_reference.dart';
import 'package:flutter_starter/errors/error_reporter.dart';
import 'package:flutter_starter/errors/scrub.dart';
import 'package:flutter_starter/theme/app_theme.dart';
import 'package:flutter_starter/widgets/error_view.dart';

class _Harness {
  _Harness({Uri? endpoint}) {
    reporter = ErrorReporter(
      endpoint: endpoint ?? Uri.parse('https://errors.test/clientErrors'),
      release: 'abc1234',
      transport: (_, body) async =>
          sent.add(jsonDecode(body) as Map<String, Object?>),
      route: () => '/docs/7?token=secret',
      now: () => DateTime.utc(2026, 11, 9, 10),
      log: logged.add,
      flushDelay: const Duration(hours: 1),
    );
  }

  late final ErrorReporter reporter;
  final List<Map<String, Object?>> sent = [];
  final List<String> logged = [];

  List<Map<String, Object?>> get events => [
        for (final b in sent)
          ...(b['events'] as List).cast<Map<String, Object?>>(),
      ];
}

void main() {
  group('error references', () {
    test('are six characters a person can read aloud', () {
      for (var i = 0; i < 200; i++) {
        final ref = newErrorReference();
        expect(ref, matches(RegExp(r'^[A-Z2-9]{6}$')));
        expect(ref, isNot(matches(RegExp('[01ILOUV]'))));
        expect(isErrorReference(ref), isTrue);
      }
      expect(newErrorReference(Random(1)), hasLength(6));
    });

    test('refuse what is not one', () {
      for (final bad in ['', 'abc123', 'K7PQ2', 'O0O0O0', 123456, null]) {
        expect(isErrorReference(bad), isFalse);
      }
    });
  });

  group('scrubText', () {
    test('removes secrets and personal details', () {
      const input = 'failed for anna@example.com password=hunter22 '
          'Bearer ya29.a0AfH6SMBx12345678 '
          'https://app.web.app/reset?oobCode=abc123';
      final out = scrubText(input);
      for (final secret in [
        'anna@example.com',
        'hunter22',
        'ya29',
        'oobCode'
      ]) {
        expect(out, isNot(contains(secret)));
      }
    });

    test('keeps the path of a route only', () {
      expect(scrubRoute('/sign-in?email=a@b.se#x'), '/sign-in');
      expect(scrubRoute(null), isNull);
    });
  });

  group('clientErrorsEndpoint', () {
    test("is the function in the app's own project", () {
      expect(
        clientErrorsEndpoint(projectId: 'acme-sign').toString(),
        'https://europe-west1-acme-sign.cloudfunctions.net/clientErrors',
      );
    });

    test('prefers an explicit address, and is null without either', () {
      expect(
        clientErrorsEndpoint(
                url: 'http://10.0.2.2:5001/p/europe-west1/clientErrors',
                projectId: 'x')
            .toString(),
        'http://10.0.2.2:5001/p/europe-west1/clientErrors',
      );
      expect(clientErrorsEndpoint(url: '', projectId: ''), isNull);
    });
  });

  group('ErrorReporter', () {
    test('makes one structured event with a reference and sends it', () async {
      final h = _Harness();
      final ref =
          h.reporter.report(StateError('no booking'), StackTrace.current);
      expect(isErrorReference(ref), isTrue);
      expect(h.logged.single, startsWith('[client-error] Reference $ref'));

      await h.reporter.flush();
      expect(h.sent.single['v'], 1);
      expect(h.events.single, containsPair('ref', ref));
      expect(h.events.single, containsPair('severity', 'ERROR'));
      expect(h.events.single, containsPair('kind', 'manual'));
      expect(h.events.single, containsPair('type', 'StateError'));
      expect(h.events.single, containsPair('route', '/docs/7'));
      expect(h.events.single, containsPair('release', 'abc1234'));
      expect(h.events.single, containsPair('ts', '2026-11-09T10:00:00.000Z'));
      expect(h.events.single['stack'], isA<String>());
    });

    test('gives the same error the same reference and sends it once', () async {
      final h = _Harness();
      final err = StateError('boom');
      final stack = StackTrace.current;
      expect(h.reporter.report(err, stack), h.reporter.report(err, stack));
      await h.reporter.flush();
      expect(h.events, hasLength(1));
    });

    test('adds the signed-in uid, never an email', () async {
      final h = _Harness();
      h.reporter.uid = 'uid_123';
      h.reporter.report(StateError('failed for anna@example.com'), null);
      await h.reporter.flush();
      expect(h.events.single['uid'], 'uid_123');
      expect(jsonEncode(h.sent), isNot(contains('anna@example.com')));
    });

    test('never logs the contents of a thrown object', () async {
      final h = _Harness();
      h.reporter.report({'email': 'a@b.se', 'body': 'contract'}, null);
      await h.reporter.flush();
      expect(jsonEncode(h.sent), isNot(contains('contract')));
    });

    test('caps one session and splits batches', () async {
      final h = _Harness();
      for (var i = 0; i < maxEventsPerSession + 5; i++) {
        h.reporter.report(StateError('e$i'), null);
      }
      await h.reporter.flush();
      expect(h.events, hasLength(maxEventsPerSession));
      expect(
        h.sent.map((b) => (b['events'] as List).length).reduce(max),
        maxEventsPerBatch,
      );
    });

    test('only logs without an endpoint', () async {
      final h = _Harness()..reporter.endpoint = null;
      h.reporter.report(StateError('offline'), null);
      await h.reporter.flush();
      expect(h.sent, isEmpty);
      expect(h.logged, hasLength(1));
    });
  });

  group('error hooks', () {
    testWidgets('report framework errors and keep the previous handler', (
      tester,
    ) async {
      final h = _Harness();
      final seen = <FlutterErrorDetails>[];
      final originalFlutter = FlutterError.onError;
      final originalPlatform = PlatformDispatcher.instance.onError;
      FlutterError.onError = seen.add;
      addTearDown(() {
        FlutterError.onError = originalFlutter;
        PlatformDispatcher.instance.onError = originalPlatform;
      });

      installErrorHooks(reporter: h.reporter, replaceErrorWidget: false);
      FlutterError.reportError(
        FlutterErrorDetails(
            exception: StateError('layout'), stack: StackTrace.current),
      );
      expect(
          PlatformDispatcher.instance.onError!(
              StateError('async'), StackTrace.current),
          isTrue);

      await h.reporter.flush();
      expect(seen, hasLength(1));
      expect(h.events.map((e) => e['kind']), ['flutter', 'uncaught']);
    });
  });

  group('ErrorView', () {
    testWidgets('shows the reference to quote', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: ErrorView(message: 'Could not load.', reference: 'K7PQ2M'),
          ),
        ),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Reference K7PQ2M'), findsOneWidget);
    });

    testWidgets('a failed widget says so with its reference', (tester) async {
      await tester.pumpWidget(const ReportedErrorWidget(reference: 'K7PQ2M'));
      expect(
          find.text('Something went wrong. Reference K7PQ2M'), findsOneWidget);
    });
  });
}
