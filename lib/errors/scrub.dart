/// What an error report may carry, and what it never does.
///
/// Exception messages and stack traces quote whatever they were handed: a URL
/// with a token in it, the email address a sign-in failed for, a request body.
/// Everything that leaves the device passes through here first, and the
/// `clientErrors` function that receives it scrubs it again.
///
/// Never logged: tokens and API keys, email addresses, passwords, query
/// strings, and document contents. The route is the path alone.
library;

/// Longest message kept; past this a message is somebody's data, not ours.
const int maxMessageLength = 1000;

/// Longest stack kept. About 40 frames.
const int maxStackLength = 8000;

final List<(RegExp, String Function(Match))> _replacements = [
  // URLs keep their path and lose query and fragment, where tokens live.
  (
    RegExp(r'''\b(https?://[^\s?#"'<>]*)[?#][^\s"'<>]*''',
        caseSensitive: false),
    (m) => '${m[1]}?[redacted]',
  ),
  // JSON Web Tokens, including Firebase ID tokens.
  (RegExp(r'\beyJ[\w-]{6,}\.[\w-]{6,}\.[\w-]{6,}'), (_) => '[token]'),
  // Bearer and basic credentials quoted from a header.
  (
    RegExp(r'\b(bearer|basic)\s+[\w~+/=.-]{8,}', caseSensitive: false),
    (m) => '${m[1]} [token]',
  ),
  // key=value pairs whose key says what they are.
  (
    RegExp(
      r'''\b(password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key|authorization|auth|session|cookie)(["']?\s*[:=]\s*["']?)[^\s"'&,;}]+''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}[redacted]',
  ),
  // Google API keys.
  (RegExp(r'\bAIza[\w-]{30,}'), (_) => '[key]'),
  // Email addresses.
  (RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+'), (_) => '[email]'),
  // Long opaque strings: hex digests, base64 blobs, card-like digit runs.
  (RegExp(r'\b[A-Fa-f0-9]{32,}\b'), (_) => '[redacted]'),
  (RegExp(r'\b[A-Za-z0-9+/_-]{40,}={0,2}'), (_) => '[redacted]'),
  (RegExp(r'\b\d{12,}\b'), (_) => '[number]'),
];

/// [text] with secrets and personal details replaced, and length capped.
String scrubText(String text, {int max = maxMessageLength}) {
  var out = text;
  for (final (pattern, replace) in _replacements) {
    out = out.replaceAllMapped(pattern, replace);
  }
  return out.length > max ? '${out.substring(0, max)}…' : out;
}

/// The route as logged: the path only.
String? scrubRoute(String? location) {
  if (location == null || location.isEmpty) return null;
  final path = location.split(RegExp(r'[?#]')).first;
  return scrubText(path, max: 200);
}
