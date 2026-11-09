/// Error references: the short code a person reads out to whoever supports the
/// app ("Reference K7PQ2M"), and the key an admin pastes into Cloud Logging to
/// find the exact log line.
///
/// Six characters from an alphabet without the ones people confuse on a
/// screenshot or the phone: no 0/O, 1/I/L, or U/V. The web app and the Cloud
/// Functions use the same alphabet, so a reference reads the same everywhere.
library;

import 'dart:math';

const String referenceAlphabet = 'ABCDEFGHJKMNPQRSTWXYZ23456789';
const int referenceLength = 6;

final RegExp _referencePattern = RegExp(
  '^[$referenceAlphabet]{$referenceLength}\$',
);

final Random _random = _secureOrNot();

Random _secureOrNot() {
  try {
    return Random.secure();
  } on UnsupportedError {
    return Random();
  }
}

/// A new random reference, such as `K7PQ2M`.
String newErrorReference([Random? random]) {
  final r = random ?? _random;
  return List.generate(
    referenceLength,
    (_) => referenceAlphabet[r.nextInt(referenceAlphabet.length)],
  ).join();
}

/// Whether [value] is a reference this app could have made.
bool isErrorReference(Object? value) =>
    value is String && _referencePattern.hasMatch(value);
