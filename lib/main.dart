import 'app.dart';
import 'errors/error_hooks.dart';
import 'router/app_router.dart';

void main() {
  // Every error the app does not handle is logged with a reference the
  // person can quote; see docs/errors.md. Once Firebase is set up, also set
  // `errorReporter.endpoint = clientErrorsEndpoint(projectId:
  // DefaultFirebaseOptions.currentPlatform.projectId)` and call
  // `setErrorReportUser(uid)` when the signed-in user changes.
  runAppReportingErrors(
    const MyApp(),
    route: () => appRouter.routeInformationProvider.value.uri.path,
  );
}
