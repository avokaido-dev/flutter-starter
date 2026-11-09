/// Wires every way a Flutter app can fail into [ErrorReporter].
///
///   - `FlutterError.onError`: errors in build, layout and paint, and those
///     the framework catches for you (a failed image, a gesture handler).
///   - `PlatformDispatcher.instance.onError`: everything else nothing caught,
///     including failed futures nobody awaited.
///   - `ErrorWidget.builder`, in release builds: a widget that failed to build
///     shows "Something went wrong. Reference K7PQ2M" instead of a grey box.
///
/// Queued reports are sent when the app goes to the background, so an error
/// just before the person leaves the app still arrives.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../widgets/error_view.dart';
import 'error_reporter.dart';

/// Runs [app] with every error reported. Use in place of `runApp`.
void runAppReportingErrors(
  Widget app, {
  String? Function()? route,
  ErrorReporter? reporter,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHooks(reporter: reporter ?? errorReporter, route: route);
  runApp(app);
}

AppLifecycleListener? _lifecycle;

/// Installs the hooks. Each keeps whatever handler was there before, so a
/// test binding or a crash reporter added later still sees every error.
void installErrorHooks({
  required ErrorReporter reporter,
  String? Function()? route,
  bool replaceErrorWidget = kReleaseMode,
}) {
  if (route != null) reporter.route = route;

  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (details) {
    reporter.report(
      details.exception,
      details.stack,
      kind: ErrorKind.flutter,
      // `silent` errors are ones the framework recovered from on its own.
      severity: details.silent ? 'WARNING' : 'ERROR',
    );
    (previousFlutter ?? FlutterError.presentError)(details);
  };

  final dispatcher = PlatformDispatcher.instance;
  final previousPlatform = dispatcher.onError;
  dispatcher.onError = (error, stack) {
    reporter.report(error, stack, kind: ErrorKind.uncaught);
    return previousPlatform?.call(error, stack) ?? true;
  };

  if (replaceErrorWidget) {
    ErrorWidget.builder = (details) => ReportedErrorWidget(
          reference: reporter.report(
            details.exception,
            details.stack,
            kind: ErrorKind.flutter,
          ),
        );
  }

  _lifecycle?.dispose();
  _lifecycle = AppLifecycleListener(
    onHide: () => unawaited(reporter.flush()),
    onDetach: () => unawaited(reporter.flush()),
  );
}
