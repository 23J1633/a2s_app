import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class Bootstrap {
  const Bootstrap({
    required this.client,
    required this.devices,
    this.basePath,
    this.protocol,
    this.avatarDataUrl,
  });
  final MobileClient? client;
  final List<Device> devices;
  final String? basePath;
  final int? protocol;
  final String? avatarDataUrl;

  factory Bootstrap.fromJson(Map<String, dynamic> json) => Bootstrap(
    client: json['client'] is Map
        ? MobileClient.fromJson(
            Map<String, dynamic>.from(json['client'] as Map),
          )
        : null,
    devices: json['devices'] is List
        ? (json['devices'] as List)
              .whereType<Map>()
              .map((item) => Device.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : const <Device>[],
    basePath: json['basePath']?.toString(),
    protocol: (json['protocol'] as num?)?.toInt(),
    avatarDataUrl: json['avatar'] is Map
        ? (json['avatar']['dataUrl']?.toString())
        : null,
  );
}

class A2sApiClient {
  A2sApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String _endpoint = '';
  String _token = '';

  String get endpoint => _endpoint;
  String get token => _token;
  bool get isConfigured => _endpoint.isNotEmpty && _token.isNotEmpty;

  void configure({required String endpoint, String? token}) {
    var value = endpoint.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('/mobile/v1')) {
      _endpoint = value;
    } else {
      _endpoint = '$value/mobile/v1';
    }
    if (token != null) _token = token;
  }

  void setToken(String token) => _token = token;

  Map<String, String> get _headers => <String, String>{
    'accept': 'application/json',
    'content-type': 'application/json',
    if (_token.isNotEmpty) 'authorization': 'Bearer $_token',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    if (_endpoint.isEmpty) throw const ApiException('尚未配置服务器端点');
    final base = Uri.parse(
      '$_endpoint${path.startsWith('/') ? path : '/$path'}',
    );
    return query == null
        ? base
        : base.replace(
            queryParameters: <String, String>{
              ...base.queryParameters,
              ...query,
            },
          );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? extraHeaders,
    bool includeToken = true,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(<String, String>{
      ..._headers,
      if (!includeToken) 'authorization': '',
      ...?extraHeaders,
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    final text = await response.stream.bytesToString();
    Map<String, dynamic> data = <String, dynamic>{};
    if (text.trim().isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(text) as Map);
      } catch (_) {
        throw ApiException(
          '服务器返回了无法识别的数据（HTTP ${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'];
      throw ApiException(
        error is Map
            ? '${error['message'] ?? '请求失败'}'
            : '请求失败（HTTP ${response.statusCode}）',
        code: error is Map ? error['code']?.toString() : null,
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<Bootstrap> login({
    required String adminKey,
    String? name,
    String platform = 'android',
    String? appVersion,
  }) async {
    final data = await _request(
      'POST',
      '/auth/login',
      includeToken: false,
      body: <String, dynamic>{
        'adminKey': adminKey,
        'name': name ?? 'A2S 手机',
        'platform': platform,
        'appVersion': appVersion ?? '1.0.0',
      },
    );
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) throw const ApiException('服务器没有返回手机凭据');
    _token = token;
    return Bootstrap.fromJson(data);
  }

  Future<Bootstrap> redeemPairing(
    PairingPayload pairing, {
    String? name,
    String platform = 'android',
    String? appVersion,
  }) async {
    configure(endpoint: pairing.endpoint);
    final data = await _request(
      'POST',
      '/pairings/redeem',
      includeToken: false,
      body: <String, dynamic>{
        'ticket': pairing.ticket,
        'name': name ?? 'A2S 手机',
        'platform': platform,
        'appVersion': appVersion ?? '1.0.0',
      },
    );
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('二维码兑换没有返回手机凭据');
    }
    _token = token;
    return Bootstrap.fromJson(data);
  }

  Future<Bootstrap> bootstrap() async =>
      Bootstrap.fromJson(await _request('GET', '/bootstrap'));

  Future<List<Device>> devices() async {
    final data = await _request('GET', '/devices');
    return data['items'] is List
        ? (data['items'] as List)
              .whereType<Map>()
              .map((item) => Device.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : <Device>[];
  }

  Future<Bootstrap> unlock(String deviceId, String deviceKey) async {
    final data = await _request(
      'POST',
      '/devices/${Uri.encodeComponent(deviceId)}/unlock',
      body: <String, dynamic>{'deviceKey': deviceKey},
    );
    return Bootstrap.fromJson(data);
  }

  Future<MobileClient?> heartbeat() async {
    final data = await _request('POST', '/clients/heartbeat');
    return data['client'] is Map
        ? MobileClient.fromJson(
            Map<String, dynamic>.from(data['client'] as Map),
          )
        : null;
  }

  Future<Map<String, dynamic>> instance(String instanceId) async =>
      _request('GET', '/instances/${Uri.encodeComponent(instanceId)}');

  Future<Map<String, dynamic>> eventReplay(
    String instanceId, {
    int since = 0,
  }) => _request(
    'GET',
    '/instances/${Uri.encodeComponent(instanceId)}/events',
    query: <String, String>{'since': '$since'},
  );

  Future<List<Session>> sessions(String instanceId) async {
    final data = await _request(
      'GET',
      '/instances/${Uri.encodeComponent(instanceId)}/sessions',
    );
    return data['items'] is List
        ? (data['items'] as List)
              .whereType<Map>()
              .map((item) => Session.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : <Session>[];
  }

  Future<List<Map<String, dynamic>>> archives(String instanceId) async {
    final data = await _request(
      'GET',
      '/instances/${Uri.encodeComponent(instanceId)}/archives',
    );
    final items = data['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> sessionEvents(
    String instanceId,
    String sessionId, {
    int limit = 500,
  }) async => _request(
    'GET',
    '/instances/${Uri.encodeComponent(instanceId)}/session-events/${Uri.encodeComponent(sessionId)}',
    query: <String, String>{'limit': '$limit'},
  );

  Future<Map<String, dynamic>> snapshot(
    String instanceId,
    String sessionId,
  ) async => _request(
    'GET',
    '/instances/${Uri.encodeComponent(instanceId)}/snapshot/${Uri.encodeComponent(sessionId)}',
  );

  Future<Map<String, dynamic>> archiveSession(
    String instanceId,
    String sessionId, {
    String scope = 'server',
  }) async => _request(
    'POST',
    '/instances/${Uri.encodeComponent(instanceId)}/sessions/${Uri.encodeComponent(sessionId)}/archive',
    body: <String, dynamic>{'scope': scope},
  );

  Future<Map<String, dynamic>> restoreSession(
    String instanceId,
    String sessionId,
  ) async => _request(
    'DELETE',
    '/instances/${Uri.encodeComponent(instanceId)}/sessions/${Uri.encodeComponent(sessionId)}/archive',
  );

  Future<dynamic> call(
    String instanceId,
    String method, [
    Map<String, dynamic> params = const <String, dynamic>{},
    Duration? timeout,
    String? requestId,
  ]) async {
    final data = await _request(
      'POST',
      '/instances/${Uri.encodeComponent(instanceId)}/request',
      body: <String, dynamic>{
        'method': method,
        'params': params,
        if (timeout != null) 'timeoutMs': timeout.inMilliseconds,
        'requestId':
            requestId ?? 'mobile-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    if (data['ok'] == false) {
      final error = data['error'];
      throw ApiException(
        error is Map ? '${error['message'] ?? '操作失败'}' : '操作失败',
        code: error is Map ? error['code']?.toString() : null,
      );
    }
    return data['result'];
  }

  Future<void> subscribe(
    String instanceId, {
    List<String>? sessions,
    bool assistantStream = true,
  }) async {
    await _request(
      'POST',
      '/instances/${Uri.encodeComponent(instanceId)}/subscribe',
      body: <String, dynamic>{
        if (sessions != null) 'sessions': sessions,
        'assistantStream': assistantStream,
        'snapshot': true,
      },
    );
  }

  Future<Map<String, dynamic>> stats() => _request('GET', '/stats');

  Future<String?> avatar() async {
    final data = await _request('GET', '/avatar');
    final value = data['avatar'];
    return value is Map ? value['dataUrl']?.toString() : null;
  }

  Future<String?> updateAvatar(String dataUrl, {String? mimeType}) async {
    final data = await _request(
      'PUT',
      '/avatar',
      body: <String, dynamic>{
        'dataUrl': dataUrl,
        if (mimeType != null) 'mimeType': mimeType,
      },
    );
    final value = data['avatar'];
    return value is Map ? value['dataUrl']?.toString() : null;
  }

  Future<void> clearAvatar() async {
    await _request('DELETE', '/avatar');
  }

  Future<List<MobileClient>> adminClients(String adminKey) async {
    final data = await _request(
      'GET',
      '/clients',
      includeToken: false,
      extraHeaders: <String, String>{'x-admin-key': adminKey},
    );
    final items = data['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map(
                (item) =>
                    MobileClient.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <MobileClient>[];
  }

  Future<Map<String, dynamic>> adminRenameClient(
    String adminKey,
    String clientId,
    String name,
  ) => _request(
    'PATCH',
    '/clients/${Uri.encodeComponent(clientId)}',
    includeToken: false,
    extraHeaders: <String, String>{'x-admin-key': adminKey},
    body: <String, dynamic>{'name': name},
  );

  Future<Map<String, dynamic>> adminRevokeClient(
    String adminKey,
    String clientId,
  ) => _request(
    'DELETE',
    '/clients/${Uri.encodeComponent(clientId)}',
    includeToken: false,
    extraHeaders: <String, String>{'x-admin-key': adminKey},
  );

  Future<List<Map<String, dynamic>>> adminKeys(String adminKey) async {
    final data = await _request(
      'GET',
      '/keys',
      includeToken: false,
      extraHeaders: <String, String>{'x-admin-key': adminKey},
    );
    final items = data['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> adminRegisterKey(
    String adminKey,
    String deviceKey,
    String label,
  ) => _request(
    'POST',
    '/keys',
    includeToken: false,
    extraHeaders: <String, String>{'x-admin-key': adminKey},
    body: <String, dynamic>{'key': deviceKey, 'label': label},
  );

  Future<Map<String, dynamic>> adminUpdateKey(
    String adminKey,
    String keyId, {
    String? label,
    String? deviceKey,
  }) => _request(
    'PATCH',
    '/keys/${Uri.encodeComponent(keyId)}',
    includeToken: false,
    extraHeaders: <String, String>{'x-admin-key': adminKey},
    body: <String, dynamic>{
      if (label != null) 'label': label,
      if (deviceKey != null) 'key': deviceKey,
    },
  );

  Future<Map<String, dynamic>> adminRevokeKey(String adminKey, String keyId) =>
      _request(
        'DELETE',
        '/keys/${Uri.encodeComponent(keyId)}',
        includeToken: false,
        extraHeaders: <String, String>{'x-admin-key': adminKey},
      );

  Future<List<String>> adminLogs(String adminKey) async {
    final data = await _request(
      'GET',
      '/logs',
      includeToken: false,
      extraHeaders: <String, String>{'x-admin-key': adminKey},
    );
    final lines = data['lines'];
    return lines is List ? lines.map((item) => '$item').toList() : <String>[];
  }

  Future<Map<String, dynamic>> adminCreatePairing(
    String adminKey, {
    required List<String> deviceIds,
    required String endpoint,
  }) => _request(
    'POST',
    '/pairings',
    includeToken: false,
    extraHeaders: <String, String>{'x-admin-key': adminKey},
    body: <String, dynamic>{'deviceIds': deviceIds, 'endpoint': endpoint},
  );

  Future<void> adminInvalidatePairing(String adminKey) async {
    await _request(
      'DELETE',
      '/pairings',
      includeToken: false,
      extraHeaders: <String, String>{'x-admin-key': adminKey},
    );
  }

  Stream<Map<String, dynamic>> events() async* {
    final request = http.Request('GET', _uri('/stream'));
    request.headers.addAll(_headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.stream.bytesToString();
      throw ApiException(
        '实时连接失败（HTTP ${response.statusCode}）',
        statusCode: response.statusCode,
        code: text,
      );
    }
    String event = 'message';
    final data = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trim());
      } else if (line.isEmpty && data.isNotEmpty) {
        try {
          final decoded = jsonDecode(data.join('\n'));
          if (decoded is Map) {
            yield <String, dynamic>{
              'event': event,
              'data': Map<String, dynamic>.from(decoded),
            };
          }
        } catch (_) {
          // Ignore malformed SSE frames; the next complete frame remains usable.
        }
        event = 'message';
        data.clear();
      }
    }
  }

  void close() => _client.close();
}
