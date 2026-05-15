import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/app.dart';

void main() {
  testWidgets('app boots and renders the initial route', (tester) async {
    await tester.pumpWidget(const MyApp());
    // Let go_router settle its initial redirect/build.
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
