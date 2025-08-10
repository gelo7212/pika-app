import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../interfaces/http_client_interface.dart';
import '../exceptions/exceptions.dart';

class DioClient implements HttpClientInterface {
  late final Dio _dio;

  DioClient() {
    _dio = Dio();
    _setupInterceptors();
  }

  // Getter to expose the Dio instance for services that need direct access
  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
      logPrint: (object) {
        if (kDebugMode) {
          print(object);
        }
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final httpException = HttpException(
          error.message ?? 'Unknown error',
          statusCode: error.response?.statusCode,
        );
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: httpException,
        ));
      },
    ));
  }

  @override
  Future<HttpResponse> get(dynamic url, {Map<String, String>? headers}) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(headers: headers),
      );
      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Network request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<HttpResponse> post(dynamic url,
      {Map<String, String>? headers, dynamic body}) async {
    try {
      final response = await _dio.post(
        url,
        data: body,
        options: Options(headers: headers),
      );
      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Network request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<HttpResponse> put(dynamic url,
      {Map<String, String>? headers, dynamic body}) async {
    try {
      final response = await _dio.put(
        url,
        data: body,
        options: Options(headers: headers),
      );
      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Network request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<HttpResponse> patch(dynamic url,
      {Map<String, String>? headers, dynamic body}) async {
    try {
      final response = await _dio.patch(
        url,
        data: body,
        options: Options(headers: headers),
      );
      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Network request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<HttpResponse> delete(dynamic url,
      {Map<String, String>? headers}) async {
    try {
      final response = await _dio.delete(
        url,
        options: Options(headers: headers),
      );
      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Network request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
