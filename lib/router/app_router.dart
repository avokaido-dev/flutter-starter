import 'package:go_router/go_router.dart';

import 'routes.dart';

/// The app's top-level [GoRouter] instance. Routes live in
/// [routes.dart] so Claude / the batch runner can regenerate the
/// route table without touching this file.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: appRoutes,
);
