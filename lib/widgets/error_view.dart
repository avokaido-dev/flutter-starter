import 'package:flutter/material.dart';

/// What a screen shows when loading failed: what went wrong, in words a user
/// understands, the error's reference, and a way to try again.
///
///     } catch (e, s) {
///       final ref = reportError(e, s);
///       return ErrorView(
///         message: "We couldn't load your bookings. Check your connection.",
///         reference: ref,
///         onRetry: _load,
///       );
///     }
///
/// The reference ("Reference K7PQ2M") is what the person quotes, and what an
/// admin pastes into Cloud Logging to find the log line (docs/errors.md).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.reference,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  /// What failed and, if it helps, what the user can do about it. Never a raw
  /// exception.
  final String message;
  final String title;

  /// The reference `reportError` returned, shown so it can be quoted.
  final String? reference;

  /// Shows the retry button when given.
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center, style: muted),
                if (reference != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Semantics(
                    label: 'Reference ${reference!.split('').join(' ')}',
                    child: ExcludeSemantics(
                      child: SelectableText(
                        'Reference $reference',
                        textAlign: TextAlign.center,
                        style: muted,
                      ),
                    ),
                  ),
                ],
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(retryLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a widget that failed to build shows in a release build, in place of
/// Flutter's grey box (`ErrorWidget.builder`, set by `error_hooks.dart`).
///
/// It can appear anywhere, including above `MaterialApp`, so it brings its own
/// text direction and depends on no theme.
class ReportedErrorWidget extends StatelessWidget {
  const ReportedErrorWidget({super.key, required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFCFCFD),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Something went wrong. Reference $reference',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1F2328), fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
