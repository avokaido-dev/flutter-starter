import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_image_base.dart';

/// Pictures Avokaido generates for this app.
///
/// Every picture nobody supplied is generated after the app ships. Its address
/// is fixed before the picture exists:
///
///     $appImageBase/<slot>
///
/// with the base from `app_image_base.dart`, which Avokaido writes when it
/// creates the app. The address has no file extension: the server says what
/// kind of picture it is. Avokaido first writes a "Generating picture…" placeholder there, then
/// overwrites it with the real picture, so the app fills in without a new
/// release. Each slot used in the code has one entry in
/// `avokaido/images.json` (slot, prompt, alt, aspect), which is what tells
/// Avokaido to make it.
///
///     AppImage('products/wool-coat-black',
///         aspect: AppImageAspect.portrait,
///         semanticLabel: 'A black wool coat on a hanger')

/// A slot is at most this many characters.
const int maxSlotLength = 80;

/// Kebab-case segments joined by `/`: `home/hero`, `products/wool-coat-black`.
final RegExp _slotPattern = RegExp(
  r'^[a-z0-9]+(?:-[a-z0-9]+)*(?:/[a-z0-9]+(?:-[a-z0-9]+)*)*$',
);

/// Whether [slot] is a name Avokaido will generate a picture for: lowercase
/// letters, digits and single hyphens, in segments joined by `/`, at most
/// [maxSlotLength] characters.
bool isValidSlot(String slot) =>
    slot.length <= maxSlotLength && _slotPattern.hasMatch(slot);

/// The address of the generated picture for [slot].
///
/// A bad slot fails an assert, so the mistake is found in a debug run; a
/// release build still returns an address, which fails to load and shows the
/// waiting card.
String appImageUrl(String slot, {String base = appImageBase}) {
  assert(
    isValidSlot(slot),
    'Invalid picture slot "$slot". A slot is kebab-case segments joined by '
    '"/" (a-z, 0-9, "-", "/"), at most $maxSlotLength characters, such as '
    '"home/hero" or "products/wool-coat-black".',
  );
  return '${_trimBase(base)}/$slot';
}

String _trimBase(String base) {
  var trimmed = base.trim();
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

/// The shapes a generated picture comes in, as in `avokaido/images.json`.
enum AppImageAspect {
  square('1:1', 1),
  landscape('4:3', 4 / 3),
  wide('16:9', 16 / 9),
  portrait('3:4', 3 / 4);

  const AppImageAspect(this.manifestValue, this.ratio);

  /// How `avokaido/images.json` writes it.
  final String manifestValue;

  /// Width over height.
  final double ratio;
}

/// Added to the semantic label until the real picture has loaded.
const String pendingSemanticsSuffix = ' (picture being generated)';

/// What the waiting card says, unless the screen passes its own words.
const String defaultPendingLabel = 'Generating picture…';

/// Below this width the waiting card shows only its icon.
const double pendingLabelMinWidth = 120;

/// A picture Avokaido generates for this app, at [appImageUrl].
///
/// Until the picture is there it shows a "Generating picture…" card: a soft
/// gradient in the app's colours, a picture icon and the words (only the icon
/// below [pendingLabelMinWidth]). It shows the same card while the picture
/// loads and when the address does not answer yet, so a screen never shows a
/// broken picture. Every slot used must have an entry in
/// `avokaido/images.json`.
class AppImage extends StatelessWidget {
  const AppImage(
    this.slot, {
    super.key,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.aspect,
    this.pendingLabel = defaultPendingLabel,
    this.base = appImageBase,
  });

  /// The picture's name, such as `home/hero`. See [isValidSlot].
  final String slot;

  final BoxFit fit;

  /// What the finished picture shows, for a screen reader. Null for a purely
  /// decorative picture.
  final String? semanticLabel;

  /// When set, the picture keeps this shape whatever it holds.
  final AppImageAspect? aspect;

  /// The waiting card's words, in the app's language.
  final String pendingLabel;

  /// Where the pictures live; the app's own ([appImageBase]) unless a test
  /// passes another.
  final String base;

  @override
  Widget build(BuildContext context) {
    final url = appImageUrl(slot, base: base);
    Widget pending() => AppImagePending(
          label: pendingLabel,
          semanticLabel: semanticLabel,
          ratio: aspect?.ratio,
        );

    final Widget image = _trimBase(base).isEmpty
        // No address to ask: show the card without a request that can only
        // fail.
        ? pending()
        : Image.network(
            url,
            fit: fit,
            semanticLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
            gaplessPlayback: true,
            // Nothing decoded yet: the card, not an empty box.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                frame == null && !wasSynchronouslyLoaded ? pending() : child,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : pending(),
            // Not made yet, or the network failed: still the card, never a
            // broken picture.
            errorBuilder: (context, error, stackTrace) => pending(),
          );

    final a = aspect;
    return a == null ? image : AspectRatio(aspectRatio: a.ratio, child: image);
  }
}

/// The "Generating picture…" card [AppImage] shows until its picture is there.
///
/// Fills the space it is given; with an unbounded height it takes [ratio]
/// (4:3 when null).
class AppImagePending extends StatelessWidget {
  const AppImagePending({
    super.key,
    this.label = defaultPendingLabel,
    this.semanticLabel,
    this.ratio,
  });

  final String label;

  /// The finished picture's label; read out with [pendingSemanticsSuffix].
  final String? semanticLabel;

  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ink = Color.lerp(scheme.primary, scheme.onSurfaceVariant, 0.45)!;

    final card = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final showLabel = width >= pendingLabelMinWidth;
        final iconSize = (width * 0.22).clamp(24.0, 56.0);
        final fontSize = (width * 0.07).clamp(14.0, 24.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(scheme.surfaceContainerHigh, scheme.primary, 0.14)!,
                Color.lerp(scheme.surface, scheme.secondary, 0.12)!,
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.5),
                radius: 0.9,
                colors: <Color>[
                  scheme.primary.withValues(alpha: 0.18),
                  scheme.primary.withValues(alpha: 0),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _PictureIcon(size: iconSize, color: ink),
                    if (showLabel) ...<Widget>[
                      SizedBox(height: math.min(8, fontSize / 2)),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: ink,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    final readAs = semanticLabel;
    final Widget announced = readAs == null
        ? ExcludeSemantics(child: card)
        : Semantics(
            image: true,
            label: '$readAs$pendingSemanticsSuffix',
            child: ExcludeSemantics(child: card),
          );

    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? SizedBox.expand(child: announced)
          : AspectRatio(aspectRatio: ratio ?? 4 / 3, child: announced),
    );
  }
}

/// A picture icon with a small sparkle: "a picture is being made".
class _PictureIcon extends StatelessWidget {
  const _PictureIcon({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Icon(Icons.image_outlined, size: size, color: color),
          Positioned(
            right: -size * 0.12,
            top: -size * 0.12,
            child: Icon(Icons.auto_awesome, size: size * 0.42, color: color),
          ),
        ],
      ),
    );
  }
}
