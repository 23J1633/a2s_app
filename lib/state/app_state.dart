import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/models.dart';

final apiProvider = Provider<A2sApiClient>((ref) {
  final api = A2sApiClient();
  ref.onDispose(api.close);
  return api;
});

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(ref.read(apiProvider)),
);

enum MotionPreference { system, reduced, off }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.createdAt,
    this.running = false,
    this.kind = 'text',
    this.seq,
    this.usage = const <String, dynamic>{},
    this.feedback,
    this.durationMs,
  });
  final String id;
  final String role;
  final String text;
  final DateTime? createdAt;
  final bool running;
  final String kind;
  final int? seq;
  final Map<String, dynamic> usage;
  final String? feedback;
  final int? durationMs;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: '${json['id'] ?? ''}',
    role: '${json['role'] ?? 'assistant'}',
    text: '${json['text'] ?? ''}',
    createdAt: _cacheDate(json['createdAt']),
    running: json['running'] == true,
    kind: '${json['kind'] ?? 'text'}',
    seq: _cacheInt(json['seq']),
    usage: json['usage'] is Map
        ? Map<String, dynamic>.from(json['usage'] as Map)
        : const <String, dynamic>{},
    feedback: json['feedback']?.toString(),
    durationMs: _cacheInt(json['durationMs']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'role': role,
    'text': text,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    'running': running,
    'kind': kind,
    if (seq != null) 'seq': seq,
    'usage': usage,
    if (feedback != null) 'feedback': feedback,
    if (durationMs != null) 'durationMs': durationMs,
  };

  ChatMessage copyWith({
    String? text,
    bool? running,
    String? kind,
    int? seq,
    Map<String, dynamic>? usage,
    String? feedback,
    bool clearFeedback = false,
    int? durationMs,
  }) => ChatMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
    running: running ?? this.running,
    kind: kind ?? this.kind,
    seq: seq ?? this.seq,
    usage: usage ?? this.usage,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    durationMs: durationMs ?? this.durationMs,
  );
}

class PendingInteraction {
  const PendingInteraction({
    required this.requestId,
    required this.kind,
    required this.sessionId,
    this.data = const <String, dynamic>{},
  });
  final String requestId;
  final String kind;
  final String? sessionId;
  final Map<String, dynamic> data;
}

class AppState {
  const AppState({
    this.initialized = false,
    this.busy = false,
    this.connected = false,
    this.endpoint = '',
    this.devices = const <Device>[],
    this.selectedDeviceId,
    this.selectedInstanceId,
    this.sessions = const <Session>[],
    this.workspaces = const <Workspace>[],
    this.selectedSessionId,
    this.messages = const <ChatMessage>[],
    this.historyLoading = false,
    this.historyHasMore = false,
    this.historyLoadingOlder = false,
    this.historyBeforeSeq,
    this.historyError,
    this.error,
    this.themeMode = ThemeMode.system,
    this.dynamicColor = true,
    this.accentColorValue = 0xFF000000,
    this.locale = 'system',
    this.serifFont = false,
    this.chatBackgroundDataUrl,
    this.avatarDataUrl,
    this.motion = MotionPreference.system,
    this.haptics = true,
    this.drawerOpen = false,
    this.sseConnected = false,
    this.offline = false,
    this.cacheUpdatedAt,
    this.stats,
    this.terminalOutputs = const <String, String>{},
    this.pendingInteractions = const <PendingInteraction>[],
  });

  final bool initialized;
  final bool busy;
  final bool connected;
  final String endpoint;
  final List<Device> devices;
  final String? selectedDeviceId;
  final String? selectedInstanceId;
  final List<Session> sessions;
  final List<Workspace> workspaces;
  final String? selectedSessionId;
  final List<ChatMessage> messages;
  final bool historyLoading;
  final bool historyHasMore;
  final bool historyLoadingOlder;
  final int? historyBeforeSeq;
  final String? historyError;
  final String? error;
  final ThemeMode themeMode;
  final bool dynamicColor;
  final int accentColorValue;
  final String locale;
  final bool serifFont;
  final String? chatBackgroundDataUrl;
  final String? avatarDataUrl;
  final MotionPreference motion;
  final bool haptics;
  final bool drawerOpen;
  final bool sseConnected;

  /// True when the shell is being rendered from the phone's last local cache.
  final bool offline;
  final DateTime? cacheUpdatedAt;
  final Map<String, dynamic>? stats;
  final Map<String, String> terminalOutputs;
  final List<PendingInteraction> pendingInteractions;

  Device? get selectedDevice =>
      devices.where((item) => item.id == selectedDeviceId).firstOrNull;
  AgentInstance? get selectedAgent {
    final id = selectedInstanceId;
    if (id == null) return null;
    for (final device in devices) {
      for (final agent in device.agents) {
        if (agent.instanceId == id) return agent;
      }
    }
    return null;
  }

  bool get hasUnlockedDevice => devices.any((item) => item.unlocked);

  AppState copyWith({
    bool? initialized,
    bool? busy,
    bool? connected,
    String? endpoint,
    List<Device>? devices,
    String? selectedDeviceId,
    bool clearSelectedDevice = false,
    String? selectedInstanceId,
    bool clearSelectedInstance = false,
    List<Session>? sessions,
    List<Workspace>? workspaces,
    String? selectedSessionId,
    bool clearSelectedSession = false,
    List<ChatMessage>? messages,
    bool? historyLoading,
    bool? historyHasMore,
    bool? historyLoadingOlder,
    int? historyBeforeSeq,
    bool clearHistoryBeforeSeq = false,
    String? historyError,
    bool clearHistoryError = false,
    String? error,
    bool clearError = false,
    ThemeMode? themeMode,
    bool? dynamicColor,
    int? accentColorValue,
    String? locale,
    bool? serifFont,
    String? chatBackgroundDataUrl,
    bool clearChatBackground = false,
    String? avatarDataUrl,
    bool clearAvatar = false,
    MotionPreference? motion,
    bool? haptics,
    bool? drawerOpen,
    bool? sseConnected,
    bool? offline,
    DateTime? cacheUpdatedAt,
    bool clearCacheUpdatedAt = false,
    Map<String, dynamic>? stats,
    Map<String, String>? terminalOutputs,
    List<PendingInteraction>? pendingInteractions,
  }) => AppState(
    initialized: initialized ?? this.initialized,
    busy: busy ?? this.busy,
    connected: connected ?? this.connected,
    endpoint: endpoint ?? this.endpoint,
    devices: devices ?? this.devices,
    selectedDeviceId: clearSelectedDevice
        ? null
        : selectedDeviceId ?? this.selectedDeviceId,
    selectedInstanceId: clearSelectedInstance
        ? null
        : selectedInstanceId ?? this.selectedInstanceId,
    sessions: sessions ?? this.sessions,
    workspaces: workspaces ?? this.workspaces,
    selectedSessionId: clearSelectedSession
        ? null
        : selectedSessionId ?? this.selectedSessionId,
    messages: messages ?? this.messages,
    historyLoading: historyLoading ?? this.historyLoading,
    historyHasMore: historyHasMore ?? this.historyHasMore,
    historyLoadingOlder: historyLoadingOlder ?? this.historyLoadingOlder,
    historyBeforeSeq: clearHistoryBeforeSeq
        ? null
        : historyBeforeSeq ?? this.historyBeforeSeq,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    error: clearError ? null : error ?? this.error,
    themeMode: themeMode ?? this.themeMode,
    dynamicColor: dynamicColor ?? this.dynamicColor,
    accentColorValue: accentColorValue ?? this.accentColorValue,
    locale: locale ?? this.locale,
    serifFont: serifFont ?? this.serifFont,
    chatBackgroundDataUrl: clearChatBackground
        ? null
        : chatBackgroundDataUrl ?? this.chatBackgroundDataUrl,
    avatarDataUrl: clearAvatar ? null : avatarDataUrl ?? this.avatarDataUrl,
    motion: motion ?? this.motion,
    haptics: haptics ?? this.haptics,
    drawerOpen: drawerOpen ?? this.drawerOpen,
    sseConnected: sseConnected ?? this.sseConnected,
    offline: offline ?? this.offline,
    cacheUpdatedAt: clearCacheUpdatedAt
        ? null
        : cacheUpdatedAt ?? this.cacheUpdatedAt,
    stats: stats ?? this.stats,
    terminalOutputs: terminalOutputs ?? this.terminalOutputs,
    pendingInteractions: pendingInteractions ?? this.pendingInteractions,
  );
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(this.api) : super(const AppState());

  final A2sApiClient api;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  SharedPreferences? _prefs;
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _eventsRetryTimer;
  Timer? _heartbeatTimer;
  Timer? _contextRefreshTimer;
  Timer? _sessionRefreshTimer;
  int _eventGeneration = 0;
  int _eventRetryAttempt = 0;
  final Map<String, int> _eventSequences = <String, int>{};
  final Map<String, bool> _historyRawMode = <String, bool>{};
  final Set<String> _historyExpanded = <String>{};
  final Set<String> _historyHydrated = <String>{};

  Future<void> initialize() async {
    if (state.initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final endpoint = _prefs?.getString('endpoint') ?? '';
    final token = await _secure.read(key: 'mobileToken') ?? '';
    final theme = _prefs?.getString('theme') ?? 'system';
    final appearanceVersion = _prefs?.getInt('appearanceVersion') ?? 0;
    // Older builds persisted Android wallpaper colors as the default.  Reset
    // that one-time state so the refreshed monochrome UI is the first view
    // after upgrading; users can still enable dynamic colors explicitly.
    final migratedAppearance = appearanceVersion >= 1;
    final dynamicColor = migratedAppearance
        ? (_prefs?.getBool('dynamicColor') ?? false)
        : false;
    final accentColorValue = migratedAppearance
        ? (_prefs?.getInt('accentColor') ?? 0xFF000000)
        : 0xFF000000;
    final locale = _prefs?.getString('locale') ?? 'system';
    final serifFont = _prefs?.getBool('serifFont') ?? false;
    final chatBackgroundDataUrl = _prefs?.getString('chatBackground');
    final motion = _prefs?.getString('motion') ?? 'system';
    api.configure(endpoint: endpoint, token: token);
    _lastToken = token;
    if (!migratedAppearance) {
      await _prefs?.setBool('dynamicColor', false);
      await _prefs?.setInt('accentColor', 0xFF000000);
      await _prefs?.setInt('appearanceVersion', 1);
    }
    state = state.copyWith(
      initialized: true,
      endpoint: endpoint,
      themeMode: _theme(theme),
      dynamicColor: dynamicColor,
      accentColorValue: accentColorValue,
      locale: locale,
      serifFont: serifFont,
      chatBackgroundDataUrl: chatBackgroundDataUrl,
      motion: _motion(motion),
      haptics: _prefs?.getBool('haptics') ?? true,
      clearError: true,
    );
    if (api.isConfigured) {
      await _restoreCachedContext(endpoint);
      try {
        await refresh();
        _scheduleContextRefreshes();
      } catch (_) {
        if (!state.offline && !_hasCachedContext()) {
          state = state.copyWith(connected: false);
        }
      }
    }
  }

  Future<void> connectWithAdmin(
    String endpoint,
    String adminKey, {
    String? deviceName,
  }) async {
    await _run(() async {
      api.configure(endpoint: endpoint);
      final bootstrap = await api.login(
        adminKey: adminKey,
        name: deviceName ?? 'A2S 手机',
      );
      _lastToken = api.token;
      await _persistConnection(api.endpoint, apiToken: true);
      _applyBootstrap(bootstrap);
      _startEvents();
    });
    await _loadSelectedContext();
    _scheduleContextRefreshes();
  }

  Future<void> redeemPairing(
    PairingPayload pairing, {
    String? deviceName,
  }) async {
    await _run(() async {
      final bootstrap = await api.redeemPairing(
        pairing,
        name: deviceName ?? 'A2S 手机',
      );
      _lastToken = api.token;
      await _persistConnection(api.endpoint, apiToken: true);
      _applyBootstrap(bootstrap);
      _startEvents();
    });
    await _loadSelectedContext();
    _scheduleContextRefreshes();
  }

  Future<void> refresh() async {
    if (!api.isConfigured) return;
    try {
      await _run(() async {
        final bootstrap = await api.bootstrap();
        _applyBootstrap(bootstrap);
        _startEvents();
      }, keepError: true);
      await _loadSelectedContext();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await _clearCachedContext();
        state = state.copyWith(connected: false, offline: false);
        return;
      }
      if (_hasCachedContext()) {
        state = state.copyWith(connected: true, offline: true);
      }
    }
  }

  Future<void> refreshDevices() async {
    if (!api.isConfigured) return;
    final devices = await api.devices();
    _applyDevices(devices);
  }

  String _cacheScope([String? endpoint]) => base64Url
      .encode(utf8.encode((endpoint ?? state.endpoint).trim()))
      .replaceAll('=', '');

  bool _hasCachedContext() =>
      state.devices.isNotEmpty ||
      state.sessions.isNotEmpty ||
      state.workspaces.isNotEmpty ||
      state.messages.isNotEmpty;

  Future<void> _restoreCachedContext(String endpoint) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final scope = _cacheScope(endpoint);
    try {
      final devicesJson = prefs.getString('a2s-cache.$scope.devices');
      final devices = devicesJson == null
          ? const <Device>[]
          : (jsonDecode(devicesJson) as List)
                .whereType<Map>()
                .map((item) => Device.fromJson(Map<String, dynamic>.from(item)))
                .toList();
      if (devices.isEmpty) return;
      final selectedDeviceId =
          prefs.getString('a2s-cache.$scope.device') ??
          devices.where((item) => item.unlocked).firstOrNull?.id;
      final selectedDevice = devices
          .where((item) => item.id == selectedDeviceId)
          .firstOrNull;
      final selectedInstanceId =
          prefs.getString('a2s-cache.$scope.instance') ??
          selectedDevice?.agents.firstOrNull?.instanceId;
      final sessions = _readCachedList<Session>(
        prefs.getString('a2s-cache.$scope.sessions.$selectedInstanceId'),
        (item) => Session.fromJson(item),
      );
      final workspaces = _readCachedList<Workspace>(
        prefs.getString('a2s-cache.$scope.workspaces.$selectedInstanceId'),
        (item) => Workspace.fromJson(item),
      );
      final selectedSessionId =
          prefs.getString('a2s-cache.$scope.session.$selectedInstanceId') ??
          sessions.firstOrNull?.sessionId;
      final messages = _readCachedList<ChatMessage>(
        prefs.getString(
          'a2s-cache.$scope.messages.$selectedInstanceId.$selectedSessionId',
        ),
        (item) => ChatMessage.fromJson(item),
      );
      final updated = prefs.getInt('a2s-cache.$scope.updatedAt');
      final avatar = prefs.getString('avatar|$scope');
      state = state.copyWith(
        connected: true,
        offline: true,
        devices: devices,
        selectedDeviceId: selectedDeviceId,
        selectedInstanceId: selectedInstanceId,
        sessions: sessions,
        workspaces: workspaces,
        selectedSessionId: selectedSessionId,
        messages: messages,
        cacheUpdatedAt: updated == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updated),
        avatarDataUrl: avatar == null || avatar.isEmpty ? null : avatar,
        clearAvatar: avatar == null || avatar.isEmpty,
      );
    } catch (_) {
      // Corrupt or obsolete cache must never prevent a fresh connection.
      await _clearCachedContext(endpoint);
    }
  }

  List<T> _readCachedList<T>(
    String? raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw == null || raw.isEmpty) return <T>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <T>[];
    return decoded
        .whereType<Map>()
        .map((item) => parse(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _restoreCachedInstanceContext(String instanceId) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final scope = _cacheScope();
    final sessions = _readCachedList<Session>(
      prefs.getString('a2s-cache.$scope.sessions.$instanceId'),
      (item) => Session.fromJson(item),
    );
    final workspaces = _readCachedList<Workspace>(
      prefs.getString('a2s-cache.$scope.workspaces.$instanceId'),
      (item) => Workspace.fromJson(item),
    );
    final sessionId =
        prefs.getString('a2s-cache.$scope.session.$instanceId') ??
        sessions.firstOrNull?.sessionId;
    final messages = _readCachedList<ChatMessage>(
      prefs.getString('a2s-cache.$scope.messages.$instanceId.$sessionId'),
      (item) => ChatMessage.fromJson(item),
    );
    if (instanceId != state.selectedInstanceId) return;
    state = state.copyWith(
      sessions: sessions,
      workspaces: workspaces,
      selectedSessionId: sessionId,
      messages: messages,
      connected: true,
      offline: true,
    );
  }

  Future<void> _writeCache(String key, Object value) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(key, jsonEncode(value));
    final now = DateTime.now();
    state = state.copyWith(cacheUpdatedAt: now);
    await prefs.setInt(
      'a2s-cache.${_cacheScope()}.updatedAt',
      now.millisecondsSinceEpoch,
    );
  }

  void _persistDevices(List<Device> devices) {
    unawaited(
      _writeCache(
        'a2s-cache.${_cacheScope()}.devices',
        devices.map((item) => item.toJson()).toList(),
      ),
    );
  }

  void _persistSessions(String instanceId, List<Session> sessions) {
    final items = sessions.length > 200 ? sessions.sublist(0, 200) : sessions;
    unawaited(
      _writeCache(
        'a2s-cache.${_cacheScope()}.sessions.$instanceId',
        items.map((item) => item.toJson()).toList(),
      ),
    );
  }

  void _persistWorkspaces(String instanceId, List<Workspace> workspaces) {
    unawaited(
      _writeCache(
        'a2s-cache.${_cacheScope()}.workspaces.$instanceId',
        workspaces.map((item) => item.toJson()).toList(),
      ),
    );
  }

  void _persistMessages(
    String instanceId,
    String sessionId,
    List<ChatMessage> messages,
  ) {
    var items = messages.length > 80
        ? messages.sublist(messages.length - 80)
        : messages;
    while (items.length > 1 &&
        jsonEncode(items.map((item) => item.toJson()).toList()).length >
            1500000) {
      items = items.sublist(1);
    }
    unawaited(
      _writeCache(
        'a2s-cache.${_cacheScope()}.messages.$instanceId.$sessionId',
        items.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> _persistSelection() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final scope = _cacheScope();
    if (state.selectedDeviceId == null) {
      await prefs.remove('a2s-cache.$scope.device');
    } else {
      await prefs.setString('a2s-cache.$scope.device', state.selectedDeviceId!);
    }
    if (state.selectedInstanceId == null) {
      await prefs.remove('a2s-cache.$scope.instance');
    } else {
      await prefs.setString(
        'a2s-cache.$scope.instance',
        state.selectedInstanceId!,
      );
    }
    if (state.selectedInstanceId != null && state.selectedSessionId != null) {
      await prefs.setString(
        'a2s-cache.$scope.session.${state.selectedInstanceId}',
        state.selectedSessionId!,
      );
    }
  }

  Future<void> _clearCachedContext([String? endpoint]) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final prefix = 'a2s-cache.${_cacheScope(endpoint)}.';
    for (final key
        in prefs.getKeys().where((item) => item.startsWith(prefix)).toList()) {
      await prefs.remove(key);
    }
  }

  /// Re-fetches the currently selected agent's durable lists.
  ///
  /// Bridge adapters can finish reconnecting after the mobile bootstrap has
  /// completed. The drawer uses this method when it opens so a stale first
  /// response cannot leave the project list empty for the rest of the run.
  Future<void> refreshSelectedContext() => _loadSelectedContext();

  void _scheduleContextRefreshes() {
    _contextRefreshTimer?.cancel();
    // The first pass is intentionally delayed: after a server restart the
    // bridge may need a few seconds to restore its durable session/workspace
    // projections. Each pass is guarded by the selected instance id.
    _contextRefreshTimer = Timer(const Duration(seconds: 6), () {
      unawaited(_loadSelectedContext());
      _contextRefreshTimer = Timer(const Duration(seconds: 14), () {
        unawaited(_loadSelectedContext());
      });
    });
  }

  Future<void> unlock(Device device, String deviceKey) async {
    await _run(() async {
      final bootstrap = await api.unlock(device.id, deviceKey);
      _applyBootstrap(bootstrap);
      _selectDevice(device.id);
    });
    await _loadSelectedContext();
  }

  Future<void> _loadSelectedContext() async {
    final id = state.selectedInstanceId;
    if (id == null || id.isEmpty || !state.hasUnlockedDevice) return;
    await _loadContextForInstance(id);
  }

  Future<void> _loadContextForInstance(String instanceId) async {
    // Bootstrap and durable bridge projections have independent lifecycles.
    // A reconnecting adapter must not make the whole mobile connection look
    // offline just because its first session.list is temporarily unavailable.
    try {
      await loadSessions(instanceId);
      final selectedSessionId = state.selectedSessionId;
      final historyKey = selectedSessionId == null
          ? null
          : '$instanceId|$selectedSessionId';
      if (selectedSessionId != null &&
          historyKey != null &&
          !_historyHydrated.contains(historyKey) &&
          !state.historyLoading &&
          instanceId == state.selectedInstanceId) {
        final session = state.sessions
            .where((item) => item.sessionId == selectedSessionId)
            .firstOrNull;
        if (session != null) await selectSession(session);
      }
    } catch (_) {
      // The retry timer and the drawer refresh will try again.
    }
    try {
      await loadWorkspaces(instanceId);
    } catch (_) {
      // A bridge without a registry can still group sessions by cwd.
    }
  }

  Future<void> selectDevice(Device device) async {
    final first = device.agents.firstOrNull;
    state = state.copyWith(
      selectedDeviceId: device.id,
      selectedInstanceId: first?.instanceId,
      clearSelectedSession: true,
      sessions: const <Session>[],
      workspaces: const <Workspace>[],
      messages: const <ChatMessage>[],
      historyLoading: false,
      historyHasMore: false,
      historyLoadingOlder: false,
      clearHistoryBeforeSeq: true,
      clearHistoryError: true,
      drawerOpen: false,
    );
    unawaited(_persistSelection());
    if (first != null && device.unlocked) {
      await _restoreCachedInstanceContext(first.instanceId);
      await _loadContextForInstance(first.instanceId);
    }
  }

  Future<void> selectAgent(AgentInstance agent) async {
    final device = state.devices
        .where((item) => item.id == state.selectedDeviceId)
        .firstOrNull;
    state = state.copyWith(
      selectedInstanceId: agent.instanceId,
      selectedSessionId: null,
      sessions: const <Session>[],
      workspaces: const <Workspace>[],
      messages: const <ChatMessage>[],
      historyLoading: false,
      historyHasMore: false,
      historyLoadingOlder: false,
      clearHistoryBeforeSeq: true,
      clearHistoryError: true,
      drawerOpen: false,
    );
    unawaited(_persistSelection());
    if (device?.unlocked == true) {
      await _restoreCachedInstanceContext(agent.instanceId);
      await _loadContextForInstance(agent.instanceId);
    }
  }

  Future<void> loadSessions([String? instanceId]) async {
    final id = instanceId ?? state.selectedInstanceId;
    if (id == null || id.isEmpty || !state.hasUnlockedDevice) return;
    await _run(() async {
      List<Session> sessions = const <Session>[];
      Object? lastError;
      for (var attempt = 0; attempt < 3; attempt += 1) {
        try {
          sessions = await api.sessions(id);
          lastError = null;
          break;
        } catch (error) {
          lastError = error;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)),
            );
          }
        }
      }
      if (lastError != null) throw lastError;
      if (id != state.selectedInstanceId) return;
      // A bridge may persist the first prompt and its generated title in two
      // separate projection writes.  Keep the local prompt title while the
      // remote row still reports its placeholder so a refresh cannot make a
      // freshly completed chat jump back to “新对话”.
      final previousById = <String, Session>{
        for (final item in state.sessions) item.sessionId: item,
      };
      sessions = sessions.map((remote) {
        final previous = previousById[remote.sessionId];
        if (previous == null ||
            !_isPlaceholderSessionTitle(remote.title) ||
            _isPlaceholderSessionTitle(previous.title)) {
          return remote;
        }
        return remote.copyWith(
          title: previous.title,
          updatedAt: remote.updatedAt ?? previous.updatedAt,
          running: remote.running || previous.running,
        );
      }).toList();
      final selectedStillExists =
          state.selectedSessionId != null &&
          sessions.any(
            (session) => session.sessionId == state.selectedSessionId,
          );
      state = state.copyWith(
        sessions: sessions,
        clearSelectedSession: !selectedStillExists,
        messages: selectedStillExists ? null : const <ChatMessage>[],
        historyLoading: false,
        historyHasMore: selectedStillExists ? null : false,
        historyLoadingOlder: selectedStillExists ? null : false,
        clearHistoryBeforeSeq: !selectedStillExists,
        clearHistoryError: true,
        clearError: true,
      );
      _persistSessions(id, sessions);
      unawaited(_persistSelection());
      if (state.selectedSessionId == null && sessions.isNotEmpty) {
        final first = sessions.firstWhere(
          (session) => !session.blank && session.title != '新对话',
          orElse: () => sessions.first,
        );
        await selectSession(first);
      }
    }, keepError: true);
  }

  bool _isPlaceholderSessionTitle(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ||
        normalized == '新对话' ||
        normalized.toLowerCase() == 'new chat';
  }

  Future<void> loadWorkspaces([String? instanceId]) async {
    final id = instanceId ?? state.selectedInstanceId;
    if (id == null || id.isEmpty || !state.hasUnlockedDevice) return;
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final result = await api.call(id, 'workspace.list');
        final raw = result is Map
            ? (result['items'] ?? result['workspaces'] ?? result['projects'])
            : result;
        final workspaces = raw is List
            ? raw
                  .whereType<Map>()
                  .map(
                    (item) =>
                        Workspace.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .where((item) => !item.hidden && item.path.isNotEmpty)
                  .toList()
            : const <Workspace>[];
        if (id == state.selectedInstanceId) {
          state = state.copyWith(workspaces: workspaces, clearError: true);
          _persistWorkspaces(id, workspaces);
        }
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 500 * (attempt + 1)),
          );
        }
      }
    }
    // A bridge without a workspace registry can still provide cwd groups.
    // Keep the previous registry in place so a transient reconnect does not
    // erase project titles already visible in the drawer.
    if (lastError != null && id == state.selectedInstanceId) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<void> selectSession(Session session) async {
    final instanceId = state.selectedInstanceId;
    if (instanceId == null || instanceId.isEmpty) return;
    final historyKey = '$instanceId|${session.sessionId}';
    _historyExpanded.remove(historyKey);
    _historyRawMode.remove(historyKey);
    _historyHydrated.remove(historyKey);
    state = state.copyWith(
      selectedSessionId: session.sessionId,
      messages: const <ChatMessage>[],
      historyLoading: true,
      historyHasMore: false,
      historyLoadingOlder: false,
      clearHistoryBeforeSeq: true,
      clearHistoryError: true,
      drawerOpen: false,
    );
    unawaited(_persistSelection());
    final cachedMessages = _readCachedList<ChatMessage>(
      _prefs?.getString(
        'a2s-cache.${_cacheScope()}.messages.$instanceId.${session.sessionId}',
      ),
      (item) => ChatMessage.fromJson(item),
    );
    if (cachedMessages.isNotEmpty && _isCurrentSession(instanceId, session)) {
      state = state.copyWith(messages: cachedMessages, historyLoading: false);
    }
    try {
      final result = await _historyResult(instanceId, session, raw: false);
      if (!_isCurrentSession(instanceId, session)) return;
      var messages = _messagesFrom(result);
      var rawMode = false;
      if (messages.isEmpty && _isCurrentSession(instanceId, session)) {
        // Some older bridges expose the raw durable event view more reliably
        // than the message-aligned view. It has the same event shapes and is
        // safe to use as a fallback for detached sessions.
        try {
          final events = await _historyResult(instanceId, session, raw: true);
          if (!_isCurrentSession(instanceId, session)) return;
          messages = _messagesFrom(events);
          rawMode = messages.isNotEmpty;
          if (messages.isNotEmpty) {
            _setHistoryWindow(instanceId, session.sessionId, events);
          }
        } catch (_) {
          // A bridge without session.events can still be used for live chats.
        }
      }
      if (messages.isNotEmpty && _isCurrentSession(instanceId, session)) {
        state = state.copyWith(messages: messages);
        _persistMessages(instanceId, session.sessionId, messages);
      }
      if (!rawMode && _isCurrentSession(instanceId, session)) {
        _setHistoryWindow(instanceId, session.sessionId, result);
      }
      _historyRawMode[historyKey] = rawMode;
      if (_isCurrentSession(instanceId, session)) {
        state = state.copyWith(historyLoading: false, clearHistoryError: true);
        _historyHydrated.add(historyKey);
        unawaited(_loadFeedback(instanceId, session.sessionId));
        // Subscription snapshots can be slow for adapters with large tool
        // histories. Start it after the durable page is visible so it cannot
        // block the history request behind the adapter's request queue.
        unawaited(
          api
              .subscribe(instanceId, sessions: <String>[session.sessionId])
              .catchError((_) {}),
        );
      }
    } catch (error) {
      if (_isCurrentSession(instanceId, session)) {
        state = state.copyWith(
          historyLoading: false,
          historyError: '对话历史加载失败：$error',
        );
      }
    }
  }

  bool _isCurrentSession(String instanceId, Session session) =>
      instanceId == state.selectedInstanceId &&
      session.sessionId == state.selectedSessionId;

  Future<void> _loadFeedback(String instanceId, String sessionId) async {
    try {
      final result = await api.call(
        instanceId,
        'message.feedback.list',
        <String, dynamic>{'sessionId': sessionId},
      );
      final raw = result is Map ? result['items'] : result;
      if (raw is! List ||
          instanceId != state.selectedInstanceId ||
          sessionId != state.selectedSessionId) {
        return;
      }
      final ratings = <int, String>{};
      for (final item in raw.whereType<Map>()) {
        final seq = item['seq'] is num
            ? (item['seq'] as num).toInt()
            : int.tryParse('${item['seq'] ?? ''}');
        final rating = item['rating']?.toString();
        if (seq != null && rating != null && rating.isNotEmpty) {
          ratings[seq] = rating;
        }
      }
      if (ratings.isEmpty) return;
      state = state.copyWith(
        messages: state.messages
            .map(
              (item) => ratings[item.seq] == null
                  ? item
                  : item.copyWith(feedback: ratings[item.seq]),
            )
            .toList(),
      );
      _persistCurrentMessages();
    } catch (_) {
      // Feedback is optional on older bridges.
    }
  }

  Future<dynamic> _historyResult(
    String instanceId,
    Session session, {
    required bool raw,
    int? beforeSeq,
  }) async {
    var watermark = await _historyWatermark(instanceId, session);
    for (var attempt = 0; attempt < 8; attempt += 1) {
      try {
        return await api.call(
          instanceId,
          raw ? 'session.events' : 'session.history',
          <String, dynamic>{
            'sessionId': session.sessionId,
            'throughSeq': watermark,
            if (beforeSeq != null && beforeSeq >= 0) 'beforeSeq': beforeSeq,
            if (raw) 'limit': 160 else 'maxMessages': 32,
          },
        );
      } on ApiException catch (error) {
        // DSH can advance its projection one event before the durable cursor
        // settles. Move the cursor back and retry the same page.
        if (watermark > 0 && error.message.contains('past cursor')) {
          watermark -= 1;
          continue;
        }
        rethrow;
      }
    }
    throw const ApiException('历史游标暂时不可用');
  }

  Future<int> _historyWatermark(String instanceId, Session session) async {
    var watermark = session.seq ?? 0;
    try {
      final detail = await api.call(
        instanceId,
        'session.get',
        <String, dynamic>{'sessionId': session.sessionId},
      );
      if (detail is Map) {
        final value =
            detail['seq'] ??
            (detail['projections'] is Map
                ? (detail['projections'] as Map)['asOfSeq']
                : null);
        final remote = value is num ? value.toInt() : int.tryParse('$value');
        if (remote != null && remote > watermark) watermark = remote;
      }
    } catch (_) {
      // The row watermark is enough for Claude/Codex and live sessions.
    }
    return watermark;
  }

  void _setHistoryWindow(String instanceId, String sessionId, Object? result) {
    final oldest = _oldestHistorySeq(result);
    final hasMore = result is Map && result['hasMore'] == true;
    state = state.copyWith(
      historyHasMore: hasMore && oldest != null,
      historyLoadingOlder: false,
      historyBeforeSeq: oldest,
      clearHistoryError: true,
    );
    if (oldest == null && hasMore) {
      // A bridge that claims another page but does not expose a cursor would
      // otherwise make every top-of-list scroll issue the same request.
      state = state.copyWith(historyHasMore: false);
    }
  }

  int? _oldestHistorySeq(Object? result) {
    if (result is! Map) return null;
    final direct = result['oldestSeq'] ?? result['startSeq'];
    final directValue = direct is num
        ? direct.toInt()
        : int.tryParse('$direct');
    if (directValue != null && directValue >= 0) return directValue;
    final raw = result['records'] ?? result['events'] ?? result['items'];
    if (raw is! List) return null;
    int? oldest;
    for (final item in raw) {
      final wrapper = item is Map
          ? Map<String, dynamic>.from(item)
          : const <String, dynamic>{};
      final event = wrapper['event'] is Map
          ? Map<String, dynamic>.from(wrapper['event'] as Map)
          : wrapper;
      final rawSeq = event['seq'];
      final seq = rawSeq is num ? rawSeq.toInt() : int.tryParse('$rawSeq');
      if (seq != null && seq >= 0 && (oldest == null || seq < oldest)) {
        oldest = seq;
      }
    }
    return oldest;
  }

  /// Loads the page immediately before the currently resident history.
  ///
  /// The web client uses the same message-boundary `beforeSeq` contract. The
  /// caller keeps the scroll anchor while this method prepends the page.
  Future<bool> loadOlderHistory() async {
    final instanceId = state.selectedInstanceId;
    final sessionId = state.selectedSessionId;
    final beforeSeq = state.historyBeforeSeq;
    if (instanceId == null ||
        sessionId == null ||
        beforeSeq == null ||
        !state.historyHasMore ||
        state.historyLoadingOlder) {
      return false;
    }
    final session = state.sessions
        .where((item) => item.sessionId == sessionId)
        .firstOrNull;
    if (session == null) return false;
    final key = '$instanceId|$sessionId';
    final rawMode = _historyRawMode[key] ?? false;
    state = state.copyWith(historyLoadingOlder: true, clearHistoryError: true);
    try {
      // A page can consist entirely of tool/reasoning records which are not
      // rendered as standalone chat bubbles. Walk a few cursors in that case
      // so one upward gesture still reaches the next visible user/assistant
      // message instead of falsely marking the transcript exhausted.
      Object? result;
      var cursor = beforeSeq;
      var serverHasMore = false;
      int? nextBefore;
      var older = <ChatMessage>[];
      for (var attempt = 0; attempt < 6; attempt += 1) {
        result = await _historyResult(
          instanceId,
          session,
          raw: rawMode,
          beforeSeq: cursor,
        );
        final page = _messagesFrom(result);
        final pageBefore = _oldestHistorySeq(result);
        serverHasMore = result is Map && result['hasMore'] == true;
        if (page.isNotEmpty) older = <ChatMessage>[...older, ...page];
        nextBefore = pageBefore;
        if (older.isNotEmpty ||
            !serverHasMore ||
            pageBefore == null ||
            pageBefore >= cursor) {
          break;
        }
        cursor = pageBefore;
      }
      if (instanceId != state.selectedInstanceId ||
          sessionId != state.selectedSessionId) {
        return false;
      }
      if (older.isEmpty || nextBefore == null || nextBefore >= beforeSeq) {
        state = state.copyWith(
          historyHasMore: false,
          historyLoadingOlder: false,
        );
        return false;
      }
      final messages = _mergeHistoryMessages(older, state.messages);
      state = state.copyWith(
        messages: messages,
        historyHasMore: serverHasMore,
        historyLoadingOlder: false,
        historyBeforeSeq: nextBefore,
        clearHistoryError: true,
      );
      _historyExpanded.add(key);
      _persistMessages(instanceId, sessionId, messages);
      return true;
    } catch (error) {
      if (instanceId == state.selectedInstanceId &&
          sessionId == state.selectedSessionId) {
        state = state.copyWith(
          historyLoadingOlder: false,
          historyError: '加载更早的消息失败：$error',
        );
      }
      return false;
    }
  }

  Future<void> createSession({String? cwd, String? title}) async {
    final instanceId = state.selectedInstanceId;
    if (instanceId == null) return;
    await _run(() async {
      final result = await api
          .call(instanceId, 'session.create', <String, dynamic>{
            'title': title ?? '新对话',
            if (cwd != null && cwd.trim().isNotEmpty) 'cwd': cwd.trim(),
          });
      final map = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      final source = map['session'] is Map
          ? Map<String, dynamic>.from(map['session'] as Map)
          : map;
      final session = Session.fromJson(<String, dynamic>{
        ...source,
        'title': source['title'] ?? '新对话',
      });
      state = state.copyWith(
        sessions: <Session>[session, ...state.sessions],
        selectedSessionId: session.sessionId,
        messages: const <ChatMessage>[],
        historyLoading: false,
        clearHistoryError: true,
        drawerOpen: false,
      );
      await loadWorkspaces(instanceId);
    });
  }

  Future<void> sendPrompt(
    String text, {
    List<Map<String, dynamic>>? content,
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && (content == null || content.isEmpty)) ||
        state.selectedInstanceId == null) {
      return;
    }
    var sessionId = state.selectedSessionId;
    if (sessionId == null) {
      await createSession();
      sessionId = state.selectedSessionId;
    }
    if (sessionId == null) return;
    final instanceId = state.selectedInstanceId;
    if (instanceId == null || instanceId.isEmpty) return;
    final now = DateTime.now();
    final promptTitle = _promptTitle(trimmed.isEmpty ? '已发送附件' : trimmed);
    final currentSession = state.sessions
        .where((item) => item.sessionId == sessionId)
        .firstOrNull;
    if (currentSession != null) {
      final shouldName =
          currentSession.title.trim().isEmpty ||
          currentSession.title == '新对话' ||
          currentSession.blank;
      final updatedSessions = state.sessions
          .map(
            (item) => item.sessionId == sessionId
                ? item.copyWith(
                    title: shouldName ? promptTitle : item.title,
                    updatedAt: now,
                    running: true,
                    blank: false,
                  )
                : item,
          )
          .toList();
      state = state.copyWith(sessions: updatedSessions);
      _persistSessions(instanceId, updatedSessions);
    }
    final message = ChatMessage(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      text: trimmed.isEmpty ? '已发送附件' : trimmed,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: <ChatMessage>[...state.messages, message]);
    _persistMessages(instanceId, sessionId, state.messages);
    try {
      final blocks = content;
      // Keep the client identity stable across relay retries and let each
      // bridge correlate the optimistic message with its final response.
      final requestId =
          'mobile-prompt-${DateTime.now().microsecondsSinceEpoch}';
      await api.call(
        instanceId,
        'session.prompt',
        <String, dynamic>{
          'sessionId': sessionId,
          'requestId': requestId,
          'clientMessageId': requestId,
          if (blocks == null) 'text': trimmed,
          if (blocks != null) 'content': blocks,
        },
        const Duration(minutes: 5),
        requestId,
      );
    } catch (error) {
      state = state.copyWith(
        messages: <ChatMessage>[
          ...state.messages,
          ChatMessage(
            id: 'error-${DateTime.now().microsecondsSinceEpoch}',
            role: 'system',
            kind: 'error',
            text: '$error',
            createdAt: DateTime.now(),
          ),
        ],
        error: '$error',
      );
    }
    _persistMessages(instanceId, sessionId, state.messages);
  }

  String _promptTitle(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '新对话';
    return normalized.length > 36
        ? '${normalized.substring(0, 36).trimRight()}…'
        : normalized;
  }

  Future<bool> forkFromMessage(ChatMessage message) async {
    final instanceId = state.selectedInstanceId;
    final sessionId = state.selectedSessionId;
    if (instanceId == null || sessionId == null || message.seq == null) {
      return false;
    }
    try {
      final result = await api.call(
        instanceId,
        'session.fork',
        <String, dynamic>{'sessionId': sessionId, 'atSeq': message.seq},
      );
      final map = result is Map
          ? Map<String, dynamic>.from(result)
          : const <String, dynamic>{};
      final childId = map['sessionId']?.toString();
      await loadSessions(instanceId);
      if (childId == null || childId.isEmpty) return false;
      final child = state.sessions
          .where((item) => item.sessionId == childId)
          .firstOrNull;
      if (child == null) return false;
      await selectSession(child);
      return true;
    } catch (error) {
      state = state.copyWith(error: '$error');
      return false;
    }
  }

  Future<void> interrupt() async {
    final instanceId = state.selectedInstanceId;
    final sessionId = state.selectedSessionId;
    if (instanceId == null || sessionId == null) return;
    await api
        .call(instanceId, 'session.interrupt', <String, dynamic>{
          'sessionId': sessionId,
        })
        .catchError((_) => null);
  }

  Future<void> setMessageFeedback(ChatMessage message, String rating) async {
    final instanceId = state.selectedInstanceId;
    final sessionId = state.selectedSessionId;
    final seq = message.seq;
    if (instanceId == null || sessionId == null || seq == null) return;
    try {
      await api.call(instanceId, 'message.feedback', <String, dynamic>{
        'sessionId': sessionId,
        'seq': seq,
        'rating': rating,
      });
      state = state.copyWith(
        messages: state.messages
            .map(
              (item) => item.id == message.id
                  ? item.copyWith(
                      feedback: rating == 'none' ? null : rating,
                      clearFeedback: rating == 'none',
                    )
                  : item,
            )
            .toList(),
      );
      _persistCurrentMessages();
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  Future<void> respondApproval(String requestId, String outcome) async {
    final instanceId = state.selectedInstanceId;
    if (instanceId == null) return;
    try {
      await api.call(instanceId, 'approval.respond', <String, dynamic>{
        'requestId': requestId,
        'outcome': outcome,
      });
      _removeInteraction(requestId);
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  Future<void> answerQuestion(
    String requestId,
    List<Map<String, dynamic>> answers,
  ) async {
    final instanceId = state.selectedInstanceId;
    if (instanceId == null) return;
    try {
      await api.call(instanceId, 'question.answer', <String, dynamic>{
        'requestId': requestId,
        'answers': answers,
      });
      _removeInteraction(requestId);
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  void _removeInteraction(String requestId) {
    state = state.copyWith(
      pendingInteractions: state.pendingInteractions
          .where((item) => item.requestId != requestId)
          .toList(),
    );
  }

  Future<void> openStats() async {
    try {
      state = state.copyWith(stats: await api.stats());
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  String _draftKey() =>
      'draft|${state.endpoint}|${state.selectedDeviceId ?? ''}|${state.selectedInstanceId ?? ''}|${state.selectedSessionId ?? ''}';

  Future<String> loadDraft() async => _prefs?.getString(_draftKey()) ?? '';

  Future<void> saveDraft(String value) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (value.isEmpty) {
      await prefs.remove(_draftKey());
    } else {
      await prefs.setString(_draftKey(), value);
    }
  }

  Future<void> clearLocalCache() async {
    await _clearCachedContext();
    final prefs = _prefs;
    if (prefs != null) {
      final prefix = 'draft|${state.endpoint}|';
      for (final key
          in prefs
              .getKeys()
              .where((item) => item.startsWith(prefix))
              .toList()) {
        await prefs.remove(key);
      }
    }
    // Clear the in-memory projection as well as SharedPreferences.  Keeping
    // the old lists here made a cache clear look ineffective until the next
    // full refresh, which was especially confusing after archiving test chats.
    state = state.copyWith(
      sessions: const <Session>[],
      workspaces: const <Workspace>[],
      messages: const <ChatMessage>[],
      clearSelectedSession: true,
      clearHistoryError: true,
      clearError: true,
      clearCacheUpdatedAt: true,
    );
  }

  void setTheme(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs?.setString('theme', mode.name);
  }

  void setDynamicColor(bool value) {
    state = state.copyWith(dynamicColor: value);
    _prefs?.setBool('dynamicColor', value);
  }

  void setAccentColor(Color color) {
    final value = color.toARGB32();
    state = state.copyWith(accentColorValue: value);
    _prefs?.setInt('accentColor', value);
  }

  void setLocale(String value) {
    final locale = <String>{'system', 'zh-CN', 'en-US'}.contains(value)
        ? value
        : 'system';
    state = state.copyWith(locale: locale);
    _prefs?.setString('locale', locale);
  }

  void setSerifFont(bool value) {
    state = state.copyWith(serifFont: value);
    _prefs?.setBool('serifFont', value);
  }

  Future<void> setChatBackground(String dataUrl) async {
    state = state.copyWith(chatBackgroundDataUrl: dataUrl);
    await _prefs?.setString('chatBackground', dataUrl);
  }

  Future<void> clearChatBackground() async {
    state = state.copyWith(clearChatBackground: true);
    await _prefs?.remove('chatBackground');
  }

  Future<void> updateAvatarFromBytes(List<int> bytes, String mimeType) async {
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    final value = await api.updateAvatar(dataUrl, mimeType: mimeType);
    state = state.copyWith(avatarDataUrl: value, clearAvatar: value == null);
    await _prefs?.setString('avatar|${_cacheScope()}', value ?? '');
  }

  Future<void> clearAvatar() async {
    await api.clearAvatar();
    state = state.copyWith(clearAvatar: true);
    await _prefs?.remove('avatar|${_cacheScope()}');
  }

  void setMotion(MotionPreference value) {
    state = state.copyWith(motion: value);
    _prefs?.setString('motion', value.name);
  }

  void setHaptics(bool value) {
    state = state.copyWith(haptics: value);
    _prefs?.setBool('haptics', value);
  }

  void toggleDrawer([bool? value]) =>
      state = state.copyWith(drawerOpen: value ?? !state.drawerOpen);

  Future<void> logout() async {
    final cachedEndpoint = state.endpoint;
    await _events?.cancel();
    _events = null;
    _eventsRetryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _eventSequences.clear();
    await _secure.delete(key: 'mobileToken');
    api.setToken('');
    _lastToken = '';
    await _prefs?.remove('endpoint');
    await _clearCachedContext(cachedEndpoint);
    api.configure(endpoint: '');
    state = state.copyWith(
      connected: false,
      endpoint: '',
      devices: const <Device>[],
      sessions: const <Session>[],
      workspaces: const <Workspace>[],
      messages: const <ChatMessage>[],
      clearSelectedDevice: true,
      clearSelectedInstance: true,
      clearSelectedSession: true,
      sseConnected: false,
      offline: false,
      clearCacheUpdatedAt: true,
      clearAvatar: true,
      terminalOutputs: const <String, String>{},
      pendingInteractions: const <PendingInteraction>[],
    );
  }

  @override
  void dispose() {
    _eventsRetryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _contextRefreshTimer?.cancel();
    _sessionRefreshTimer?.cancel();
    _events?.cancel();
    super.dispose();
  }

  Future<void> _persistConnection(
    String endpoint, {
    required bool apiToken,
  }) async {
    await _prefs?.setString(
      'endpoint',
      endpoint.replaceFirst(RegExp(r'/mobile/v1$'), ''),
    );
    if (apiToken) {
      await _secure.write(key: 'mobileToken', value: _tokenFromApi());
    }
  }

  String _tokenFromApi() {
    // The API client deliberately does not expose the secret. The secure token
    // is persisted by this notifier immediately after login/redeem.
    return _lastToken;
  }

  String _lastToken = '';

  void _applyBootstrap(Bootstrap bootstrap) {
    if (api.token.isNotEmpty) _lastToken = api.token;
    state = state.copyWith(
      connected: true,
      offline: false,
      endpoint: api.endpoint.replaceFirst(RegExp(r'/mobile/v1$'), ''),
      avatarDataUrl: bootstrap.avatarDataUrl,
      clearAvatar: bootstrap.avatarDataUrl == null,
      clearError: true,
    );
    final prefs = _prefs;
    if (prefs != null) {
      final key = 'avatar|${_cacheScope()}';
      if (bootstrap.avatarDataUrl == null) {
        unawaited(prefs.remove(key));
      } else {
        unawaited(prefs.setString(key, bootstrap.avatarDataUrl!));
      }
    }
    _applyDevices(bootstrap.devices);
  }

  void _applyDevices(List<Device> devices) {
    final selectedDevice =
        state.selectedDeviceId != null &&
            devices.any((item) => item.id == state.selectedDeviceId)
        ? state.selectedDeviceId
        : devices.where((item) => item.unlocked).firstOrNull?.id;
    final device = devices
        .where((item) => item.id == selectedDevice)
        .firstOrNull;
    final selectedInstance =
        state.selectedInstanceId != null &&
            device?.agents.any(
                  (item) => item.instanceId == state.selectedInstanceId,
                ) ==
                true
        ? state.selectedInstanceId
        : device?.agents.firstOrNull?.instanceId;
    state = state.copyWith(
      devices: devices,
      selectedDeviceId: selectedDevice,
      selectedInstanceId: selectedInstance,
    );
    _persistDevices(devices);
    unawaited(_persistSelection());
  }

  void _selectDevice(String id) {
    final device = state.devices.where((item) => item.id == id).firstOrNull;
    state = state.copyWith(
      selectedDeviceId: id,
      selectedInstanceId: device?.agents.firstOrNull?.instanceId,
    );
    unawaited(_persistSelection());
  }

  void _startEvents() {
    final generation = ++_eventGeneration;
    _eventsRetryTimer?.cancel();
    _events?.cancel();
    _eventRetryAttempt = 0;
    _events = api.events().listen(
      (event) {
        if (generation != _eventGeneration) return;
        _eventRetryAttempt = 0;
        state = state.copyWith(sseConnected: true);
        _handleEvent(event['data']);
      },
      onError: (_) {
        if (generation == _eventGeneration) {
          state = state.copyWith(sseConnected: false);
          _scheduleEventsRetry(generation);
        }
      },
      onDone: () {
        if (generation == _eventGeneration) {
          state = state.copyWith(sseConnected: false);
          _scheduleEventsRetry(generation);
        }
      },
    );
    unawaited(_recoverEvents(generation));
    _heartbeatTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _heartbeat(),
    );
  }

  Future<void> _recoverEvents(int generation) async {
    if (generation != _eventGeneration || !state.connected) return;
    final instanceId = state.selectedInstanceId;
    if (instanceId == null || instanceId.isEmpty) return;
    final since = _eventSequences[instanceId] ?? 0;
    try {
      final result = await api.eventReplay(instanceId, since: since);
      if (generation != _eventGeneration) return;
      final items = result['items'];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          _handleEvent(<String, dynamic>{
            'instanceId': instanceId,
            'frame': Map<String, dynamic>.from(item),
          });
        }
      }
      if (result['gap'] == true) {
        await loadSessions(instanceId);
      }
    } catch (_) {
      // A live SSE stream remains the source of truth when the bounded replay
      // endpoint is unavailable on an older bridge.
    }
  }

  Future<void> _heartbeat() async {
    if (!state.connected || !api.isConfigured) return;
    try {
      await api.heartbeat();
    } catch (_) {
      // The next heartbeat or SSE reconnect will recover transient failures.
    }
  }

  void _scheduleEventsRetry(int generation) {
    if (generation != _eventGeneration || !state.connected) return;
    if (_eventsRetryTimer?.isActive == true) return;
    final seconds = 1 << (_eventRetryAttempt.clamp(0, 5));
    _eventRetryAttempt++;
    _eventsRetryTimer = Timer(Duration(seconds: seconds), () {
      if (generation == _eventGeneration && state.connected) _startEvents();
    });
  }

  void _handleEvent(Object? raw) {
    if (raw is! Map) return;
    final outer = Map<String, dynamic>.from(raw);
    final event = outer['frame'] is Map
        ? Map<String, dynamic>.from(outer['frame'] as Map)
        : outer;
    final kind = event['kind']?.toString() ?? '';
    final instanceId =
        outer['instanceId']?.toString() ??
        event['instanceId']?.toString() ??
        '';
    final sequence = (event['seq'] as num?)?.toInt();
    if (kind.isNotEmpty && instanceId.isNotEmpty && sequence != null) {
      final previous = _eventSequences[instanceId];
      if (previous != null && sequence <= previous) return;
      _eventSequences[instanceId] = sequence;
    }
    final data = event['data'];
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    final sid = event['sessionId']?.toString() ?? map['sessionId']?.toString();
    if (kind == 'terminal/output' || kind == 'terminal/exit') {
      final terminalId = map['terminalId']?.toString();
      if (terminalId != null && terminalId.isNotEmpty) {
        final previous = state.terminalOutputs[terminalId] ?? '';
        final chunk = kind == 'terminal/output'
            ? map['data']?.toString() ?? ''
            : '\n[终端已退出：${map['code'] ?? map['signal'] ?? 'unknown'}]\n';
        final combined = ('$previous$chunk');
        state = state.copyWith(
          terminalOutputs: <String, String>{
            ...state.terminalOutputs,
            terminalId: combined.length > 1024 * 1024
                ? combined.substring(combined.length - 1024 * 1024)
                : combined,
          },
        );
      }
      return;
    }
    if (kind == 'approval/request' || kind == 'question/request') {
      final requestId = map['requestId']?.toString();
      if (requestId != null && requestId.isNotEmpty) {
        final item = PendingInteraction(
          requestId: requestId,
          kind: kind == 'approval/request' ? 'approval' : 'question',
          sessionId: sid ?? map['sessionId']?.toString(),
          data: map,
        );
        state = state.copyWith(
          pendingInteractions: <PendingInteraction>[
            ...state.pendingInteractions.where(
              (existing) => existing.requestId != requestId,
            ),
            item,
          ],
        );
      }
      return;
    }
    if (kind == 'message/feedback') {
      final seq = map['seq'] is num
          ? (map['seq'] as num).toInt()
          : int.tryParse('${map['seq'] ?? ''}');
      final rating = map['rating']?.toString();
      if (seq != null && rating != null && sid == state.selectedSessionId) {
        state = state.copyWith(
          messages: state.messages
              .map(
                (item) => item.seq == seq
                    ? item.copyWith(
                        feedback: rating == 'none' ? null : rating,
                        clearFeedback: rating == 'none',
                      )
                    : item,
              )
              .toList(),
        );
      }
      return;
    }
    if (kind == 'bridge/resync') {
      final selected = state.selectedInstanceId;
      if (selected != null) unawaited(loadSessions(selected));
      return;
    }
    if (kind == 'workspace/changed') {
      if (instanceId == state.selectedInstanceId) {
        unawaited(loadWorkspaces(instanceId));
      }
      return;
    }
    if (kind == 'session/created' ||
        kind == 'session/added' ||
        kind == 'session/removed' ||
        kind == 'session/disposed') {
      if (instanceId == state.selectedInstanceId) {
        unawaited(loadSessions(instanceId));
      }
      return;
    }
    if (kind == 'session/assistant-stream' && sid == state.selectedSessionId) {
      final frame = map['frame'];
      final text = frame is Map
          ? _streamText(frame['chunk'] ?? frame['text'])
          : '';
      if (text.isNotEmpty) {
        _appendAssistant(text, running: frame is Map && frame['type'] != 'end');
      }
      if (frame is Map && frame['type']?.toString() == 'end') {
        // End frames often carry no text.  Still settle the optimistic
        // assistant row so its actions become available immediately.
        _appendAssistant('', running: false);
        if (instanceId == state.selectedInstanceId && sid != null) {
          _scheduleSessionRefresh(instanceId, sid);
        }
      }
    } else if (kind == 'session/event' && sid == state.selectedSessionId) {
      final type = map['type']?.toString() ?? '';
      if (type == 'assistant/message' || type.contains('assistant')) {
        final message = map['message'] is Map ? map['message'] : map;
        final text = _historyText(
          message is Map ? (message['content'] ?? message['text']) : message,
        );
        final usage = map['usage'] is Map
            ? Map<String, dynamic>.from(map['usage'] as Map)
            : const <String, dynamic>{};
        final eventSeq = event['seq'] is num
            ? (event['seq'] as num).toInt()
            : int.tryParse('${event['seq'] ?? ''}');
        if (text.trim().isNotEmpty || usage.isNotEmpty) {
          _appendAssistant(
            text,
            running: false,
            seq: eventSeq,
            usage: usage,
            durationMs: _durationFrom(map),
          );
        } else {
          _appendAssistant('', running: false);
        }
        if (instanceId == state.selectedInstanceId && sid != null) {
          _scheduleSessionRefresh(instanceId, sid);
        }
      }
    } else if (kind == 'session/status') {
      final sessions = state.sessions
          .map(
            (item) => item.sessionId == sid
                ? Session.fromJson(<String, dynamic>{
                    ...item.toJson(),
                    ...map,
                    'sessionId': item.sessionId,
                    if (map['title'] == null) 'title': item.title,
                  })
                : item,
          )
          .toList();
      state = state.copyWith(sessions: sessions);
      _persistSessions(instanceId, sessions);
      if (instanceId == state.selectedInstanceId && sid != null) {
        final running =
            map['running'] == true || map['status']?.toString() == 'running';
        if (!running) _scheduleSessionRefresh(instanceId, sid);
      }
    }
  }

  int? _durationFrom(Map<String, dynamic> value) {
    final raw = value['durationMs'] ?? value['duration'] ?? value['elapsedMs'];
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  void _scheduleSessionRefresh(String instanceId, String sessionId) {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer(const Duration(milliseconds: 260), () {
      unawaited(_refreshCurrentSession(instanceId, sessionId));
    });
  }

  Future<void> _refreshCurrentSession(
    String instanceId,
    String sessionId,
  ) async {
    if (instanceId != state.selectedInstanceId ||
        sessionId != state.selectedSessionId) {
      return;
    }
    try {
      await loadSessions(instanceId);
      if (instanceId != state.selectedInstanceId ||
          sessionId != state.selectedSessionId) {
        return;
      }
      final session = state.sessions
          .where((item) => item.sessionId == sessionId)
          .firstOrNull;
      if (session == null) return;
      final result = await _historyResult(instanceId, session, raw: false);
      if (instanceId != state.selectedInstanceId ||
          sessionId != state.selectedSessionId) {
        return;
      }
      final messages = _messagesFrom(result);
      final historyKey = '$instanceId|$sessionId';
      final preserveOlder = _historyExpanded.contains(historyKey);
      if (messages.isNotEmpty) {
        final nextMessages = preserveOlder
            ? _mergeHistoryMessages(messages, state.messages)
            : messages;
        state = state.copyWith(messages: nextMessages, historyLoading: false);
        if (!preserveOlder) {
          _setHistoryWindow(instanceId, sessionId, result);
        }
        _persistMessages(instanceId, sessionId, nextMessages);
      } else {
        state = state.copyWith(
          messages: state.messages
              .map(
                (item) => item.role == 'assistant'
                    ? item.copyWith(running: false)
                    : item,
              )
              .toList(),
          historyLoading: false,
        );
      }
      _historyRawMode[historyKey] = false;
      unawaited(_loadFeedback(instanceId, sessionId));
    } catch (_) {
      // The optimistic row already contains the finished response.  A later
      // live event or explicit refresh can fill in the durable projection.
      state = state.copyWith(
        messages: state.messages
            .map(
              (item) => item.role == 'assistant'
                  ? item.copyWith(running: false)
                  : item,
            )
            .toList(),
      );
    }
  }

  void _appendAssistant(
    String text, {
    required bool running,
    int? seq,
    Map<String, dynamic>? usage,
    int? durationMs,
  }) {
    if (text.isEmpty &&
        !running &&
        !state.messages.any(
          (item) => item.role == 'assistant' && item.running,
        )) {
      return;
    }
    final existing = state.messages
        .where((item) => item.role == 'assistant' && item.running)
        .firstOrNull;
    if (existing != null) {
      final nextText = !running && text.trim().isNotEmpty
          ? (text.length >= existing.text.length &&
                    text.startsWith(existing.text)
                ? text
                : '${existing.text}$text')
          : '${existing.text}$text';
      state = state.copyWith(
        messages: state.messages
            .map(
              (item) => item.id == existing.id
                  ? item.copyWith(
                      text: nextText,
                      running: running,
                      seq: seq,
                      usage: usage == null || usage.isEmpty ? null : usage,
                      durationMs: durationMs,
                    )
                  : item,
            )
            .toList(),
      );
      _persistCurrentMessages();
    } else {
      final last = state.messages.reversed
          .where((item) => item.role == 'assistant')
          .firstOrNull;
      if (last != null &&
          text.trim().isNotEmpty &&
          (last.text == text ||
              last.text.startsWith(text) ||
              text.startsWith(last.text))) {
        final merged = text.length >= last.text.length ? text : last.text;
        state = state.copyWith(
          messages: state.messages
              .map(
                (item) => item.id == last.id
                    ? item.copyWith(
                        text: merged,
                        running: running,
                        seq: seq,
                        usage: usage == null || usage.isEmpty ? null : usage,
                        durationMs: durationMs,
                      )
                    : item,
              )
              .toList(),
        );
        _persistCurrentMessages();
        return;
      }
      state = state.copyWith(
        messages: <ChatMessage>[
          ...state.messages,
          ChatMessage(
            id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
            role: 'assistant',
            text: text,
            createdAt: DateTime.now(),
            running: running,
            seq: seq,
            usage: usage ?? const <String, dynamic>{},
            durationMs: durationMs,
          ),
        ],
      );
      _persistCurrentMessages();
    }
  }

  void _persistCurrentMessages() {
    final instanceId = state.selectedInstanceId;
    final sessionId = state.selectedSessionId;
    if (instanceId != null && sessionId != null) {
      _persistMessages(instanceId, sessionId, state.messages);
    }
  }

  String _streamText(Object? value) {
    if (value is String) return value;
    if (value is List) return value.map(_streamText).join();
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final direct = map['text'] ?? map['content'];
      if (direct != null) return _streamText(direct);
      final delta = map['delta'] ?? map['message'];
      if (delta != null) return _streamText(delta);
      final choices = map['choices'];
      if (choices is List && choices.isNotEmpty) {
        return _streamText(choices.first);
      }
    }
    return '';
  }

  List<ChatMessage> _messagesFrom(Object? result) {
    if (result is! Map) return const <ChatMessage>[];
    final raw =
        result['records'] ??
        result['messages'] ??
        result['items'] ??
        result['events'];
    if (raw is! List) return const <ChatMessage>[];
    final output = <ChatMessage>[];
    final seen = <String>{};
    for (final item in raw.whereType<Map>()) {
      final wrapper = Map<String, dynamic>.from(item);
      final event = wrapper['event'] is Map
          ? Map<String, dynamic>.from(wrapper['event'] as Map)
          : wrapper;
      final type = '${event['type'] ?? event['kind'] ?? ''}';
      final data = event['data'] is Map
          ? Map<String, dynamic>.from(event['data'] as Map)
          : event;
      final message = data['message'] is Map
          ? Map<String, dynamic>.from(data['message'] as Map)
          : data;
      final source = data['source'] ?? message['source'];
      final sourceKind = source is Map ? source['kind']?.toString() : null;
      final role =
          message['role']?.toString() ??
          (type.startsWith('user/')
              ? 'user'
              : type.startsWith('assistant/')
              ? 'assistant'
              : '');
      if (role != 'user' && role != 'assistant') continue;
      if (role == 'user' && sourceKind != null && sourceKind != 'user') {
        continue;
      }
      final text = _historyText(
        message['content'] ??
            message['text'] ??
            data['content'] ??
            data['text'],
      );
      if (text.trim().isEmpty) continue;
      final id =
          '${message['id'] ?? event['seq'] ?? DateTime.now().microsecondsSinceEpoch}';
      final dedupe = '$role|$id|$text';
      if (!seen.add(dedupe)) continue;
      final usage = data['usage'] is Map
          ? Map<String, dynamic>.from(data['usage'] as Map)
          : const <String, dynamic>{};
      final seqValue = event['seq'] is num
          ? (event['seq'] as num).toInt()
          : int.tryParse('${event['seq'] ?? ''}');
      final durationValue =
          data['durationMs'] ?? data['duration'] ?? data['elapsedMs'];
      output.add(
        ChatMessage(
          id: id,
          role: role,
          text: text,
          createdAt: _eventDate(event['time']) ?? DateTime.now(),
          seq: seqValue,
          usage: usage,
          durationMs: durationValue is num
              ? durationValue.toInt()
              : int.tryParse('$durationValue'),
        ),
      );
    }
    return _groupAssistantMessages(output);
  }

  List<ChatMessage> _mergeHistoryMessages(
    List<ChatMessage> older,
    List<ChatMessage> current,
  ) {
    final combined = <ChatMessage>[];
    final seen = <String>{};
    for (final message in <ChatMessage>[...older, ...current]) {
      final identity =
          '${message.role}|${message.seq ?? message.id}|${message.text.trim()}';
      if (seen.add(identity)) combined.add(message);
    }
    return _groupAssistantMessages(combined);
  }

  // A single model turn can contain several assistant/message records
  // (reasoning, tool calls and a final answer). The web client presents that
  // turn as one transcript item with one action row at its tail. Fold adjacent
  // assistant records here so mobile does not repeat statistics, feedback and
  // branch controls after every step.
  List<ChatMessage> _groupAssistantMessages(List<ChatMessage> input) {
    if (input.length < 2) return input;
    final grouped = <ChatMessage>[];
    for (final message in input) {
      final previous = grouped.isEmpty ? null : grouped.last;
      if (previous == null ||
          previous.role != 'assistant' ||
          message.role != 'assistant') {
        grouped.add(message);
        continue;
      }
      final separator =
          previous.text.trim().isEmpty || message.text.trim().isEmpty
          ? ''
          : '\n\n';
      final mergedText = previous.text == message.text
          ? previous.text
          : '${previous.text}$separator${message.text}';
      grouped[grouped.length - 1] = ChatMessage(
        id: previous.id,
        role: 'assistant',
        text: mergedText,
        createdAt: previous.createdAt ?? message.createdAt,
        running: previous.running || message.running,
        kind: previous.kind,
        seq: message.seq ?? previous.seq,
        usage: _mergeUsage(previous.usage, message.usage),
        feedback: message.feedback ?? previous.feedback,
        durationMs: _sumNullable(previous.durationMs, message.durationMs),
      );
    }
    return grouped;
  }

  Map<String, dynamic> _mergeUsage(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    if (first.isEmpty) return second;
    if (second.isEmpty) return first;
    final merged = <String, dynamic>{...first};
    for (final entry in second.entries) {
      final left = _numberValue(merged[entry.key]);
      final right = _numberValue(entry.value);
      if (left != null && right != null) {
        merged[entry.key] = left + right;
      } else {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  int? _numberValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  int? _sumNullable(int? first, int? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first + second;
  }

  String _historyText(Object? value) {
    if (value is String) return value;
    if (value is List) {
      return value.map(_historyText).join();
    }
    if (value is Map) {
      final type = value['type']?.toString();
      if (type == 'tool-result' || type == 'tool-call' || type == 'reasoning') {
        return '';
      }
      return _historyText(
        value['text'] ?? value['content'] ?? value['message'],
      );
    }
    return value?.toString() ?? '';
  }

  DateTime? _eventDate(Object? value) {
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool keepError = false,
  }) async {
    state = state.copyWith(busy: true, clearError: !keepError);
    try {
      await action();
    } on ApiException catch (error) {
      state = state.copyWith(
        error: error.message,
        connected: error.statusCode == 401 ? false : state.connected,
      );
      rethrow;
    } catch (error) {
      state = state.copyWith(error: '$error');
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  ThemeMode _theme(String value) =>
      ThemeMode.values.where((item) => item.name == value).firstOrNull ??
      ThemeMode.system;
  MotionPreference _motion(String value) =>
      MotionPreference.values.where((item) => item.name == value).firstOrNull ??
      MotionPreference.system;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

DateTime? _cacheDate(Object? value) {
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.tryParse('$value');
}

int? _cacheInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}
