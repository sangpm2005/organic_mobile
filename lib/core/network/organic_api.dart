import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/json.dart';
import 'api_exception.dart';

class OrganicApi {
  static const configuredBase = String.fromEnvironment('API_BASE_URL');
  final String baseUrl;
  final http.Client client;
  String? accessToken, refreshToken;
  int sessionVersion = 0;
  Future<bool>? _refreshing;
  int? _refreshVersion;
  Future<void> Function()? onSessionChanged;
  OrganicApi({String? baseUrl, http.Client? client})
    : baseUrl =
          (baseUrl ??
                  (configuredBase.isNotEmpty
                      ? configuredBase
                      : kIsWeb
                      ? '${Uri.base.origin}/api/v1'
                      : 'http://10.0.2.2:8088/api/v1'))
              .replaceFirst(RegExp(r'/$'), ''),
      client = client ?? http.Client();

  void setSession(String? access, String? refresh) {
    sessionVersion++;
    accessToken = access;
    refreshToken = refresh;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Json? body,
    Json? query,
    bool authenticated = true,
    String? idempotencyKey,
    bool retry = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final version = sessionVersion;
    final sentAccess = accessToken;
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null
          ? null
          : {
              for (final entry in query.entries)
                if (entry.value != null && '${entry.value}'.isNotEmpty)
                  entry.key: '${entry.value}',
            },
    );
    final req = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (authenticated && accessToken != null) {
      req.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (idempotencyKey != null) req.headers['Idempotency-Key'] = idempotencyKey;
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(req),
      ))().timeout(timeout);
      if (authenticated && version != sessionVersion) {
        throw const ApiException('Phiên đăng nhập đã thay đổi.');
      }
      if (response.statusCode == 401 &&
          authenticated &&
          retry &&
          refreshToken != null) {
        bool refreshed;
        if (sentAccess != accessToken) {
          refreshed = accessToken != null;
        } else {
          if (_refreshing == null || _refreshVersion != version) {
            _refreshVersion = version;
            _refreshing = _refresh(version);
          }
          final pending = _refreshing!;
          try {
            refreshed = await pending;
          } finally {
            if (identical(_refreshing, pending)) _refreshing = null;
          }
        }
        if (refreshed) {
          return await request(
            method,
            path,
            body: body,
            query: query,
            authenticated: authenticated,
            idempotencyKey: idempotencyKey,
            retry: false,
            timeout: timeout,
          );
        }
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        if (response.statusCode < 400 && response.statusCode != 204) {
          throw const ApiException(
            'Phản hồi từ máy chủ chưa hợp lệ. Vui lòng thử lại.',
          );
        }
        decoded = {};
      }
      final envelope = object(decoded);
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && authenticated) {
          if (version == sessionVersion && sentAccess == accessToken) {
            setSession(null, null);
            await onSessionChanged?.call();
          }
        }
        throw ApiException(
          '${envelope['message'] ?? 'Không thể xử lý yêu cầu (${response.statusCode}).'}',
          response.statusCode,
        );
      }
      return envelope.containsKey('data') ? envelope['data'] : decoded;
    } on TimeoutException {
      throw const ApiException(
        'Kết nối quá lâu. Vui lòng kiểm tra mạng và thử lại.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Chưa kết nối được máy chủ. Kiểm tra backend và địa chỉ API.',
      );
    }
  }

  Future<bool> _refresh(int version) async {
    final sentRefresh = refreshToken;
    try {
      final data = object(
        await request(
          'POST',
          '/auth/refresh-token',
          authenticated: false,
          body: {'refreshToken': sentRefresh},
          retry: false,
        ),
      );
      if (version != sessionVersion) return false;
      if (data['accessToken'] is! String) {
        throw const ApiException('Máy chủ trả về phiên đăng nhập chưa hợp lệ.');
      }
      accessToken = data['accessToken'];
      refreshToken = data['refreshToken'] ?? refreshToken;
      await onSessionChanged?.call();
      return accessToken != null;
    } on ApiException catch (error) {
      if (error.status == 401 || error.status == 403) return false;
      rethrow;
    }
  }

  void close() => client.close();
}
