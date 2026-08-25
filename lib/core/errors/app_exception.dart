/// Typed errors used across the market pipeline.
enum AppErrorCode {
  network,
  timeout,
  rateLimited,
  invalidData,
  unauthorized,
  serverRequired,
  unknown,
}

class AppException implements Exception {
  const AppException(this.code, this.message, {this.cause});

  final AppErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException(${code.name}): $message';
}
