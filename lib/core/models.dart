class Device {
  const Device({
    required this.id,
    required this.label,
    this.online = false,
    this.unlocked = false,
    this.keyFingerprint,
    this.agents = const <AgentInstance>[],
    this.instanceIds = const <String>[],
    this.lastUsedAt,
  });

  final String id;
  final String label;
  final bool online;
  final bool unlocked;
  final String? keyFingerprint;
  final List<AgentInstance> agents;
  final List<String> instanceIds;
  final DateTime? lastUsedAt;

  factory Device.fromJson(Map<String, dynamic> json) {
    final rawAgents = json['agents'];
    return Device(
      id: '${json['id'] ?? json['deviceId'] ?? ''}',
      label: '${json['label'] ?? json['name'] ?? '未命名电脑'}',
      online: json['online'] == true,
      unlocked: json['unlocked'] == true,
      keyFingerprint: json['keyFingerprint']?.toString(),
      agents: rawAgents is List
          ? rawAgents
                .whereType<Map>()
                .map(
                  (item) =>
                      AgentInstance.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <AgentInstance>[],
      instanceIds: json['instanceIds'] is List
          ? List<String>.from(
              (json['instanceIds'] as List).map((item) => '$item'),
            )
          : const <String>[],
      lastUsedAt: _date(json['lastUsedAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'online': online,
    'unlocked': unlocked,
    if (keyFingerprint != null) 'keyFingerprint': keyFingerprint,
    'agents': agents.map((item) => item.toJson()).toList(),
    'instanceIds': instanceIds,
    if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
  };

  Device copyWith({
    bool? unlocked,
    bool? online,
    List<AgentInstance>? agents,
  }) => Device(
    id: id,
    label: label,
    online: online ?? this.online,
    unlocked: unlocked ?? this.unlocked,
    keyFingerprint: keyFingerprint,
    agents: agents ?? this.agents,
    instanceIds: instanceIds,
    lastUsedAt: lastUsedAt,
  );
}

class AgentInstance {
  const AgentInstance({
    required this.instanceId,
    required this.agentType,
    required this.agentName,
    this.online = false,
    this.displayName,
    this.capabilities = const <String, dynamic>{},
    this.liveSessions,
    this.hostname,
    this.platform,
  });

  final String instanceId;
  final String agentType;
  final String agentName;
  final bool online;
  final String? displayName;
  final Map<String, dynamic> capabilities;
  final int? liveSessions;
  final String? hostname;
  final String? platform;

  factory AgentInstance.fromJson(Map<String, dynamic> json) => AgentInstance(
    instanceId: '${json['instanceId'] ?? ''}',
    agentType: '${json['agentType'] ?? 'dsh'}',
    agentName: '${json['agentName'] ?? _agentLabel(json['agentType'])}',
    online: json['online'] == true,
    displayName: json['displayName']?.toString(),
    capabilities: json['capabilities'] is Map
        ? Map<String, dynamic>.from(json['capabilities'] as Map)
        : const <String, dynamic>{},
    liveSessions: (json['liveSessions'] as num?)?.toInt(),
    hostname: json['hostname']?.toString(),
    platform: json['platform']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'instanceId': instanceId,
    'agentType': agentType,
    'agentName': agentName,
    'online': online,
    if (displayName != null) 'displayName': displayName,
    'capabilities': capabilities,
    if (liveSessions != null) 'liveSessions': liveSessions,
    if (hostname != null) 'hostname': hostname,
    if (platform != null) 'platform': platform,
  };

  // The server's displayName is the host label for legacy bridges.  The
  // agentName is the stable product identity used by the web console picker.
  String get title => agentName;

  bool supports(String capability) => capabilities[capability] == true;
}

class Session {
  const Session({
    required this.sessionId,
    this.title = '新对话',
    this.cwd,
    this.updatedAt,
    this.running = false,
    this.status,
    this.paused = false,
    this.lastError,
    this.streamText,
    this.seq,
    this.blank = false,
    this.projections = const <String, dynamic>{},
  });

  final String sessionId;
  final String title;
  final String? cwd;
  final DateTime? updatedAt;
  final bool running;
  final String? status;
  final bool paused;
  final String? lastError;
  final String? streamText;
  final int? seq;
  final bool blank;
  final Map<String, dynamic> projections;

  Session copyWith({
    String? title,
    String? cwd,
    DateTime? updatedAt,
    bool? running,
    String? status,
    bool? paused,
    String? lastError,
    String? streamText,
    int? seq,
    bool? blank,
    Map<String, dynamic>? projections,
  }) => Session(
    sessionId: sessionId,
    title: title ?? this.title,
    cwd: cwd ?? this.cwd,
    updatedAt: updatedAt ?? this.updatedAt,
    running: running ?? this.running,
    status: status ?? this.status,
    paused: paused ?? this.paused,
    lastError: lastError ?? this.lastError,
    streamText: streamText ?? this.streamText,
    seq: seq ?? this.seq,
    blank: blank ?? this.blank,
    projections: projections ?? this.projections,
  );

  factory Session.fromJson(Map<String, dynamic> json) {
    final projections = json['projections'] is Map
        ? Map<String, dynamic>.from(json['projections'] as Map)
        : const <String, dynamic>{};
    final values = projections['values'] is Map
        ? Map<String, dynamic>.from(projections['values'] as Map)
        : const <String, dynamic>{};
    final header = json['header'] is Map
        ? Map<String, dynamic>.from(json['header'] as Map)
        : const <String, dynamic>{};
    final title =
        [json['title'], json['name'], values['title'], header['title']]
            .map((value) => value?.toString().trim() ?? '')
            .firstWhere((value) => value.isNotEmpty, orElse: () => '新对话');
    final seq =
        _number(json['seq']) ??
        _number(json['lastSeq']) ??
        _number(projections['asOfSeq']);
    return Session(
      sessionId: '${json['sessionId'] ?? json['id'] ?? header['id'] ?? ''}',
      title: title,
      cwd: json['cwd']?.toString() ?? header['cwd']?.toString(),
      updatedAt: _date(
        json['updatedAt'] ?? json['createdAt'] ?? header['createdAt'],
      ),
      running: json['running'] == true,
      status: json['status']?.toString(),
      paused: json['paused'] == true,
      lastError: json['lastError']?.toString(),
      streamText: (json['stream'] is Map)
          ? (json['stream']['text']?.toString())
          : json['streamText']?.toString(),
      seq: seq,
      blank: json['blank'] == true,
      projections: projections,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    'title': title,
    if (cwd != null) 'cwd': cwd,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'running': running,
    if (status != null) 'status': status,
    'paused': paused,
    if (lastError != null) 'lastError': lastError,
    if (streamText != null) 'streamText': streamText,
    if (seq != null) 'seq': seq,
    'blank': blank,
    'projections': projections,
  };
}

class Workspace {
  const Workspace({
    required this.id,
    required this.path,
    this.title,
    this.sessionIds = const <String>[],
    this.hidden = false,
  });

  final String id;
  final String path;
  final String? title;
  final List<String> sessionIds;
  final bool hidden;

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
    id: '${json['id'] ?? json['path'] ?? ''}',
    path: '${json['path'] ?? json['cwd'] ?? ''}',
    title: (json['title'] ?? json['name'])?.toString(),
    sessionIds: json['sessionIds'] is List
        ? (json['sessionIds'] as List).map((item) => '$item').toList()
        : const <String>[],
    hidden: json['hidden'] == true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'path': path,
    if (title != null) 'title': title,
    'sessionIds': sessionIds,
    'hidden': hidden,
  };

  String get displayTitle {
    final value = title?.trim() ?? '';
    if (value.isNotEmpty) return value;
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .where((item) => item.isNotEmpty)
        .toList();
    return parts.isEmpty ? path : parts.last;
  }
}

class PairingPayload {
  const PairingPayload({
    required this.endpoint,
    required this.ticket,
    this.expiresAt,
  });
  final String endpoint;
  final String ticket;
  final DateTime? expiresAt;

  factory PairingPayload.fromJson(Map<String, dynamic> json) => PairingPayload(
    endpoint: '${json['endpoint'] ?? ''}',
    ticket: '${json['ticket'] ?? ''}',
    expiresAt: _date(json['expiresAt']),
  );
}

class MobileClient {
  const MobileClient({
    required this.id,
    required this.name,
    this.platform,
    this.appVersion,
    this.lastSeenAt,
    this.authorizedDevices = const <String>[],
  });
  final String id;
  final String name;
  final String? platform;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final List<String> authorizedDevices;

  factory MobileClient.fromJson(Map<String, dynamic> json) => MobileClient(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? 'A2S 手机'}',
    platform: json['platform']?.toString(),
    appVersion: json['appVersion']?.toString(),
    lastSeenAt: _date(json['lastSeenAt']),
    authorizedDevices: json['authorizedDevices'] is List
        ? (json['authorizedDevices'] as List)
              .whereType<Map>()
              .map((item) => '${item['deviceId'] ?? ''}')
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[],
  );
}

String _agentLabel(Object? type) {
  switch ('$type') {
    case 'claude':
      return 'Claude Code';
    case 'codex':
      return 'OpenAI Codex';
    default:
      return 'DeepSeek Harness';
  }
}

DateTime? _date(Object? value) {
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int? _number(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}
