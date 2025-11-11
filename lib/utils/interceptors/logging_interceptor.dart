import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Logging Interceptor
/// Logs requests and responses, redacting sensitive information
/// Only logs in debug mode (non-production)
class LoggingInterceptor extends Interceptor {
  final bool enabled;

  LoggingInterceptor({this.enabled = true});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!enabled) {
      return handler.next(options);
    }

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ REQUEST');
    debugPrint('├─────────────────────────────────────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    debugPrint('│ Headers: ${_redactHeaders(options.headers)}');

    if (options.data != null) {
      final data = options.data;
      if (data is Map || data is List) {
        debugPrint('│ Body: ${_redactSensitiveData(jsonEncode(data))}');
      } else if (data is FormData) {
        debugPrint('│ Body: [FormData with ${data.fields.length} fields]');
      } else {
        debugPrint('│ Body: ${_redactSensitiveData(data.toString())}');
      }
    }

    if (options.queryParameters.isNotEmpty) {
      debugPrint('│ Query: ${_redactSensitiveData(options.queryParameters.toString())}');
    }

    debugPrint('└─────────────────────────────────────────────────────────────');

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!enabled) {
      return handler.next(response);
    }

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ RESPONSE');
    debugPrint('├─────────────────────────────────────────────────────────────');
    debugPrint('│ ${response.requestOptions.method} ${response.requestOptions.uri}');
    debugPrint('│ Status: ${response.statusCode} ${response.statusMessage}');

    if (response.data != null) {
      try {
        final data = response.data;
        if (data is Map || data is List) {
          debugPrint('│ Body: ${_redactSensitiveData(jsonEncode(data))}');
        } else {
          debugPrint('│ Body: ${_redactSensitiveData(data.toString())}');
        }
      } catch (e) {
        debugPrint('│ Body: [Unable to parse response]');
      }
    }

    debugPrint('└─────────────────────────────────────────────────────────────');

    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!enabled) {
      return handler.next(err);
    }

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ ERROR');
    debugPrint('├─────────────────────────────────────────────────────────────');
    debugPrint('│ ${err.requestOptions.method} ${err.requestOptions.uri}');
    debugPrint('│ Status: ${err.response?.statusCode ?? 'N/A'}');
    debugPrint('│ Message: ${err.message}');

    if (err.response?.data != null) {
      try {
        final data = err.response!.data;
        if (data is Map || data is List) {
          debugPrint('│ Error Body: ${_redactSensitiveData(jsonEncode(data))}');
        } else {
          debugPrint('│ Error Body: ${_redactSensitiveData(data.toString())}');
        }
      } catch (e) {
        debugPrint('│ Error Body: [Unable to parse error response]');
      }
    }

    debugPrint('└─────────────────────────────────────────────────────────────');

    return handler.next(err);
  }

  /// Redact sensitive headers (Authorization, etc.)
  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final redacted = Map<String, dynamic>.from(headers);
    if (redacted.containsKey('Authorization')) {
      final auth = redacted['Authorization'] as String?;
      if (auth != null && auth.startsWith('Bearer ')) {
        redacted['Authorization'] = 'Bearer [REDACTED]';
      }
    }
    return redacted;
  }

  /// Redact sensitive data from request/response bodies
  String _redactSensitiveData(String data) {
    // Redact common sensitive fields
    final sensitivePatterns = [
      RegExp(r'"password"\s*:\s*"[^"]*"', caseSensitive: false),
      RegExp(r'"token"\s*:\s*"[^"]*"', caseSensitive: false),
      RegExp(r'"access_token"\s*:\s*"[^"]*"', caseSensitive: false),
      RegExp(r'"refresh_token"\s*:\s*"[^"]*"', caseSensitive: false),
      RegExp(r'"authorization"\s*:\s*"[^"]*"', caseSensitive: false),
      RegExp(r'"api_key"\s*:\s*"[^"]*"', caseSensitive: false),
      RegExp(r'"secret"\s*:\s*"[^"]*"', caseSensitive: false),
    ];

    String redacted = data;
    for (final pattern in sensitivePatterns) {
      redacted = redacted.replaceAllMapped(pattern, (match) {
        final matchedText = match.group(0) ?? '';
        final fieldName = matchedText.split(':')[0].replaceAll('"', '').trim();
        return '"$fieldName": "[REDACTED]"';
      });
    }

    // Limit output length to prevent huge logs
    if (redacted.length > 1000) {
      redacted = '${redacted.substring(0, 1000)}... [truncated]';
    }

    return redacted;
  }
}

