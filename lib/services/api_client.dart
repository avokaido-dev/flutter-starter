/// Stub HTTP / Functions client.
///
/// Feature services (`menu_service.dart`, `booking_service.dart`, …)
/// call into this in the AI scaffold so swapping in real backend
/// transport later is a one-file change.
///
/// TODO(avokaido): api — wire FirebaseFunctions / a typed REST client.
///   Contract:
///     - `call<T>(name, body)` issues the call and returns the parsed JSON
///     - Errors throw an `ApiException` with the server status + message
class ApiClient {
  Future<T> call<T>(String name, {Map<String, dynamic>? body}) async {
    throw UnimplementedError(
      'ApiClient.call($name) is a stub — the Avokaido batch runner '
      'wires this to the real backend.',
    );
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => 'ApiException($status): $message';
}

final ApiClient apiClient = ApiClient();
