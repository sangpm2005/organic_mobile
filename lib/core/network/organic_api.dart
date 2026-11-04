import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../media/upload_file.dart';

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
    List<UploadFile>? files,
    String fileField = 'files',
    String? jsonPart,
    Map<String, String> headers = const {},
    void Function(Map<String, String>)? onResponseHeaders,
    bool followRedirects = true,
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
    final http.BaseRequest req;
    if (files != null) {
      final multipart = http.MultipartRequest(method, uri);
      if (jsonPart != null && body != null) {
        multipart.files.add(
          http.MultipartFile.fromString(
            jsonPart,
            jsonEncode(body),
            contentType: MediaType('application', 'json'),
          ),
        );
      } else if (body != null) {
        multipart.fields.addAll({
          for (final e in body.entries)
            if (e.value != null) e.key: '${e.value}',
        });
      }
      for (final file in files) {
        multipart.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            file.bytes,
            filename: file.name,
            contentType: MediaType.parse(file.contentType),
          ),
        );
      }
      req = multipart;
    } else {
      req = http.Request(method, uri);
    }
    req.headers.addAll(headers);
    req.followRedirects = followRedirects;
    req.headers['Accept'] = 'application/json';
    if (authenticated && accessToken != null) {
      req.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (idempotencyKey != null) req.headers['Idempotency-Key'] = idempotencyKey;
    if (body != null && req is http.Request) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(req),
      ))().timeout(timeout);
      onResponseHeaders?.call(response.headers);
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
            files: files,
            fileField: fileField,
            jsonPart: jsonPart,
            headers: headers,
            onResponseHeaders: onResponseHeaders,
            followRedirects: followRedirects,
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
