import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

typedef RequestStartCallback = void Function(RequestOptions options);
typedef RequestErrorCallback = void Function(DioException error);
typedef RefreshTokenCallback = Future<String?> Function(String? oldToken);

class HttpUtil {
  
  static HttpUtil? _instance;
  late Dio _dio;
  late BaseOptions _options;

  static bool _isLoading = false;
  static String? _accessToken;
  static String? _refreshToken;
  static RequestStartCallback? _globalOnRequestStart;
  static RequestErrorCallback? _globalOnRequestError;
  static RefreshTokenCallback? _refreshTokenCallback;
  static Completer<String?>? _refreshCompleter;

  factory HttpUtil() => _instance ??= HttpUtil._internal();

  HttpUtil._internal() {
    
    _options = BaseOptions(
      baseUrl: "https://api.example.com", 
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      contentType: "application/json; charset=utf-8",
      responseType: ResponseType.json,
    );

    _dio = Dio(_options);

    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        
        final skipAuth = options.extra["skipAuth"] == true;
        if (!skipAuth && _accessToken != null && _accessToken!.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $_accessToken";
        }

        _globalOnRequestStart?.call(options);
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (e, handler) async {
        final statusCode = e.response?.statusCode;
        final requestOptions = e.requestOptions;
        final isRefreshRequest = requestOptions.extra["isRefreshRequest"] == true;
        final hasRetried = requestOptions.extra["retried"] == true;

        if (statusCode == 401 && !isRefreshRequest && !hasRetried) {
          final newToken = await _refreshAccessToken();
          if (newToken != null && newToken.isNotEmpty) {
            requestOptions.extra["retried"] = true;
            requestOptions.headers["Authorization"] = "Bearer $newToken";
            try {
              final retryResponse = await HttpUtil()._dio.fetch(requestOptions);
              return handler.resolve(retryResponse);
            } catch (_) {
              
            }
          }
        }

        _globalOnRequestError?.call(e);
        _handleError(e);
        return handler.next(e);
      },
    ));
  }

  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  static void setRefreshToken(String? refreshToken) {
    _refreshToken = refreshToken;
  }

  static void setRequestCallbacks({
    RequestStartCallback? onRequestStart,
    RequestErrorCallback? onRequestError,
  }) {
    _globalOnRequestStart = onRequestStart;
    _globalOnRequestError = onRequestError;
  }

  static void setRefreshTokenHandler(RefreshTokenCallback callback) {
    _refreshTokenCallback = callback;
  }

  static Future<String?> _refreshAccessToken() async {
    if (_refreshTokenCallback == null) return null;

    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    try {
      final newToken = await _refreshTokenCallback!.call(_refreshToken);
      if (newToken != null && newToken.isNotEmpty) {
        _accessToken = newToken;
      }
      _refreshCompleter!.complete(newToken);
      return newToken;
    } catch (_) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  void _handleError(DioException e) {
    String msg = "请求失败";
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        msg = "连接超时";
        break;
      case DioExceptionType.sendTimeout:
        msg = "发送超时";
        break;
      case DioExceptionType.receiveTimeout:
        msg = "接收超时";
        break;
      case DioExceptionType.badResponse:
        msg = "服务器异常 ${e.response?.statusCode}";
        break;
      default:
        msg = "网络异常";
    }
    Fluttertoast.showToast(msg: msg);
    debugPrint("Dio 错误：$msg");
  }

  static void showLoading() {
    if (!_isLoading) {
      _isLoading = true;
      
      Fluttertoast.cancel();
    }
  }

  static void hideLoading() {
    if (_isLoading) {
      _isLoading = false;
    }
  }

  static Future<T?> _request<T>(
    Future<Response<T>> Function() send, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    RequestOptions? requestOptionsForStart,
  }) async {
    try {
      if (isShowLoading) showLoading();
      if (requestOptionsForStart != null) {
        onStart?.call(requestOptionsForStart);
      }
      final res = await send();
      return res.data;
    } on DioException catch (e) {
      onError?.call(e);
      rethrow;
    } finally {
      if (isShowLoading) hideLoading();
    }
  }

  static Future<T?> get<T>(
      String path, {
        Map<String, dynamic>? params,
        bool isShowLoading = true,
        RequestStartCallback? onStart,
        RequestErrorCallback? onError,
        bool skipAuth = false,
      }) async {
    final options = Options(extra: {"skipAuth": skipAuth});
    return _request<T>(
      () => HttpUtil()._dio.get<T>(path, queryParameters: params, options: options),
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      requestOptionsForStart: RequestOptions(path: path, queryParameters: params),
    );
  }

  static Future<T?> post<T>(
      String path, {
        dynamic data,
        Map<String, dynamic>? params,
        bool isShowLoading = true,
        RequestStartCallback? onStart,
        RequestErrorCallback? onError,
        bool skipAuth = false,
      }) async {
    final options = Options(extra: {"skipAuth": skipAuth});
    return _request<T>(
      () => HttpUtil()._dio.post<T>(
        path,
        data: data,
        queryParameters: params,
        options: options,
      ),
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      requestOptionsForStart: RequestOptions(
        path: path,
        data: data,
        queryParameters: params,
      ),
    );
  }

  static Future<T?> put<T>(
      String path, {
        dynamic data,
        bool isShowLoading = true,
        RequestStartCallback? onStart,
        RequestErrorCallback? onError,
        bool skipAuth = false,
      }) async {
    final options = Options(extra: {"skipAuth": skipAuth});
    return _request<T>(
      () => HttpUtil()._dio.put<T>(path, data: data, options: options),
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      requestOptionsForStart: RequestOptions(path: path, data: data),
    );
  }

  static Future<T?> delete<T>(
      String path, {
        bool isShowLoading = true,
        RequestStartCallback? onStart,
        RequestErrorCallback? onError,
        bool skipAuth = false,
      }) async {
    final options = Options(extra: {"skipAuth": skipAuth});
    return _request<T>(
      () => HttpUtil()._dio.delete<T>(path, options: options),
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      requestOptionsForStart: RequestOptions(path: path),
    );
  }

  static Future<T?> uploadFile<T>(
      String path,
      String filePath, {
        String name = "file",
        bool isShowLoading = true,
        RequestStartCallback? onStart,
        RequestErrorCallback? onError,
        bool skipAuth = false,
      }) async {
    final options = Options(extra: {"skipAuth": skipAuth});
    return _request<T>(
      () async {
        final formData = FormData.fromMap({
          name: await MultipartFile.fromFile(filePath),
        });
        return HttpUtil()._dio.post<T>(path, data: formData, options: options);
      },
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      requestOptionsForStart: RequestOptions(path: path),
    );
  }

  static Future<void> download(
      String url,
      String savePath, {
        Function(int, int)? onProgress,
      }) async {
    await HttpUtil()._dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
    );
  }

  static Future<List<int>?> getBytes(
      String path, {
        Map<String, dynamic>? params,
        bool isShowLoading = true,
        RequestStartCallback? onStart,
        RequestErrorCallback? onError,
        bool skipAuth = false,
      }) async {
    final options = Options(
      extra: {"skipAuth": skipAuth},
      responseType: ResponseType.bytes,
    );
    return _request<List<int>>(
      () => HttpUtil()._dio.get<List<int>>(
            path,
            queryParameters: params,
            options: options,
          ),
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      requestOptionsForStart: RequestOptions(path: path, queryParameters: params),
    );
  }
}


