/// The one place an app error goes, so an admin can find it later.
///
/// Every error the app does not handle (a Flutter framework error, an
/// uncaught exception, a failed future) becomes ONE structured event with a
/// short reference. It is printed to the device log and sent in batches to the
/// `clientErrors` function in this app's own Firebase project, which writes
/// it to the project's Cloud Logging at severity ERROR, labelled
/// `log=client-errors`. That is where Avokaido's investigator and the app's IT
/// admin look; `docs/errors.md` says how to find one.
///
/// ```dart
/// final ref = reportError(e, stack);               // a catch that gives up
/// return ErrorView(message: '…', reference: ref);  // and the screen shows it
/// ```
///
/// Reporting never throws and never blocks: an app that cannot reach its
/// logging must still work. With no endpoint configured the event goes to the
/// device log only.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'error_reference.dart';
import 'scrub.dart';

/// Region every function in the app's project runs in.
const String functionsRegion = 'europe-west1';

/// The function the web starter deploys (`functions/src/client-errors`).
const String clientErrorsFunction = 'clientErrors';

/// At most this many events leave one app session; the rest stay in the log.
const int maxEventsPerSession = 30;

/// At most this many events in one request. The function refuses more.
const int maxEventsPerBatch = 10;

/// `--dart-define=CLIENT_ERRORS_URL=…`: where to send, overriding the rest.
const String _definedUrl = String.fromEnvironment('CLIENT_ERRORS_URL');

/// `--dart-define=FIREBASE_PROJECT_ID=…`: the app's own Firebase project.
const String _definedProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

/// `--dart-define=APP_VERSION=…`: which build this is.
const String _definedVersion = String.fromEnvironment('APP_VERSION');

/// Where events are sent, or null to keep them in the device log.
///
/// An explicit [url] wins (an emulator, a custom domain). Otherwise the
/// function's address in the app's own Firebase project, [projectId].
Uri? clientErrorsEndpoint({String? url, String? projectId}) {
  final explicit = (url ?? _definedUrl).trim();
  if (explicit.isNotEmpty) return Uri.tryParse(explicit);
  final project = (projectId ?? _definedProjectId).trim();
  if (project.isEmpty) return null;
  return Uri.https(
    '$functionsRegion-$project.cloudfunctions.net',
    '/$clientErrorsFunction',
  );
}

/// How an error reached us.
enum ErrorKind {
  /// `FlutterError.onError`: a build, layout or paint error.
  flutter,

  /// `PlatformDispatcher.onError`: an exception nothing caught.
  uncaught,

  /// `reportError` called by the app's own code.
  manual,
}

/// One event, as the app sends it. Mirrors `functions/src/client-errors`.
@immutable
class ClientErrorEvent {
  const ClientErrorEvent({
    required this.ref,
    required this.severity,
    required this.kind,
    required this.type,
    required this.message,
    required this.release,
    required this.ts,
    this.stack,
    this.route,
    this.uid,
  });

  final String ref;

  /// `ERROR`, or `WARNING` for an error the app handled.
  final String severity;
  final ErrorKind kind;

  /// The error's type, such as `StateError`.
  final String type;
  final String message;
  final String? stack;

  /// The screen's path, without query or fragment.
  final String? route;
  final String release;

  /// The signed-in user's Firebase uid, when there is one.
  final String? uid;
  final DateTime ts;

  ClientErrorEvent withUid(String? uid) => ClientErrorEvent(
        ref: ref,
        severity: severity,
        kind: kind,
        type: type,
        message: message,
        release: release,
        ts: ts,
        stack: stack,
        route: route,
        uid: uid,
      );

  Map<String, Object?> toJson() => {
        'ref': ref,
        'severity': severity,
        'kind': kind.name,
        'type': type,
        'message': message,
        if (stack != null) 'stack': stack,
        if (route != null) 'route': route,
        'release': release,
        if (uid != null) 'uid': uid,
        'ts': ts.toUtc().toIso8601String(),
      };
}

/// Sends one JSON body. Swallows its own failures.
typedef ErrorTransport = Future<void> Function(Uri endpoint, String body);

Future<void> _httpTransport(Uri endpoint, String body) async {
  try {
    // text/plain keeps a web build's request "simple": no CORS preflight.
    await http
        .post(
          endpoint,
          headers: {'content-type': 'text/plain; charset=utf-8'},
          body: body,
        )
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    // Nowhere left to report this to. The device log already has the event.
  }
}

/// The reporter behind [reportError]. Its own class so tests can make one.
class ErrorReporter {
  ErrorReporter({
    this.endpoint,
    String? release,
    ErrorTransport? transport,
    this.route,
    DateTime Function()? now,
    void Function(String line)? log,
    this.flushDelay = const Duration(milliseconds: 1500),
  })  : release =
            release ?? (_definedVersion.isEmpty ? 'dev' : _definedVersion),
        _transport = transport ?? _httpTransport,
        _now = now ?? DateTime.now,
        _log = log ?? debugPrint;

  /// Where events go; null keeps them in the device log.
  Uri? endpoint;
  final String release;

  /// The current screen's location, such as `appRouter`'s.
  String? Function()? route;
  final Duration flushDelay;
  final ErrorTransport _transport;
  final DateTime Function() _now;
  final void Function(String line) _log;

  final List<ClientErrorEvent> _queue = [];

  /// Same error, same session: one event, and the same reference.
  final Map<String, String> _seen = {};
  int _sent = 0;
  Timer? _timer;
  String? _uid;

  /// Who is signed in, for the reports that follow. Null after sign-out.
  set uid(String? uid) => _uid = uid;

  /// Records [error] and returns the reference to show the person.
  String report(
    Object error,
    StackTrace? stack, {
    ErrorKind kind = ErrorKind.manual,
    String severity = 'ERROR',
    String? ref,
  }) {
    try {
      final type = errorTypeName(error);
      final message = scrubText(_messageOf(error));
      final stackText = stack == null || stack == StackTrace.empty
          ? null
          : scrubText(stack.toString(), max: maxStackLength);
      final firstFrame = stackText?.split('\n').first ?? '';
      final key = '$type|$message|$firstFrame';
      final earlier = _seen[key];
      if (earlier != null) return earlier;

      final reference = isErrorReference(ref)
          ? ref!
          : (_carriedReference(error) ?? newErrorReference());
      _seen[key] = reference;

      final event = ClientErrorEvent(
        ref: reference,
        severity: severity == 'WARNING' ? 'WARNING' : 'ERROR',
        kind: kind,
        type: type,
        message: message,
        stack: stackText,
        route: scrubRoute(_safeRoute()),
        release: release,
        ts: _now(),
      );
      _log('[client-error] Reference $reference ${jsonEncode(event.toJson())}');

      if (endpoint != null && _sent < maxEventsPerSession) {
        _sent++;
        _queue.add(event);
        _timer ??= Timer(flushDelay, () => unawaited(flush()));
      }
      return reference;
    } catch (_) {
      // Logging must never become the failure.
      return ref ?? newErrorReference();
    }
  }

  /// Sends what is queued.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final target = endpoint;
    if (target == null || _queue.isEmpty) return;
    final batch = List<ClientErrorEvent>.of(_queue);
    _queue.clear();
    for (var i = 0; i < batch.length; i += maxEventsPerBatch) {
      final end = i + maxEventsPerBatch < batch.length
          ? i + maxEventsPerBatch
          : batch.length;
      final events = batch.sublist(i, end).map((e) => e.withUid(_uid));
      final body = jsonEncode({
        'v': 1,
        'platform': _platformName(),
        'events': [for (final e in events) e.toJson()],
      });
      try {
        await _transport(target, body);
      } catch (_) {
        // See the transport: nowhere left to report to.
      }
    }
  }

  String? _safeRoute() {
    try {
      return route?.call();
    } catch (_) {
      return null;
    }
  }
}

/// A readable type name. Only the error's type, never its fields: a thrown
/// object can hold anything, including a whole document.
String errorTypeName(Object error) {
  if (error is FlutterError) return 'FlutterError';
  if (error is StateError) return 'StateError';
  if (error is ArgumentError) return 'ArgumentError';
  if (error is RangeError) return 'RangeError';
  if (error is FormatException) return 'FormatException';
  if (error is TimeoutException) return 'TimeoutException';
  if (error is TypeError) return 'TypeError';
  if (error is NoSuchMethodError) return 'NoSuchMethodError';
  if (error is UnsupportedError) return 'UnsupportedError';
  if (error is UnimplementedError) return 'UnimplementedError';
  if (error is AssertionError) return 'AssertionError';
  if (error is String) return 'String';
  return error.runtimeType.toString();
}

String _messageOf(Object error) {
  if (error is Exception || error is Error || error is String) {
    return error.toString();
  }
  return 'Non-Error thrown (${error.runtimeType})';
}

/// The reference an error already carries, such as one a function logged
/// and returned in its error details (`failWithReference`).
String? _carriedReference(Object error) {
  try {
    final dynamic e = error;
    final dynamic details = e.details;
    if (details is Map && isErrorReference(details['ref'])) {
      return details['ref'] as String;
    }
  } catch (_) {
    // Most errors have no `details`.
  }
  return null;
}

String _platformName() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'flutter';
  }
}

/// The app's reporter.
final ErrorReporter errorReporter = ErrorReporter(
  endpoint: clientErrorsEndpoint(),
);

/// Reports [error] and returns its reference. Use it in a `catch` that gives
/// up: show the reference, and the admin can find the log line.
String reportError(
  Object error, [
  StackTrace? stack,
  String severity = 'ERROR',
]) =>
    errorReporter.report(error, stack, severity: severity);

/// Who is signed in, for the reports that follow. Null after sign-out.
void setErrorReportUser(String? uid) => errorReporter.uid = uid;
