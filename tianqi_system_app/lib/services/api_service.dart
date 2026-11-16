import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'token_storage.dart';

/// 与论坛后端通信的统一入口。
///
/// 线上服务：Nginx 监听 80，/api/ 反向代理到 Gunicorn（见 anime-forum/deploy.sh）。
class ApiService {
  static final ApiService instance = ApiService._();

  /// 线上 API 主机；本地联调再临时换回 http://10.0.2.2:8000。
  static const String host = 'http://121.43.108.53';
  static const String _baseUrl = '$host/api/v1/';

  /// 全局导航钥匙：401 时由网络层清栈跳转登录页。
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  ApiService._() {
    _dio.interceptors.add(_authInterceptor);
  }

  Interceptor get _authInterceptor => InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await TokenStorage.instance.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      // 登录接口自身的 401 是账号密码错误，交给页面提示，不做跳转。
      if (error.response?.statusCode == 401 &&
          !_isAuthEndpoint(error.requestOptions.path)) {
        await _handleUnauthorized();
      }
      handler.next(error);
    },
  );

  bool _isAuthEndpoint(String path) =>
      path.contains('auth/login') || path.contains('auth/register');

  Future<void> _handleUnauthorized() async {
    await TokenStorage.instance.clear();
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool> hasSession() => TokenStorage.instance.hasAccessToken();

  /// 登录并保存 access / refresh；失败时抛出原始异常，由页面统一提示。
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/login/',
      data: {'username': username, 'password': password},
    );

    final data = response.data ?? const <String, dynamic>{};
    final access = data['access'];
    final refresh = data['refresh'];
    if (access is! String || refresh is! String) {
      throw const FormatException('登录响应缺少 Token');
    }
    await TokenStorage.instance.saveTokens(access: access, refresh: refresh);
  }

  /// 上报宿主状态；调用方负责吞掉异常，避免影响本地进度。
  Future<void> syncStatus({
    required int level,
    required int exp,
    required int streak,
    required String? streakDate,
  }) async {
    await _dio.post<void>(
      'sync_status/',
      data: {
        'level': level,
        'exp': exp,
        'streak': streak,
        // 契约：streak 为 0 时日期必须为 null。
        'streak_date': streak > 0 ? streakDate : null,
      },
    );
  }

  /// 把网络异常转成适合直接展示的一行中文提示。
  static String describeError(Object error) {
    if (error is FormatException) return error.message;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        final message = (data['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return '连接超时，请检查网络';
        case DioExceptionType.connectionError:
          return '无法连接服务器，请确认后端已启动';
        case DioExceptionType.badResponse:
          return '请求失败（${error.response?.statusCode}）';
        case DioExceptionType.cancel:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          return '网络异常，请稍后重试';
      }
    }
    return '网络异常，请稍后重试';
  }
}
