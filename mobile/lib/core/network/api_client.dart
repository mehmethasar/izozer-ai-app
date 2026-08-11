import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mazdek_ai/core/config/app_config.dart';
import 'package:mazdek_ai/core/storage/offline_cache.dart';
import 'package:mazdek_ai/core/storage/settings_store.dart';
import 'package:mazdek_ai/core/storage/token_store.dart';
import 'package:mazdek_ai/models/models.dart';

final class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override String toString() => message;
}

final class ApiResult<T> {
  const ApiResult(this.data, {this.fromCache = false});
  final T data;
  final bool fromCache;
}

final class ApiClient {
  ApiClient({required this._tokens, required this._settings, required this._cache, http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final TokenStore _tokens;
  final SettingsStore _settings;
  final OfflineCache _cache;
  final http.Client _http;
  Future<AuthResponse>? _refreshing;

  Future<Uri> _uri(String path) async {
    final base = await _settings.apiBaseUrl();
    if (base.trim().isEmpty || !AppConfig.isSecureApiUrl(base)) {
      throw const ApiException('Güvenli sunucu adresi yapılandırılmadı.');
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized');
  }

  Future<AuthResponse> login(String email, String password) async {
    final json = await _requestJson('/api/auth/login', method: 'POST', body: {'email': email.trim(), 'password': password}, authenticated: false, cache: false);
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResponse> appleLogin({required String identityToken, required String nonce, String? authorizationCode, String? name}) async {
    final body = <String, dynamic>{'identityToken': identityToken, 'nonce': nonce};
    if (authorizationCode != null) body['authorizationCode'] = authorizationCode;
    if (name != null) body['name'] = name;
    final json = await _requestJson('/api/auth/apple', method: 'POST', body: body, authenticated: false, cache: false);
    return AuthResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> health() async => (await _requestJson('/health', authenticated: false, cache: false)) as Map<String, dynamic>;
  Future<AppUser> me() async => AppUser.fromJson((await _requestJson('/api/me')) as Map<String, dynamic>);
  Future<ApiResult<DashboardSummary>> dashboard() async { final r = await _getWithCache('/api/dashboard'); return ApiResult(DashboardSummary.fromJson(r.data as Map<String,dynamic>), fromCache: r.fromCache); }
  Future<List<ConversationItem>> chatHistory() async => ((await _requestJson('/api/chat/history?limit=80')) as List).whereType<Map<String,dynamic>>().map(ConversationItem.fromJson).toList();
  Future<ChatResponse> chat(String message) async => ChatResponse.fromJson((await _requestJson('/api/chat', method: 'POST', body: {'message': message}, cache: false)) as Map<String,dynamic>);
  Future<Map<String,dynamic>> confirm(String actionId) async => (await _requestJson('/api/actions/confirm', method: 'POST', body: {'actionId': actionId}, cache: false)) as Map<String,dynamic>;
  Future<PendingAction> cancel(String actionId) async => PendingAction.fromJson((await _requestJson('/api/actions/cancel', method: 'POST', body: {'actionId': actionId}, cache: false)) as Map<String,dynamic>);
  Future<List<PendingAction>> pendingActions() async => ((await _requestJson('/api/actions/pending')) as List).whereType<Map<String,dynamic>>().map(PendingAction.fromJson).toList();

  Future<ApiResult<List<EntityRecord>>> records(String endpoint) async {
    final r = await _getWithCache(endpoint);
    final list = (r.data as List).whereType<Map<String,dynamic>>().map((e) => EntityRecord.fromJson(e, endpoint)).toList();
    return ApiResult(list, fromCache: r.fromCache);
  }

  Future<Map<String, dynamic>> integrationStatus() async => (await _requestJson('/api/settings/integrations')) as Map<String,dynamic>;
  Future<Map<String, dynamic>> readiness() async => (await _requestJson('/api/admin/readiness')) as Map<String,dynamic>;
  Future<Map<String, dynamic>> syncKolayBi() async => (await _requestJson('/api/sync/kolaybi', method: 'POST', body: const {}, cache: false)) as Map<String,dynamic>;
  Future<Map<String, dynamic>> testKolayBi() async => (await _requestJson('/api/sync/kolaybi/test', cache: false)) as Map<String,dynamic>;
  Future<Map<String, dynamic>> changePassword(String current, String next) async => (await _requestJson('/api/me/password', method: 'POST', body: {'currentPassword': current, 'newPassword': next}, cache: false)) as Map<String,dynamic>;


  Future<Map<String, dynamic>> updateIntegrationSettings(Map<String, dynamic> values) async =>
      (await _requestJson('/api/settings/integrations', method: 'PUT', body: values, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> testOpenAI() async =>
      (await _requestJson('/api/settings/integrations/test/openai', method: 'POST', body: const {}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> testAPNS() async =>
      (await _requestJson('/api/settings/integrations/test/apns', method: 'POST', body: const {}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> testFCM() async =>
      (await _requestJson('/api/settings/integrations/test/fcm', method: 'POST', body: const {}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> testNotification() async =>
      (await _requestJson('/api/settings/integrations/test/notification', method: 'POST', body: const {}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> kolayBiSyncStatus() async =>
      (await _requestJson('/api/sync/kolaybi/status', cache: false)) as Map<String, dynamic>;

  Future<Map<String, dynamic>> linkApple({required String identityToken, required String nonce, required String authorizationCode}) async =>
      (await _requestJson('/api/me/apple/link', method: 'POST', body: {'identityToken': identityToken, 'nonce': nonce, 'authorizationCode': authorizationCode}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> unlinkApple() async =>
      (await _requestJson('/api/me/apple/link', method: 'DELETE', body: const {}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> deleteAccount({required String currentPassword, required String confirmation}) async =>
      (await _requestJson('/api/me', method: 'DELETE', body: {'currentPassword': currentPassword, 'confirmation': confirmation}, cache: false)) as Map<String, dynamic>;

  Future<File> exportAccountData() => download('/api/me/export', 'mazdek-hesap-verileri.json');
  Future<Map<String, dynamic>> detail(String endpoint) async =>
      (await _requestJson(endpoint)) as Map<String, dynamic>;
  Future<List<EntityRecord>> users() async =>
      ((await _requestJson('/api/admin/users')) as List).whereType<Map<String, dynamic>>().map((e) => EntityRecord.fromJson(e, '/api/admin/users')).toList();
  Future<List<EntityRecord>> auditLogs({int limit = 250}) async =>
      ((await _requestJson('/api/admin/audit?limit=$limit')) as List).whereType<Map<String, dynamic>>().map((e) => EntityRecord.fromJson(e, '/api/admin/audit')).toList();
  Future<List<EntityRecord>> backups({int limit = 50}) async =>
      ((await _requestJson('/api/admin/maintenance/backups?limit=$limit')) as List).whereType<Map<String, dynamic>>().map((e) => EntityRecord.fromJson(e, '/api/admin/maintenance/backups')).toList();
  Future<Map<String, dynamic>> createBackup() async =>
      (await _requestJson('/api/admin/maintenance/backup', method: 'POST', body: const {}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> runMaintenance() async =>
      (await _requestJson('/api/admin/maintenance/run', method: 'POST', body: const {}, cache: false)) as Map<String, dynamic>;

  Future<Map<String, dynamic>> registerDeviceToken(String token, {required String provider, required String platform, String environment = 'sandbox'}) async =>
      (await _requestJson('/api/notifications/device', method: 'POST', body: {'token': token, 'provider': provider, 'platform': platform, 'environment': environment}, cache: false)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> unregisterDeviceToken(String token) async =>
      (await _requestJson('/api/notifications/device', method: 'DELETE', body: {'token': token}, cache: false)) as Map<String, dynamic>;

  Future<ChatResponse> uploadAttachment({required File file, required String message, String extractedText = ''}) async {
    final json = await _multipart('/api/chat/attachment', file: file, fieldName: 'document', fields: {'message': message, if (extractedText.isNotEmpty) 'extractedText': extractedText});
    return ChatResponse.fromJson(json);
  }

  Future<File> download(String path, String fileName) async {
    final response = await _authorizedSend(() async {
      return http.Request('GET', await _uri(path));
    });
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException('Dosya indirilemedi.', statusCode: response.statusCode);
    final bytes = await response.stream.toBytes();
    final directory = await Directory.systemTemp.createTemp('mazdek_ai_');
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Map<String,dynamic>> _multipart(String path, {required File file, required String fieldName, required Map<String,String> fields}) async {
    Future<http.BaseRequest> build() async {
      final request = http.MultipartRequest('POST', await _uri(path));
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
      return request;
    }
    final response = await _authorizedSend(build);
    final text = await response.stream.bytesToString();
    final decoded = text.isEmpty ? <String,dynamic>{} : jsonDecode(text);
    if (response.statusCode < 200 || response.statusCode >= 300) throw _error(decoded, response.statusCode);
    return decoded as Map<String,dynamic>;
  }

  Future<ApiResult<dynamic>> _getWithCache(String path) async {
    try {
      final data = await _requestJson(path);
      return ApiResult(data);
    } on SocketException catch (_) {
      final cached = await _cache.read(path);
      if (cached == null) rethrow;
      return ApiResult(jsonDecode(cached), fromCache: true);
    } on TimeoutException catch (_) {
      final cached = await _cache.read(path);
      if (cached == null) rethrow;
      return ApiResult(jsonDecode(cached), fromCache: true);
    } on http.ClientException catch (_) {
      final cached = await _cache.read(path);
      if (cached == null) rethrow;
      return ApiResult(jsonDecode(cached), fromCache: true);
    }
  }

  Future<dynamic> _requestJson(String path, {String method = 'GET', Map<String,dynamic>? body, bool authenticated = true, bool cache = true, bool retry = true}) async {
    final uri = await _uri(path);
    final headers = <String,String>{'Accept': 'application/json'};
    if (authenticated) { final token = await _tokens.accessToken; if (token != null) headers['Authorization'] = 'Bearer $token'; }
    if (body != null) headers['Content-Type'] = 'application/json';
    final response = await _http.send(http.Request(method, uri)..headers.addAll(headers)..body = body == null ? '' : jsonEncode(body)).timeout(const Duration(seconds: 60));
    final text = await response.stream.bytesToString();
    final decoded = text.isEmpty ? <String,dynamic>{} : jsonDecode(text);
    if (response.statusCode == 401 && authenticated && retry) {
      await _refreshAccessToken();
      return _requestJson(path, method: method, body: body, authenticated: authenticated, cache: cache, retry: false);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) throw _error(decoded, response.statusCode);
    if (method == 'GET' && authenticated && cache) await _cache.write(path, text);
    return decoded;
  }

  Future<http.StreamedResponse> _authorizedSend(Future<http.BaseRequest> Function() builder, {bool retry = true}) async {
    Future<http.StreamedResponse> send() async {
      final request = await builder();
      final token = await _tokens.accessToken;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      return _http.send(request);
    }
    var response = await send();
    if (response.statusCode == 401 && retry) {
      await response.stream.drain<void>();
      await _refreshAccessToken();
      response = await send();
    }
    return response;
  }

  Future<AuthResponse> _refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!;
    final completer = Completer<AuthResponse>();
    _refreshing = completer.future;
    try {
      final token = await _tokens.refreshToken;
      if (token == null) throw const ApiException('Oturum süresi doldu.');
      final json = await _requestJson('/api/auth/refresh', method: 'POST', body: {'refreshToken': token}, authenticated: false, cache: false, retry: false);
      final auth = AuthResponse.fromJson(json as Map<String,dynamic>);
      await _tokens.saveSession(accessToken: auth.accessToken, refreshToken: auth.refreshToken, userJson: auth.userJson());
      completer.complete(auth);
      return auth;
    } catch (error, stack) {
      completer.completeError(error, stack);
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  ApiException _error(dynamic body, int status) {
    if (body is Map<String,dynamic>) {
      return ApiException(body['message']?.toString() ?? body['error']?.toString() ?? 'İşlem tamamlanamadı.', statusCode: status);
    }
    return ApiException('İşlem tamamlanamadı.', statusCode: status);
  }

  Future<void> logout() async {
    final refresh = await _tokens.refreshToken;
    if (refresh != null) {
      try { await _requestJson('/api/auth/logout', method: 'POST', body: {'refreshToken': refresh}, authenticated: false, cache: false); } catch (_) {}
    }
    await _tokens.clearSession();
    await _cache.clearAll();
  }
}
