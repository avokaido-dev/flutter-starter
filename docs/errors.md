# Errors: where they go and how to find one

When something goes wrong in this app, the person sees:

> Something went wrong
> Reference **K7PQ2M**

That reference is on exactly one log line in this app's own Google Cloud
project. This page is how an IT admin finds it.

## Where errors land

| What failed | How it is caught | Where it goes |
| --- | --- | --- |
| A build, layout or paint error | `FlutterError.onError` (`lib/errors/error_hooks.dart`) | Cloud Logging, via `clientErrors` |
| An exception or future nothing caught | `PlatformDispatcher.instance.onError` (same file) | Cloud Logging, via `clientErrors` |
| A widget that failed to build (release builds) | `ErrorWidget.builder`, which shows the reference | Cloud Logging, via `clientErrors` |
| An error a screen caught and gave up on | `reportError(e, s)` (`lib/errors/error_reporter.dart`) | Cloud Logging, via `clientErrors` |

`main.dart` runs the app through `runAppReportingErrors`, which installs all
three hooks. The app sends its errors in small batches to `clientErrors`, a
Cloud Function in the app's Firebase project, which writes each one to Cloud
Logging at severity `ERROR`, labelled `log=client-errors`. Avokaido checks
every app's logs for `severity>=ERROR` and emails the app's admins.

Every event is also printed to the device log as
`[client-error] Reference K7PQ2M …`, so `flutter run` shows it straight away.

### Where the app sends them

The address comes from the build, in this order:

1. `--dart-define=CLIENT_ERRORS_URL=…`, for an emulator or a custom address.
2. `--dart-define=FIREBASE_PROJECT_ID=<project>`, giving
   `https://europe-west1-<project>.cloudfunctions.net/clientErrors`.
3. Once Firebase is set up in the app (the batch runner wires it), `main.dart` sets
   `errorReporter.endpoint = clientErrorsEndpoint(projectId:
   DefaultFirebaseOptions.currentPlatform.projectId)`.

With none of these, errors stay in the device log. `clientErrors` itself is
deployed by the website in the same Firebase project (it ships with every
Avokaido website, in `functions/src/client-errors/`). A project with no website
needs it deployed from there once.

`--dart-define=APP_VERSION=<commit>` names the build in each event; without it
the version reads `dev`.

## Finding a reference

Open **Logs Explorer** in the Google Cloud console for the app's project and
paste:

```
jsonPayload.ref="K7PQ2M"
```

Other filters worth keeping:

| What you want | Filter |
| --- | --- |
| Every app error | `labels.log="client-errors" severity>=ERROR` |
| Only the mobile builds | `labels.log="client-errors" jsonPayload.platform=("ios" OR "android")` |
| One user's errors | `labels.log="client-errors" jsonPayload.uid="<uid>"` |
| One release | `jsonPayload.release="<version>"` |

Errors are also grouped in **Error Reporting** as `client-web`,
`client-ios` and `client-android`. Cloud Logging keeps them for **30 days**, its default.

## What one event holds

`ref`, `severity`, `kind` (`flutter`, `uncaught`, `manual`), `errorType`,
`errorMessage`, `stack_trace`, `route` (the screen's path), `release`,
`platform`, and `uid` when someone is signed in. The sign-in code reports who
that is with `setErrorReportUser(uid)`, and `setErrorReportUser(null)` on
sign-out. The uid is reported by the app, not verified.

## What is never logged

- Passwords, tokens, API keys or `Authorization` headers.
- Email addresses, names, or anything a person typed.
- Document contents, or the fields of anything thrown that is not an
  `Exception` or `Error` (only its type is logged).
- Query strings and fragments of any URL.

The app scrubs every message and stack before sending (`lib/errors/scrub.dart`)
and the function scrubs them again. Google's request log for `clientErrors`
records the caller's IP address, as for every request to the project; the
function uses it for its rate limit and does not log it itself.

## Writing code that fails well

A `catch` that gives up reports the error and shows the reference:

```dart
} catch (e, s) {
  final ref = reportError(e, s);
  return ErrorView(message: "We couldn't load your bookings.", reference: ref);
}
```
