import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api.dart';

class ApiService {
  static Future<void> Function()? onUnauthorized;
  static Future<void> Function(String message)? onPendingProfile;
  static bool _unauthorizedCallbackRunning = false;
  static bool _pendingProfileCallbackRunning = false;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 20);
  static const pendingProfileMessage =
      'Your account is registered, but your employee profile is awaiting HR completion. You will be able to log in once HR completes your profile.';

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool handleUnauthorized = true,
  }) => _request('GET', endpoint, handleUnauthorized: handleUnauthorized);

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool handleUnauthorized = true,
  }) => _request(
    'POST',
    endpoint,
    body: body,
    handleUnauthorized: handleUnauthorized,
  );

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool handleUnauthorized = true,
  }) => _request(
    'PATCH',
    endpoint,
    body: body,
    handleUnauthorized: handleUnauthorized,
  );

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool handleUnauthorized = true,
  }) => _request('DELETE', endpoint, handleUnauthorized: handleUnauthorized);

  static Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool handleUnauthorized = true,
    bool authenticated = true,
    String? explicitToken,
    Duration requestTimeout = _timeout,
  }) async {
    final token = authenticated
        ? (explicitToken ?? await getStoredToken())
        : null;
    final headers = <String, String>{'Accept': 'application/json'};

    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('${Api.baseUrl}$endpoint');
    final encodedBody = body == null ? null : jsonEncode(body);
    late http.Response response;

    switch (method) {
      case 'GET':
        response = await http
            .get(uri, headers: headers)
            .timeout(requestTimeout);
      case 'POST':
        response = await http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(requestTimeout);
      case 'PATCH':
        response = await http
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(requestTimeout);
      case 'DELETE':
        response = await http
            .delete(uri, headers: headers)
            .timeout(requestTimeout);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }

    final data = _decodeBody(response.body);
    if (response.statusCode == 403 &&
        authenticated &&
        handleUnauthorized &&
        token != null &&
        isPendingProfileResponse(data)) {
      await _handlePendingProfile(token, messageFromResponse(data, 403));
    }

    if (response.statusCode == 401 && authenticated && handleUnauthorized) {
      await clearSession();
      if (!_unauthorizedCallbackRunning) {
        _unauthorizedCallbackRunning = true;
        try {
          await onUnauthorized?.call();
        } finally {
          _unauthorizedCallbackRunning = false;
        }
      }
    }

    return {'status': response.statusCode, 'data': data};
  }

  static dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } on FormatException {
      return <String, dynamic>{
        'message': 'The server returned an invalid response.',
      };
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) =>
      _request(
        'POST',
        '/login',
        body: {'email': email, 'password': password},
        authenticated: false,
        handleUnauthorized: false,
      );

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) => _request(
    'POST',
    '/register',
    body: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    },
    authenticated: false,
    handleUnauthorized: false,
  );

  static bool isPendingProfileResponse(dynamic data) =>
      data is Map && data['message'] == pendingProfileMessage;

  static String messageFromResponse(dynamic data, dynamic status) {
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;

      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
        }
      }
    }

    return messageForStatus(status);
  }

  static Future<void> _handlePendingProfile(
    String requestToken,
    String message,
  ) async {
    if (_pendingProfileCallbackRunning) return;

    if (await getStoredToken() != requestToken) return;

    _pendingProfileCallbackRunning = true;
    try {
      try {
        await _request(
          'POST',
          '/logout',
          body: const {},
          handleUnauthorized: false,
          explicitToken: requestToken,
          requestTimeout: const Duration(seconds: 8),
        );
      } catch (_) {
        // The pending account is blocked on the server even if revocation is offline.
      }

      if (await getStoredToken() != requestToken) return;
      await clearSession();
      await onPendingProfile?.call(message);
    } finally {
      _pendingProfileCallbackRunning = false;
    }
  }

  static Future<Map<String, dynamic>?> revokeCurrentToken() async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) return null;

    try {
      return await _request(
        'POST',
        '/logout',
        body: const {},
        handleUnauthorized: false,
        requestTimeout: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getStoredToken() async {
    final secureToken = await _secureStorage.read(key: 'token');
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString('token');
    if (legacyToken == null || legacyToken.isEmpty) return null;

    await _secureStorage.write(key: 'token', value: legacyToken);
    await prefs.remove('token');
    return legacyToken;
  }

  static Future<void> storeToken(String token) async {
    await _secureStorage.write(key: 'token', value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('user');
    if (rawUser == null) return null;
    try {
      final user = jsonDecode(rawUser);
      if (user is Map<String, dynamic>) {
        final id = user['id'];
        return id is int ? id : int.tryParse(id?.toString() ?? '');
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static bool isSuccess(dynamic status) =>
      status is int && status >= 200 && status < 300;

  static bool isUnauthorized(dynamic status) => status == 401;

  static String messageForStatus(dynamic status) {
    if (status == 403) {
      return 'Your account does not have permission for this action.';
    }
    if (status == 404) return 'The requested record or profile was not found.';
    if (status == 422) return 'Please review the submitted information.';
    if (status == 429) return 'Too many requests. Please wait and retry.';
    if (status is int && status >= 500) {
      return 'The server is temporarily unavailable.';
    }
    return 'The request could not be completed.';
  }

  static Future<void> clearSession() async {
    await _secureStorage.delete(key: 'token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('cached_employee');
  }
}
