import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/authentication/login_request.dart';
import '../../responses/authentication/auth_session_response.dart';

class AuthRepository {
  final Dio _dio = Get.find<ApiClient>().dio;

  
  Future<AuthSessionResponse> autoLogin(List<String> simNumbers) async {
    try {
      final response = await _dio.post('/auth/auto-login', data: {
        'sim_numbers': simNumbers,
      });
      final token = (response.data['data']?['token'] ?? response.data['token']) as String;
      final user = (response.data['data']?['user'] ?? response.data['user'] ?? response.data['data']) as Map<String, dynamic>;
      return AuthSessionResponse.fromJson(user, token: token);
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AuthSessionResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post('/auth/login', data: request.toJson());
      final token = response.data['token'] as String;
      final user = response.data['data']['user'] as Map<String, dynamic>;
      return AuthSessionResponse.fromJson(user, token: token);
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  /// Registration creates the account but doesn't return a token, so a
  /// successful register immediately logs in with the same credentials to
  /// get a real session.
  Future<AuthSessionResponse> register(RegisterRequest request) async {
    try {
      await _dio.post('/auth/register', data: request.toJson());
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
    return login(
      LoginRequest(email: request.email, password: request.password),
    );
  }

  /// Returns `null` on any failure (expired/invalid token) rather than
  /// throwing — the splash flow treats "couldn't verify" and "not logged
  /// in" the same way.
  Future<AuthSessionResponse?> checkSession(String token) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final user = response.data['data']['user'] as Map<String, dynamic>;
      return AuthSessionResponse.fromJson(user, token: token);
    } on DioException {
      return null;
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? 'Something went wrong. Please try again.';
  }
}
