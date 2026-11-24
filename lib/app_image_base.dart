/// Where this app's generated pictures live:
/// `https://storage.googleapis.com/<bucket>/apps/<mediaId>`.
///
/// Avokaido writes this file when it creates the app; do not edit it. The
/// address is public and fixed for the project. Empty means the app has no
/// pictures yet, and `AppImage` then shows its "Generating picture…" card
/// without asking the network for anything.
const String appImageBase = '';
