import 'package:flutter/material.dart';

/// Centered progress indicator + optional caption. Standard async
/// placeholder used by feature screens while a stub service "loads".
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.caption});
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          if (caption != null) ...[
            const SizedBox(height: 12),
            Text(
              caption!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
