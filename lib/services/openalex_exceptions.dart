/// Typed errors raised by [OpenAlexService] so the UI can react differently to
/// connectivity issues, rate limiting, and malformed responses.
sealed class OpenAlexException implements Exception {
  const OpenAlexException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Connectivity failure or a non-success HTTP status (other than 429).
class NetworkException extends OpenAlexException {
  const NetworkException(super.message, {this.statusCode});
  final int? statusCode;
}

/// OpenAlex returned HTTP 429 (polite-pool / rate limit exceeded).
class RateLimitException extends OpenAlexException {
  const RateLimitException([super.message = 'Rate limit exceeded. Try again shortly.']);
}

/// The response body could not be decoded into the expected shape.
class ParseException extends OpenAlexException {
  const ParseException([super.message = 'Could not parse the OpenAlex response.']);
}
