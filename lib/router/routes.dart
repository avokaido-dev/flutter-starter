import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home_screen.dart';

/// Default route table — the AI scaffold OVERWRITES this when it
/// generates screens for the user's app. The single `/` route here
/// keeps the project bootable in the rare case Claude omits this file.
final List<RouteBase> appRoutes = <RouteBase>[
  GoRoute(
    path: '/',
    builder: (BuildContext context, GoRouterState state) =>
        const HomeScreen(),
  ),
];
