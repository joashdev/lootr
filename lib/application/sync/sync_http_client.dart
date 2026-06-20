import 'dart:convert';

import 'package:http/http.dart' as http;

class SyncHttpResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const SyncHttpResponse({required this.statusCode, required this.body});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isUnauthorized => statusCode == 401;
  bool get isValidationError => statusCode == 422;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => false;
}

class SyncHttpNetworkError extends SyncHttpResponse {
  final String message;

  SyncHttpNetworkError({required this.message})
      : super(statusCode: 0, body: const {});

  @override
  bool get isNetworkError => true;
}

abstract class SyncHttpClient {
  Future<SyncHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  });
}

class SyncHttpClientImpl implements SyncHttpClient {
  final http.Client httpClient;
  final String baseUrl;

  SyncHttpClientImpl({required this.httpClient, required this.baseUrl});

  @override
  Future<SyncHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await httpClient
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> responseBody;
      try {
        responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        responseBody = {};
      }

      return SyncHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } catch (e) {
      return SyncHttpNetworkError(message: e.toString());
    }
  }
}
