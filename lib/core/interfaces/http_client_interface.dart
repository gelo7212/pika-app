abstract class HttpClientInterface {
  Future<HttpResponse> get(dynamic url, {Map<String, String>? headers});

  Future<HttpResponse> post(dynamic url,
      {Map<String, String>? headers, dynamic body});

  Future<HttpResponse> put(dynamic url,
      {Map<String, String>? headers, dynamic body});

  Future<HttpResponse> patch(dynamic url,
      {Map<String, String>? headers, dynamic body});

  Future<HttpResponse> delete(dynamic url, {Map<String, String>? headers});
}

class HttpResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, dynamic>? headers;

  HttpResponse({
    required this.statusCode,
    required this.data,
    this.headers,
  });
}

class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, {this.statusCode});

  @override
  String toString() =>
      'HttpException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}
