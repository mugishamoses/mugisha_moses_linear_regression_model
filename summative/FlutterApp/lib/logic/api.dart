import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// Production Render API. Local dev: --dart-define=API_URL=http://localhost:8000/predict (Android emulator: 10.0.2.2)
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://graduate-debt-api-d2wk.onrender.com/predict');

/// The server rejected one field (HTTP 422).
class ApiFieldError implements Exception {
  ApiFieldError(this.key, this.message);
  final String key, message;
}

/// Network problem, timeout or unexpected server response.
class ApiNetworkError implements Exception {
  ApiNetworkError(this.detail);
  final String detail;
}

class Api {
  Api({http.Client? client, this.url = apiUrl, this.timeout = const Duration(seconds: 90)}) : _client = client ?? http.Client();
  final http.Client _client;
  final String url;
  final Duration timeout; // free Render instance can take ~1 min to wake

  Future<double> predict(Map<String, num> body) async {
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw ApiNetworkError('Error: request timed out after ${timeout.inSeconds} s');
    } catch (_) {
      throw ApiNetworkError('Error: no connection to the server');
    }
    try {
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return (data['predicted_median_debt_usd'] as num).toDouble();
      if (res.statusCode == 422) {
        final d = (data['detail'] as List).first;
        throw ApiFieldError('${(d['loc'] as List).last}', '${d['msg']}');
      }
    } on ApiFieldError {
      rethrow;
    } catch (_) {/* fall through */}
    throw ApiNetworkError('Error: server responded ${res.statusCode}');
  }
}
