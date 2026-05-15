import 'package:flutter/material.dart';

/// Default home screen — the AI scaffold OVERWRITES this. Kept here
/// so the project boots when Claude omits the file (e.g. mid-chat
/// without committing any screens yet).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Starter')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_outlined,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Welcome to Flutter Starter',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Frontend scaffold is live. Chat with Avokaido to add '
                'real screens for this app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
