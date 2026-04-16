import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/models.dart';

class AuthService {
  final _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _api.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });

    final token = response.data['access_token'];
    final user = UserModel.fromJson(response.data['user']);

    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(
        key: AppConstants.userKey, value: jsonEncode(user.toJson()));

    return {'token': token, 'user': user};
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<String?> getToken() =>
      _storage.read(key: AppConstants.tokenKey);

  Future<UserModel?> getStoredUser() async {
    final raw = await _storage.read(key: AppConstants.userKey);
    if (raw == null) return null;
    return UserModel.fromJson(jsonDecode(raw));
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<UserModel> getMe() async {
    final response = await _api.get('/api/auth/me');
    return UserModel.fromJson(response.data);
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _api.put('/api/auth/fcm-token', data: {'fcm_token': fcmToken});
  }
}
