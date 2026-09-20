import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xterm/xterm.dart';

import 'core/models.dart';
import 'core/api_client.dart';
import 'state/app_state.dart';

void _popDialog(BuildContext context, [Object? result]) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(context).pop(result);
}

void _disposeDialogControllerLater(TextEditingController controller) {
  // showDialog resolves as soon as pop starts, while the route can still
  // rebuild its TextField during the exit animation. Dispose after that frame
  // so the animation never observes a dead controller.
  Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
}

// The default visual language is black and white; users can opt into a
// restrained accent color from Appearance settings.
const _seed = Color(0xFF000000);
const _chatSerifFamily = 'A2SCjkSerif';
const _chatSerifFallback = <String>[
  'Noto Serif CJK SC',
  'Source Han Serif SC',
  'STSong',
  'SimSun',
  'serif',
];

TextStyle _chatTextStyle(TextStyle? base, bool serif) {
  final value = base ?? const TextStyle();
  return serif
      ? value.copyWith(
          fontFamily: _chatSerifFamily,
          fontFamilyFallback: _chatSerifFallback,
        )
      : value;
}

String _t(BuildContext context, String mode, String zh, String en) {
  final language = mode == 'system'
      ? Localizations.localeOf(context).languageCode
      : mode.startsWith('en')
      ? 'en'
      : 'zh';
  return language == 'en' ? en : zh;
}

String _localeLabel(BuildContext context, String mode) => switch (mode) {
  'en-US' => 'English',
  'zh-CN' => '简体中文',
  _ => _t(context, mode, '跟随系统', 'System'),
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: A2sApp()));
}

class A2sApp extends ConsumerWidget {
  const A2sApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final duration = app.motion == MotionPreference.off
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'A2S',
          locale: app.locale == 'en-US'
              ? const Locale('en', 'US')
              : app.locale == 'zh-CN'
              ? const Locale('zh', 'CN')
              : null,
          supportedLocales: const <Locale>[
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          themeMode: app.themeMode,
          themeAnimationDuration: duration,
          themeAnimationCurve: Curves.easeOutCubic,
          theme: _theme(
            Brightness.light,
            app.dynamicColor ? lightDynamic : null,
            Color(app.accentColorValue),
          ),
          darkTheme: _theme(
            Brightness.dark,
            app.dynamicColor ? darkDynamic : null,
            Color(app.accentColorValue),
          ),
          home: const HomePage(),
        );
      },
    );
  }

  ThemeData _theme(
    Brightness brightness,
    ColorScheme? dynamicScheme,
    Color accent,
  ) {
    var scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: accent == Colors.transparent ? _seed : accent,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        );
    // A pure black brand seed still produces a warm tonal palette in the
    // Material generator.  Keep the default unmistakably monochrome and let
    // the explicit accent choices provide color only where the user asks for
    // it.
    if (dynamicScheme == null && accent.toARGB32() == Colors.black.toARGB32()) {
      final dark = brightness == Brightness.dark;
      scheme = scheme.copyWith(
        primary: dark ? Colors.white : Colors.black,
        onPrimary: dark ? Colors.black : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF303030)
            : const Color(0xFFE8E8E8),
        onPrimaryContainer: dark ? Colors.white : Colors.black,
        secondary: dark ? const Color(0xFFBDBDBD) : const Color(0xFF5F6368),
        onSecondary: dark ? Colors.black : Colors.white,
        secondaryContainer: dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFEDEDED),
        onSecondaryContainer: dark ? Colors.white : Colors.black,
        surface: dark ? const Color(0xFF111111) : const Color(0xFFFCFCFC),
        surfaceContainerLowest: dark ? const Color(0xFF0B0B0B) : Colors.white,
        surfaceContainerLow: dark
            ? const Color(0xFF171717)
            : const Color(0xFFF8F8F8),
        surfaceContainer: dark
            ? const Color(0xFF1D1D1D)
            : const Color(0xFFF2F2F2),
        surfaceContainerHigh: dark
            ? const Color(0xFF252525)
            : const Color(0xFFECECEC),
        surfaceContainerHighest: dark
            ? const Color(0xFF303030)
            : const Color(0xFFE3E3E3),
        onSurface: dark ? const Color(0xFFF5F5F5) : const Color(0xFF171717),
        onSurfaceVariant: dark
            ? const Color(0xFFC5C5C5)
            : const Color(0xFF606060),
        outline: dark ? const Color(0xFF9B9B9B) : const Color(0xFF767676),
        outlineVariant: dark
            ? const Color(0xFF4A4A4A)
            : const Color(0xFFD0D0D0),
        surfaceTint: Colors.transparent,
      );
    }
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .42)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide.none,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(
      () => ref.read(appStateProvider.notifier).initialize(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(appStateProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (previous, next) {
      if (next.drawerOpen && previous?.drawerOpen != true) {
        unawaited(ref.read(appStateProvider.notifier).refreshSelectedContext());
      }
    });
    final app = ref.watch(appStateProvider);
    if (!app.initialized) return const _Splash();
    return AnimatedSwitcher(
      duration: motionDuration(context, ref),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: app.connected
          ? const MainShell(key: ValueKey('shell'))
          : const ConnectLanding(key: ValueKey('connect')),
    );
  }
}

Duration motionDuration(
  BuildContext context,
  WidgetRef ref, [
  int milliseconds = 280,
]) {
  final motion = ref.read(appStateProvider).motion;
  if (motion == MotionPreference.off) return Duration.zero;
  if (motion == MotionPreference.reduced) {
    return Duration(milliseconds: milliseconds ~/ 2);
  }
  return Duration(milliseconds: milliseconds);
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _A2sMark(size: 104),
          const SizedBox(height: 28),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ),
    ),
  );
}

class ConnectLanding extends ConsumerWidget {
  const ConnectLanding({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    String text(String zh, String en) => _t(context, app.locale, zh, en);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 54, 28, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const _A2sMark(size: 132),
                  const SizedBox(height: 30),
                  Text(
                    text('连接你的 AI 工作区', 'Connect your AI workspace'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text(
                      '连接服务器后，在手机上管理对话、项目和智能体。',
                      'Connect a server to manage chats, projects, and agents on your phone.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ScannerPage(),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(text('扫码快速配对', 'Scan to pair')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showManualConnect(context, ref),
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(text('手动配置服务器', 'Configure server manually')),
                    ),
                  ),
                  if (app.error != null) ...<Widget>[
                    const SizedBox(height: 20),
                    _ErrorBanner(
                      message: app.error!,
                      onRetry: () =>
                          ref.read(appStateProvider.notifier).refresh(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    String text(String zh, String en) => _t(context, app.locale, zh, en);
    final agent = app.selectedAgent;
    final device = app.selectedDevice;
    return Scaffold(
      drawer: const AppDrawer(),
      onDrawerChanged: (open) =>
          ref.read(appStateProvider.notifier).toggleDrawer(open),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: text('打开侧栏', 'Open sidebar'),
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _HeaderSelector(
              icon: Icons.computer_rounded,
              label: device?.label ?? text('选择电脑', 'Select computer'),
              selected: device != null,
              onTap: (anchorContext) => showDevicePicker(anchorContext, ref),
            ),
            const SizedBox(width: 6),
            _HeaderSelector(
              agentType: agent?.agentType ?? 'a2s',
              label: agent?.title ?? text('选择智能体', 'Select agent'),
              selected: agent != null,
              onTap: (anchorContext) => showAgentPicker(anchorContext, ref),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: text('新建对话', 'New chat'),
            onPressed: agent == null
                ? null
                : () => showNewConversation(context, ref),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: text('会话详情', 'Conversation details'),
            onPressed: agent == null || app.selectedSessionId == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SessionInsightsPage(
                        instanceId: agent.instanceId,
                        sessionId: app.selectedSessionId!,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.analytics_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: text('工具与设置', 'Tools and settings'),
            icon: const Icon(Icons.auto_awesome_rounded),
            onSelected: (value) {
              if (value == 'tools' && agent != null) {
                showTools(context, ref);
              } else if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                );
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'tools',
                enabled: agent != null,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.auto_awesome_rounded),
                    const SizedBox(width: 12),
                    Text(text('工具和能力', 'Tools and capabilities')),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.settings_outlined),
                    const SizedBox(width: 12),
                    Text(text('设置与连接', 'Settings and connection')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (app.offline)
            _OfflineCacheBanner(
              updatedAt: app.cacheUpdatedAt,
              onRefresh: app.busy
                  ? null
                  : () => unawaited(
                      ref.read(appStateProvider.notifier).refresh(),
                    ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: motionDuration(context, ref),
              child: agent == null
                  ? const UnlockPrompt(key: ValueKey('unlock'))
                  : ChatPage(
                      key: ValueKey(
                        'chat-${agent.instanceId}-${app.selectedSessionId ?? ''}',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSelector extends StatelessWidget {
  const _HeaderSelector({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.agentType,
  });

  final IconData? icon;
  final String? agentType;
  final String label;
  final bool selected;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = agentType != null
        ? _AgentIcon(type: agentType!, size: 26)
        : Icon(icon, size: 24, color: scheme.primary);
    return Semantics(
      button: true,
      label: label,
      hint: '点击选择',
      child: Tooltip(
        message: label,
        child: Material(
          color: selected
              ? scheme.surfaceContainerHighest
              : scheme.surfaceContainerLow,
          shape: const CircleBorder(),
          child: InkResponse(
            containedInkWell: true,
            customBorder: const CircleBorder(),
            onTap: () => onTap(context),
            child: SizedBox(width: 46, height: 46, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _OfflineCacheBanner extends StatelessWidget {
  const _OfflineCacheBanner({required this.updatedAt, required this.onRefresh});

  final DateTime? updatedAt;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stamp = updatedAt == null
        ? '已保存的本地内容'
        : '最后同步 ${MaterialLocalizations.of(context).formatShortDate(updatedAt!)}';
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 10, 7),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '离线缓存 · $stamp',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRefresh,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onTertiaryContainer,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  String _query = '';

  List<_DrawerProject> _projects(AppState app) {
    final bySession = <String, String>{};
    final projects = <String, _DrawerProject>{};
    for (final workspace in app.workspaces) {
      projects[workspace.path] = _DrawerProject(workspace);
      for (final sessionId in workspace.sessionIds) {
        bySession[sessionId] = workspace.path;
      }
    }
    for (final session in app.sessions) {
      final key = bySession[session.sessionId] ?? session.cwd ?? '__other__';
      final project = projects[key] ??= _DrawerProject(
        Workspace(
          id: key,
          path: session.cwd ?? '',
          title: session.cwd == null ? '其他对话' : null,
        ),
      );
      project.sessions.add(session);
    }
    final output = projects.values.toList();
    final selectedSessionId = app.selectedSessionId;
    DateTime latest(_DrawerProject project) => project.sessions
        .map(
          (session) =>
              session.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        )
        .fold(
          DateTime.fromMillisecondsSinceEpoch(0),
          (current, value) => value.isAfter(current) ? value : current,
        );
    output.sort((left, right) {
      final leftSelected = left.sessions.any(
        (session) => session.sessionId == selectedSessionId,
      );
      final rightSelected = right.sessions.any(
        (session) => session.sessionId == selectedSessionId,
      );
      if (leftSelected != rightSelected) return leftSelected ? -1 : 1;
      return latest(right).compareTo(latest(left));
    });
    return output;
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    String text(String zh, String en) => _t(context, app.locale, zh, en);
    final scheme = Theme.of(context).colorScheme;
    final device = app.selectedDevice;
    final agent = app.selectedAgent;
    return Drawer(
      width: MediaQuery.sizeOf(context).width * .86,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 10),
              child: Row(
                children: <Widget>[
                  // Keep the transparent mark as the only brand label in the
                  // compact drawer header.
                  const _A2sMark(size: 80),
                  const Spacer(),
                  IconButton(
                    tooltip: text('刷新项目和对话', 'Refresh projects and chats'),
                    onPressed: app.busy
                        ? null
                        : () => unawaited(
                            ref
                                .read(appStateProvider.notifier)
                                .refreshSelectedContext(),
                          ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: text('关闭侧栏', 'Close sidebar'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SelectorCard(
                icon: Icons.computer_rounded,
                label: device?.label ?? text('选择电脑', 'Select computer'),
                value: device?.online == true
                    ? text('在线', 'Online')
                    : device == null
                    ? text('尚未选择', 'Not selected')
                    : text('离线', 'Offline'),
                selected: device != null,
                onTap: (anchorContext) => showDevicePicker(anchorContext, ref),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SelectorCard(
                leading: _AgentIcon(type: agent?.agentType ?? 'a2s', size: 22),
                label: agent?.title ?? text('选择智能体', 'Select agent'),
                value: agent?.online == true
                    ? text('已连接', 'Connected')
                    : text('选择一台已解锁的电脑', 'Choose an unlocked computer'),
                selected: agent != null,
                onTap: (anchorContext) => showAgentPicker(anchorContext, ref),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Close the drawer first so the creation sheet is anchored
                  // to the chat scaffold instead of being stacked behind it.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) showNewConversation(context, ref);
                  });
                },
                icon: const Icon(Icons.add_rounded),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(text('新建对话', 'New chat')),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: agent == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                WorkspacePage(instanceId: agent.instanceId),
                          ),
                        );
                      },
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text('新建工作区 / 管理项目', 'New workspace / manage projects'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: text('搜索对话', 'Search chats'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 7),
                    child: Text(
                      text('最近对话', 'Recent chats'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (app.sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        text(
                          '还没有对话\n新建一个对话开始工作.',
                          'No chats yet\nCreate a chat to get started.',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.outline,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ..._projects(app).map((project) {
                    final projectMatches =
                        _query.isNotEmpty &&
                        (project.workspace.displayTitle.toLowerCase().contains(
                              _query.toLowerCase(),
                            ) ||
                            project.workspace.path.toLowerCase().contains(
                              _query.toLowerCase(),
                            ));
                    final sessions = project.sessions
                        .where(
                          (session) =>
                              _query.isEmpty ||
                              projectMatches ||
                              session.title.toLowerCase().contains(
                                _query.toLowerCase(),
                              ),
                        )
                        .toList();
                    if (_query.isNotEmpty &&
                        sessions.isEmpty &&
                        !projectMatches) {
                      return const SizedBox.shrink();
                    }
                    return ExpansionTile(
                      key: PageStorageKey<String>(
                        'project-${project.workspace.id}',
                      ),
                      initiallyExpanded: project.sessions.any(
                        (session) => session.sessionId == app.selectedSessionId,
                      ),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                      childrenPadding: const EdgeInsets.only(left: 12),
                      leading: Icon(
                        Icons.folder_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(
                        project.workspace.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        app.locale.startsWith('en')
                            ? '${sessions.length} chats'
                            : '${sessions.length} 个对话',
                      ),
                      children: <Widget>[
                        ...sessions.map(
                          (session) => _SessionTile(
                            session: session,
                            selected:
                                session.sessionId == app.selectedSessionId,
                            onTap: () {
                              Navigator.of(context).pop();
                              ref
                                  .read(appStateProvider.notifier)
                                  .selectSession(session);
                            },
                          ),
                        ),
                        if (project.workspace.path.isNotEmpty)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.add_rounded, size: 19),
                            title: Text(
                              text('在此项目中新建对话', 'New chat in this project'),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              ref
                                  .read(appStateProvider.notifier)
                                  .createSession(
                                    cwd: project.workspace.path,
                                    title: text('新对话', 'New chat'),
                                  );
                            },
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  IconButton(
                    tooltip: _t(context, app.locale, '个人资料', 'Profile'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileSettingsPage(),
                        ),
                      );
                    },
                    icon: _AvatarImage(dataUrl: app.avatarDataUrl, size: 34),
                  ),
                  IconButton(
                    tooltip: _t(context, app.locale, '统计', 'Statistics'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const StatsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.insights_outlined),
                  ),
                  IconButton(
                    tooltip: _t(
                      context,
                      app.locale,
                      '设置与连接',
                      'Settings & connection',
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerProject {
  _DrawerProject(this.workspace);
  final Workspace workspace;
  final List<Session> sessions = <Session>[];
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.leading,
  });
  final IconData? icon;
  final Widget? leading;
  final String label;
  final String value;
  final bool selected;
  final void Function(BuildContext context) onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.surfaceContainerLow : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              leading ?? Icon(icon, size: 21, color: scheme.primary),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                size: 21,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });
  final Session session;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  session.running
                      ? Icons.more_horiz_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? scheme.onSecondaryContainer : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (session.paused)
                  Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 15,
                    color: scheme.tertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnlockPrompt extends ConsumerWidget {
  const UnlockPrompt({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '先解锁一台电脑',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '服务器已连接。输入 A2Switch 的设备 key 后，才能操作这台电脑上的智能体。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: app.devices.isEmpty
                  ? null
                  : () => showDevicePicker(context, ref),
              icon: const Icon(Icons.key_rounded),
              label: const Text('选择电脑并解锁'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _imagePicker = ImagePicker();
  final List<_PendingAttachment> _attachments = <_PendingAttachment>[];
  bool _uploadingAttachment = false;
  Future<bool>? _olderLoad;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_persistDraft);
    _scroll.addListener(_onScroll);
    ref.listenManual<AppState>(appStateProvider, (previous, next) {
      if (!mounted) return;
      final sessionChanged =
          previous?.selectedSessionId != next.selectedSessionId;
      final historyArrived =
          previous?.messages.isEmpty == true &&
          next.messages.isNotEmpty &&
          !next.historyLoadingOlder;
      final historyWindowArrived =
          previous?.historyBeforeSeq == null &&
          next.historyBeforeSeq != null &&
          next.messages.isNotEmpty &&
          !next.historyLoadingOlder;
      if (sessionChanged || historyArrived || historyWindowArrived) {
        _scheduleScrollToBottom();
      }
    });
    // Context restoration can finish before ChatPage is mounted. Perform one
    // post-layout positioning pass so a restored long transcript opens at its
    // newest message instead of an arbitrary cached list offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = ref.read(appStateProvider);
      if (app.messages.isNotEmpty && !app.historyLoading) {
        _scheduleScrollToBottom();
      }
    });
    Future<void>.microtask(() async {
      final draft = await ref.read(appStateProvider.notifier).loadDraft();
      if (mounted && _controller.text.isEmpty && draft.isNotEmpty) {
        _controller.value = TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: draft.length),
        );
      }
    });
  }

  void _persistDraft() {
    ref.read(appStateProvider.notifier).saveDraft(_controller.text);
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (target <= 0) return;
      _scroll.jumpTo(target);
    });
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients || _olderLoad != null) return;
    final app = ref.read(appStateProvider);
    if (app.historyLoading || !app.historyHasMore || app.historyLoadingOlder) {
      return;
    }
    final position = _scroll.position;
    final threshold = math.max(240.0, position.viewportDimension * .45);
    if (position.pixels > threshold) return;
    final oldPixels = position.pixels;
    final oldExtent = position.maxScrollExtent;
    final request = ref.read(appStateProvider.notifier).loadOlderHistory();
    _olderLoad = request;
    request
        .then((changed) {
          if (!mounted || !changed) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            final nextExtent = _scroll.position.maxScrollExtent;
            final target = (oldPixels + nextExtent - oldExtent).clamp(
              0.0,
              nextExtent,
            );
            _scroll.jumpTo(target);
          });
        })
        .whenComplete(() {
          if (!mounted) return;
          _olderLoad = null;
          // A short page may leave the preserved anchor inside the prefetch
          // zone. Continue paging while the user is still at the top,
          // matching the web client's sentinel behavior.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            final threshold = math.max(
              240.0,
              _scroll.position.viewportDimension * .45,
            );
            if (_scroll.position.pixels <= threshold) _onScroll();
          });
        });
  }

  @override
  void dispose() {
    _controller.removeListener(_persistDraft);
    _scroll.removeListener(_onScroll);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final value = _controller.text;
    if (value.trim().isEmpty && _attachments.isEmpty) return;
    final blocks = <Map<String, dynamic>>[
      if (value.trim().isNotEmpty)
        <String, dynamic>{'type': 'text', 'text': value.trim()},
      ..._attachments.map(
        (item) => <String, dynamic>{
          'type': item.kind,
          'attachmentId': item.id,
          'name': item.name,
        },
      ),
    ];
    _controller.clear();
    final attachments = List<_PendingAttachment>.from(_attachments);
    setState(() => _attachments.clear());
    ref.read(appStateProvider.notifier).sendPrompt(value, content: blocks);
    if (attachments.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已发送 ${attachments.length} 个附件')));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: motionDuration(context, ref, 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    await _uploadAttachment(
      name: image.name,
      mime: image.mimeType ?? _mimeForName(image.name),
      bytes: bytes,
      kind: 'image',
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取这个文件')));
      }
      return;
    }
    await _uploadAttachment(
      name: file.name,
      mime: _mimeForName(file.name),
      bytes: bytes,
      kind: 'file',
    );
  }

  Future<void> _uploadAttachment({
    required String name,
    required String mime,
    required List<int> bytes,
    required String kind,
  }) async {
    if (bytes.length > 8 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('单个附件不能超过 8 MB')));
      }
      return;
    }
    final agent = ref.read(appStateProvider).selectedAgent;
    if (agent == null || !agent.supports('attachments')) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前智能体没有启用附件能力')));
      }
      return;
    }
    setState(() => _uploadingAttachment = true);
    try {
      final result = await ref.read(apiProvider).call(
        agent.instanceId,
        'attachment.put',
        <String, dynamic>{
          'name': name,
          'mime': mime,
          'dataBase64': base64Encode(bytes),
        },
      );
      final id = result is Map ? result['attachmentId']?.toString() : null;
      if (id == null || id.isEmpty) throw StateError('服务器没有返回附件编号');
      if (mounted) {
        setState(() {
          _uploadingAttachment = false;
          _attachments.add(
            _PendingAttachment(id: id, name: name, mime: mime, kind: kind),
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('附件上传失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final scheme = Theme.of(context).colorScheme;
    final agent = app.selectedAgent;
    final pending = app.pendingInteractions
        .where(
          (item) =>
              item.sessionId == null || item.sessionId == app.selectedSessionId,
        )
        .toList();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (app.chatBackgroundDataUrl != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: .16,
                child: _DataImage(
                  dataUrl: app.chatBackgroundDataUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        Column(
          children: <Widget>[
            if (pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  children: pending
                      .map((item) => _InteractionCard(interaction: item))
                      .toList(),
                ),
              ),
            Expanded(
              child: app.historyLoading && app.messages.isEmpty
                  ? const _HistoryLoadingState()
                  : app.historyError != null && app.messages.isEmpty
                  ? _HistoryErrorState(
                      message: app.historyError!,
                      onRetry: app.selectedSessionId == null
                          ? null
                          : () {
                              final session = app.sessions
                                  .where(
                                    (item) =>
                                        item.sessionId == app.selectedSessionId,
                                  )
                                  .firstOrNull;
                              if (session != null) {
                                ref
                                    .read(appStateProvider.notifier)
                                    .selectSession(session);
                              }
                            },
                    )
                  : app.messages.isEmpty
                  ? _EmptyChat(
                      agent: agent,
                      onNew: () =>
                          ref.read(appStateProvider.notifier).createSession(),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount:
                          app.messages.length +
                          (app.historyHasMore || app.historyLoadingOlder
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        final hasOlderHeader =
                            app.historyHasMore || app.historyLoadingOlder;
                        if (hasOlderHeader && index == 0) {
                          return _OlderHistoryIndicator(
                            loading: app.historyLoadingOlder,
                          );
                        }
                        final messageIndex = index - (hasOlderHeader ? 1 : 0);
                        final message = app.messages[messageIndex];
                        return _MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  children: <Widget>[
                    if (app.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ErrorBanner(
                          message: app.error!,
                          onRetry: () =>
                              ref.read(appStateProvider.notifier).refresh(),
                        ),
                      ),
                    if (_attachments.isNotEmpty || _uploadingAttachment)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: <Widget>[
                              ..._attachments.map(
                                (item) => InputChip(
                                  avatar: Icon(
                                    item.kind == 'image'
                                        ? Icons.image_outlined
                                        : Icons.insert_drive_file_outlined,
                                    size: 17,
                                  ),
                                  label: Text(
                                    item.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onDeleted: () =>
                                      setState(() => _attachments.remove(item)),
                                ),
                              ),
                              if (_uploadingAttachment)
                                const Chip(
                                  avatar: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  label: Text('上传中'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    _Composer(
                      controller: _controller,
                      onSend: _send,
                      onStop: () =>
                          ref.read(appStateProvider.notifier).interrupt(),
                      onTools: () => showTools(
                        context,
                        ref,
                        onPickImage: _pickImage,
                        onPickFile: _pickFile,
                      ),
                      running:
                          app.sessions
                              .where(
                                (item) =>
                                    item.sessionId == app.selectedSessionId,
                              )
                              .firstOrNull
                              ?.running ==
                          true,
                      scheme: scheme,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DataImage extends StatelessWidget {
  const _DataImage({required this.dataUrl, this.fit = BoxFit.contain});
  final String dataUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    try {
      final comma = dataUrl.indexOf(',');
      if (!dataUrl.startsWith('data:') || comma < 0) {
        return const SizedBox.shrink();
      }
      return Image.memory(base64Decode(dataUrl.substring(comma + 1)), fit: fit);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 16),
        Text(
          '正在加载对话历史…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _OlderHistoryIndicator extends StatelessWidget {
  const _OlderHistoryIndicator({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: loading,
      label: loading ? '正在加载更早的消息' : '继续向上滑加载更早的消息',
      child: SizedBox(
        height: 58,
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: scheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '继续向上滑加载更早的消息',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 38,
                  color: scheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  '无法加载这段对话',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新加载'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.agent, required this.onNew});
  final AgentInstance? agent;
  final VoidCallback onNew;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Hero(
            tag: 'agent-mark',
            child: _AgentIcon(type: agent?.agentType ?? 'a2s', size: 60),
          ),
          const SizedBox(height: 20),
          Text(
            agent == null ? '准备开始' : '和 ${agent!.title} 对话',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            agent == null ? '从左侧选择一台已解锁的电脑和智能体。' : '描述目标、粘贴代码，或让它帮你检查工作区。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.lightbulb_outline_rounded, size: 17),
                label: const Text('帮我梳理一个任务'),
                onPressed: onNew,
              ),
              ActionChip(
                avatar: const Icon(Icons.code_rounded, size: 17),
                label: const Text('检查工作区代码'),
                onPressed: onNew,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PendingAttachment {
  const _PendingAttachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.kind,
  });
  final String id;
  final String name;
  final String mime;
  final String kind;
}

String _mimeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.txt')) return 'text/plain';
  if (lower.endsWith('.json')) return 'application/json';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.onTools,
    required this.running,
    required this.scheme,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onTools;
  final bool running;
  final ColorScheme scheme;
  @override
  Widget build(BuildContext context) => Material(
    color: scheme.surfaceContainerHigh,
    elevation: 2,
    shadowColor: scheme.shadow.withValues(alpha: .12),
    borderRadius: BorderRadius.circular(26),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          IconButton(
            tooltip: '工具和附件',
            onPressed: onTools,
            icon: const Icon(Icons.add_rounded),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '向智能体发送消息',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: running
                ? IconButton(
                    key: const ValueKey('stop'),
                    tooltip: '停止',
                    onPressed: onStop,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                    ),
                    icon: const Icon(Icons.stop_rounded),
                  )
                : IconButton(
                    key: const ValueKey('send'),
                    tooltip: '发送',
                    onPressed: onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({super.key, required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final user = message.role == 'user';
    final error = message.kind == 'error';
    final content = user
        ? SelectableText(
            message.text,
            style: _chatTextStyle(
              TextStyle(color: scheme.onSurface, height: 1.45),
              app.serifFont,
            ),
          )
        : MarkdownBody(
            data: message.text.isEmpty ? '…' : message.text,
            selectable: true,
            styleSheet: () {
              final base = MarkdownStyleSheet.fromTheme(theme);
              return base.copyWith(
                p: _chatTextStyle(
                  theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  app.serifFont,
                ),
                h1: _chatTextStyle(base.h1, app.serifFont),
                h2: _chatTextStyle(base.h2, app.serifFont),
                h3: _chatTextStyle(base.h3, app.serifFont),
                h4: _chatTextStyle(base.h4, app.serifFont),
                h5: _chatTextStyle(base.h5, app.serifFont),
                h6: _chatTextStyle(base.h6, app.serifFont),
                em: _chatTextStyle(base.em, app.serifFont),
                strong: _chatTextStyle(base.strong, app.serifFont),
                del: _chatTextStyle(base.del, app.serifFont),
                blockquote: _chatTextStyle(base.blockquote, app.serifFont),
                listBullet: _chatTextStyle(base.listBullet, app.serifFont),
                tableHead: _chatTextStyle(base.tableHead, app.serifFont),
                tableBody: _chatTextStyle(base.tableBody, app.serifFont),
                code: TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.onSurface,
                ),
              );
            }(),
          );
    final inputTokens = _usageNumber(message.usage, const <String>[
      'inputTokens',
      'input_tokens',
      'promptTokens',
      'input',
    ]);
    final outputTokens = _usageNumber(message.usage, const <String>[
      'outputTokens',
      'output_tokens',
      'completionTokens',
      'output',
    ]);
    final cachedTokens = _usageNumber(message.usage, const <String>[
      'cacheReadTokens',
      'cache_read_input_tokens',
      'cache_creation_input_tokens',
      'cachedInputTokens',
      'cacheRead',
      'cacheTokens',
    ]);
    final totalTokens = _usageNumber(message.usage, const <String>[
      'totalTokens',
      'total_tokens',
      'total',
    ]);
    final reasoningTokens = _usageNumber(message.usage, const <String>[
      'reasoningTokens',
      'reasoning_tokens',
      'reasoning',
    ]);
    final hasUsage =
        inputTokens != null ||
        outputTokens != null ||
        cachedTokens != null ||
        totalTokens != null ||
        reasoningTokens != null;
    final metadata = !user && !error && (message.seq != null || hasUsage)
        ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: <Widget>[
                if (message.seq != null)
                  Text(
                    'seq ${message.seq}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                if (inputTokens != null)
                  _UsagePill(
                    label: '输入 $inputTokens',
                    icon: Icons.login_rounded,
                  ),
                if (outputTokens != null)
                  _UsagePill(
                    label: '输出 $outputTokens',
                    icon: Icons.logout_rounded,
                  ),
                if (cachedTokens != null)
                  _UsagePill(
                    label: '缓存 $cachedTokens',
                    icon: Icons.cached_rounded,
                  ),
                if (totalTokens != null)
                  _UsagePill(
                    label: '总计 $totalTokens',
                    icon: Icons.functions_rounded,
                  ),
                if (reasoningTokens != null)
                  _UsagePill(
                    label: '推理 $reasoningTokens',
                    icon: Icons.psychology_alt_outlined,
                  ),
                if (message.durationMs != null)
                  _UsagePill(
                    label: '${message.durationMs} ms',
                    icon: Icons.timer_outlined,
                  ),
                IconButton(
                  tooltip: '点赞',
                  visualDensity: VisualDensity.compact,
                  onPressed: message.seq == null
                      ? null
                      : () => ref
                            .read(appStateProvider.notifier)
                            .setMessageFeedback(message, 'like'),
                  color: message.feedback == 'like'
                      ? scheme.primary
                      : scheme.outline,
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                ),
                IconButton(
                  tooltip: '点踩',
                  visualDensity: VisualDensity.compact,
                  onPressed: message.seq == null
                      ? null
                      : () => ref
                            .read(appStateProvider.notifier)
                            .setMessageFeedback(message, 'dislike'),
                  color: message.feedback == 'dislike'
                      ? scheme.error
                      : scheme.outline,
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                ),
                IconButton(
                  tooltip: '复制',
                  visualDensity: VisualDensity.compact,
                  onPressed: message.text.trim().isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: message.text),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('已复制消息内容')),
                              );
                          }
                        },
                  color: scheme.outline,
                  icon: const Icon(Icons.content_copy_outlined, size: 18),
                ),
                IconButton(
                  tooltip: '从此处分支',
                  visualDensity: VisualDensity.compact,
                  onPressed: message.seq == null
                      ? null
                      : () async {
                          final created = await ref
                              .read(appStateProvider.notifier)
                              .forkFromMessage(message);
                          if (context.mounted && created) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('已从此消息创建分支')),
                              );
                          }
                        },
                  color: scheme.outline,
                  icon: const Icon(Icons.call_split_rounded, size: 18),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .9,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Material(
              color: error
                  ? scheme.errorContainer
                  : user
                  ? scheme.surfaceContainerHighest
                  : Colors.transparent,
              borderRadius: user
                  ? BorderRadius.circular(22)
                  : BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[content, metadata],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int? _usageNumber(Map<String, dynamic> usage, List<String> keys) {
  for (final key in keys) {
    final value = usage[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse('$value');
    if (parsed != null) return parsed;
  }
  return null;
}

class _UsagePill extends StatelessWidget {
  const _UsagePill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    ),
  );
}

class _InteractionCard extends ConsumerStatefulWidget {
  const _InteractionCard({required this.interaction});
  final PendingInteraction interaction;

  @override
  ConsumerState<_InteractionCard> createState() => _InteractionCardState();
}

class _InteractionCardState extends ConsumerState<_InteractionCard> {
  final _answer = TextEditingController();

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.interaction;
    final scheme = Theme.of(context).colorScheme;
    final approval = item.kind == 'approval';
    final title = approval ? '需要审批' : '需要回答结构化问题';
    final detail = approval
        ? '${item.data['toolName'] ?? '工具调用'}\n${item.data['reason'] ?? '智能体正在等待你的决定。'}'
        : const JsonEncoder.withIndent(
            '  ',
          ).convert(item.data['questions'] ?? const <dynamic>[]);
    return Card(
      color: approval ? scheme.tertiaryContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(approval ? Icons.gpp_maybe_rounded : Icons.quiz_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            SelectableText(detail),
            if (!approval) ...<Widget>[
              const SizedBox(height: 8),
              TextField(
                controller: _answer,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'answers JSON',
                  hintText: '[{"id":"question-id","selected":["选项"]}]',
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (approval)
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(appStateProvider.notifier)
                        .respondApproval(item.requestId, 'allowed-once'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('允许一次'),
                  ),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(appStateProvider.notifier)
                        .respondApproval(item.requestId, 'rejected'),
                    child: const Text('拒绝'),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(appStateProvider.notifier)
                        .respondApproval(item.requestId, 'cancelled'),
                    child: const Text('取消'),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () {
                  try {
                    final value = jsonDecode(_answer.text);
                    if (value is! List) {
                      throw const FormatException('answers 必须是数组');
                    }
                    final answers = value
                        .whereType<Map>()
                        .map((entry) => Map<String, dynamic>.from(entry))
                        .toList();
                    ref
                        .read(appStateProvider.notifier)
                        .answerQuestion(item.requestId, answers);
                  } catch (error) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('答案格式错误：$error')));
                  }
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('提交答案'),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    String text(String zh, String en) => _t(context, app.locale, zh, en);
    return Scaffold(
      appBar: AppBar(title: Text(text('设置', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: <Widget>[
          Text(
            text('连接、外观和设备管理', 'Connection, appearance, and devices'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            text(
              '每个设置模块单独打开，返回时保留当前对话和选择。',
              'Each module opens separately while your current chat stays in place.',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(text('连接与授权', 'Connection & authorization')),
          _entry(
            context,
            icon: Icons.link_rounded,
            title: text('服务器连接', 'Server connection'),
            subtitle: text(
              'API 端点、管理员 key 验证和电脑设备解锁',
              'API endpoint, admin key verification, and computer unlock',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ConnectionSettingsPage(),
              ),
            ),
          ),
          _entry(
            context,
            icon: Icons.qr_code_scanner_rounded,
            title: text('扫码配对', 'Scan to pair'),
            subtitle: text(
              '扫描服务器生成的一次性二维码',
              'Scan a one-time QR code from the server',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScannerPage()),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text('外观与本地数据', 'Appearance & local data')),
          _entry(
            context,
            icon: Icons.palette_outlined,
            title: text('外观与交互', 'Appearance & interaction'),
            subtitle: text(
              '主题、动态取色、动画和触觉反馈',
              'Theme, dynamic colors, motion, and haptics',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AppearanceSettingsPage(),
              ),
            ),
          ),
          _entry(
            context,
            icon: Icons.offline_bolt_outlined,
            title: text('缓存与离线', 'Cache & offline'),
            subtitle: text(
              '查看本地缓存并清理手机保存的数据',
              'Review and clear data stored on this phone',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CacheSettingsPage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text('服务器端管理', 'Server administration')),
          _entry(
            context,
            icon: Icons.admin_panel_settings_outlined,
            title: text('服务器管理', 'Server administration'),
            subtitle: text(
              '移动设备、设备 key、配对二维码和服务日志',
              'Mobile devices, device keys, pairing QR, and logs',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ServerAdminPage()),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text('个人资料', 'Profile')),
          _entry(
            context,
            icon: Icons.account_circle_outlined,
            title: text('统一头像', 'Shared avatar'),
            subtitle: text(
              '在手机、服务器网页端和本机 A2Switch 之间同步一张头像',
              'Sync one avatar across the phone, server web console, and A2Switch',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileSettingsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectionSettingsPage extends ConsumerStatefulWidget {
  const ConnectionSettingsPage({super.key});
  @override
  ConsumerState<ConnectionSettingsPage> createState() =>
      _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState
    extends ConsumerState<ConnectionSettingsPage> {
  late final TextEditingController _endpoint;
  late final TextEditingController _adminKey;
  @override
  void initState() {
    super.initState();
    final value = ref.read(appStateProvider);
    _endpoint = TextEditingController(text: value.endpoint);
    _adminKey = TextEditingController();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _adminKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('服务器连接')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: <Widget>[
          const _SectionLabel('服务器连接'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _endpoint,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'API 端点',
                      hintText: 'http://127.0.0.1:50443/a2s-api',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _adminKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '管理 key（只用于验证）',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          app.connected
                              ? '已连接 · ${app.devices.length} 台电脑'
                              : '尚未连接',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: app.connected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: app.busy
                            ? null
                            : () async {
                                try {
                                  await ref
                                      .read(appStateProvider.notifier)
                                      .connectWithAdmin(
                                        _endpoint.text,
                                        _adminKey.text,
                                      );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('服务器连接成功')),
                                  );
                                } catch (_) {}
                              },
                        icon: app.busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('连接'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('电脑授权'),
          if (app.devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '连接服务器后，这里会显示已登记的电脑。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...app.devices.map(
              (device) => _DeviceCard(
                device: device,
                onUnlock: () => showUnlock(context, ref, device),
              ),
            ),
          if (app.error != null) ...<Widget>[
            const SizedBox(height: 14),
            _ErrorBanner(
              message: app.error!,
              onRetry: () => ref.read(appStateProvider.notifier).refresh(),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: app.connected
                ? () => ref.read(appStateProvider.notifier).logout()
                : null,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('断开手机连接'),
          ),
        ],
      ),
    );
  }
}

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    String text(String zh, String en) => _t(context, app.locale, zh, en);
    final accentChoices = <Color>[
      Colors.black,
      const Color(0xFF5367D8),
      const Color(0xFF7B4DFF),
      const Color(0xFF00897B),
      const Color(0xFFE06C2E),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(text('外观与交互', 'Appearance & interaction'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: <Widget>[
          _SectionLabel(text('主题', 'Theme')),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(text('主题模式', 'Theme mode')),
                  subtitle: Text(switch (app.themeMode) {
                    ThemeMode.light => text('浅色', 'Light'),
                    ThemeMode.dark => text('深色', 'Dark'),
                    ThemeMode.system => text('跟随系统', 'System'),
                  }),
                  trailing: DropdownButton<ThemeMode>(
                    value: app.themeMode,
                    underline: const SizedBox.shrink(),
                    items: <DropdownMenuItem<ThemeMode>>[
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(text('跟随系统', 'System')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(text('浅色', 'Light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(text('深色', 'Dark')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) notifier.setTheme(value);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 72),
                SwitchListTile(
                  value: app.dynamicColor,
                  onChanged: notifier.setDynamicColor,
                  secondary: const Icon(Icons.colorize_rounded),
                  title: Text(text('系统动态取色', 'Dynamic system colors')),
                  subtitle: Text(
                    text(
                      '在支持的 Android 设备上使用系统壁纸色调',
                      'Use Android wallpaper colors when available',
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(text('界面语言', 'Interface language')),
                  subtitle: Text(_localeLabel(context, app.locale)),
                  trailing: DropdownButton<String>(
                    value: app.locale,
                    underline: const SizedBox.shrink(),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'system',
                        child: Text(text('跟随系统', 'System')),
                      ),
                      const DropdownMenuItem(
                        value: 'zh-CN',
                        child: Text('简体中文'),
                      ),
                      const DropdownMenuItem(
                        value: 'en-US',
                        child: Text('English'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) notifier.setLocale(value);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const Icon(Icons.color_lens_outlined),
                  title: Text(text('强调色', 'Accent color')),
                  subtitle: Text(
                    text(
                      '默认黑色，也可以选择一处克制的强调色',
                      'Black by default; choose a restrained accent',
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 7,
                    children: accentChoices
                        .map(
                          (color) => GestureDetector(
                            onTap: () => notifier.setAccentColor(color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      app.accentColorValue == color.toARGB32()
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text('动效与反馈', 'Motion & feedback')),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.animation_rounded),
                  title: Text(text('动画', 'Motion')),
                  subtitle: Text(switch (app.motion) {
                    MotionPreference.reduced => text('减少动画', 'Reduced'),
                    MotionPreference.off => text('关闭动画', 'Off'),
                    MotionPreference.system => text('跟随系统', 'System'),
                  }),
                  trailing: DropdownButton<MotionPreference>(
                    value: app.motion,
                    underline: const SizedBox.shrink(),
                    items: <DropdownMenuItem<MotionPreference>>[
                      DropdownMenuItem(
                        value: MotionPreference.system,
                        child: Text(text('跟随系统', 'System')),
                      ),
                      DropdownMenuItem(
                        value: MotionPreference.reduced,
                        child: Text(text('减少', 'Reduced')),
                      ),
                      DropdownMenuItem(
                        value: MotionPreference.off,
                        child: Text(text('关闭', 'Off')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) notifier.setMotion(value);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 72),
                SwitchListTile(
                  value: app.haptics,
                  onChanged: notifier.setHaptics,
                  secondary: const Icon(Icons.vibration_rounded),
                  title: Text(text('触觉反馈', 'Haptic feedback')),
                  subtitle: Text(
                    text(
                      '选择和扫码成功时提供轻微反馈',
                      'A light tap on selection and pairing success',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text('聊天显示', 'Chat display')),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: app.serifFont,
                  onChanged: notifier.setSerifFont,
                  secondary: const Icon(Icons.font_download_outlined),
                  title: Text(text('衬线字体', 'Serif conversation font')),
                  subtitle: Text(
                    text(
                      '仅改变对话正文，代码仍使用等宽字体',
                      'Changes conversation text while code stays monospace',
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const Icon(Icons.wallpaper_outlined),
                  title: Text(text('聊天背景图', 'Chat background')),
                  subtitle: Text(
                    app.chatBackgroundDataUrl == null
                        ? text('使用纯色背景', 'Use a plain background')
                        : text('已设置自定义背景图', 'Custom background set'),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      IconButton(
                        tooltip: text('选择背景图', 'Choose background'),
                        onPressed: () async {
                          final image = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image == null) return;
                          final bytes = await image.readAsBytes();
                          if (bytes.length > 4 * 1024 * 1024) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    text(
                                      '背景图不能超过 4 MB',
                                      'Background image must be under 4 MB',
                                    ),
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          await notifier.setChatBackground(
                            'data:${image.mimeType ?? _mimeForName(image.name)};base64,${base64Encode(bytes)}',
                          );
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                      ),
                      if (app.chatBackgroundDataUrl != null)
                        IconButton(
                          tooltip: text('清除背景图', 'Clear background'),
                          onPressed: notifier.clearChatBackground,
                          icon: const Icon(Icons.clear_rounded),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() =>
      _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像图片不能超过 2 MB')));
      }
      return;
    }
    final app = ref.read(appStateProvider);
    if (!app.connected) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(appStateProvider.notifier)
          .updateAvatarFromBytes(
            bytes,
            image.mimeType ?? _mimeForName(image.name),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('统一头像已更新，所有端会同步显示')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('头像上传失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAvatar() async {
    setState(() => _busy = true);
    try {
      await ref.read(appStateProvider.notifier).clearAvatar();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('统一头像已清除')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final strings = _t;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings(context, app.locale, '个人资料', 'Profile')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: <Widget>[
          Center(child: _AvatarImage(dataUrl: app.avatarDataUrl, size: 112)),
          const SizedBox(height: 18),
          Text(
            strings(context, app.locale, '服务器统一头像', 'Shared server avatar'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            strings(
              context,
              app.locale,
              '这里只保存一张图片在服务器上，手机、服务器网页端和本机 A2Switch 都显示同一张头像。',
              'Only one image is stored on the server and shared by the phone, web console, and local A2Switch.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy || !app.connected ? null : _pickAvatar,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined),
            label: Text(
              strings(context, app.locale, '选择头像图片', 'Choose avatar image'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy || app.avatarDataUrl == null ? null : _clearAvatar,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(
              strings(context, app.locale, '清除服务器头像', 'Clear server avatar'),
            ),
          ),
          if (!app.connected)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                strings(
                  context,
                  app.locale,
                  '连接服务器后才能修改统一头像。',
                  'Connect to a server before changing the shared avatar.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class CacheSettingsPage extends ConsumerWidget {
  const CacheSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final scheme = Theme.of(context).colorScheme;
    final timestamp = app.cacheUpdatedAt == null
        ? '尚未保存同步缓存'
        : '最近更新：${app.cacheUpdatedAt!.toLocal()}';
    return Scaffold(
      appBar: AppBar(title: const Text('缓存与离线')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: <Widget>[
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.phone_android_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '项目、会话摘要、已加载消息和输入草稿会保存在手机本地。服务器不可用时仍可查看最近内容；联网后再继续发送和修改操作。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('本地内容'),
                  subtitle: Text(
                    '${app.workspaces.length} 个项目 · ${app.sessions.length} 个会话 · ${app.messages.length} 条消息\n$timestamp',
                  ),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('清理本地缓存'),
                  subtitle: const Text('只删除手机保存的项目、会话、消息和草稿，不会删除服务器历史'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('清理本地缓存？'),
                        content: const Text('清理后需要联网重新加载项目和会话。服务器上的历史不会被删除。'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => _popDialog(dialogContext, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => _popDialog(dialogContext, true),
                            child: const Text('清理'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(appStateProvider.notifier)
                          .clearLocalCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('本地缓存已清理')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServerAdminPage extends ConsumerStatefulWidget {
  const ServerAdminPage({super.key});

  @override
  ConsumerState<ServerAdminPage> createState() => _ServerAdminPageState();
}

class _ServerAdminPageState extends ConsumerState<ServerAdminPage> {
  late final TextEditingController _adminKey;
  late final TextEditingController _endpoint;
  final Set<String> _selectedDevices = <String>{};
  List<MobileClient> _clients = const <MobileClient>[];
  List<Map<String, dynamic>> _deviceKeys = const <Map<String, dynamic>>[];
  List<String> _logs = const <String>[];
  String? _qrDataUrl;
  DateTime? _qrExpiresAt;
  String? _error;
  bool _loaded = false;
  bool _busy = false;
  bool _logsLoaded = false;

  @override
  void initState() {
    super.initState();
    final endpoint = ref.read(appStateProvider).endpoint;
    _adminKey = TextEditingController();
    _endpoint = TextEditingController(text: _withoutMobilePath(endpoint));
  }

  @override
  void dispose() {
    _adminKey.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  String _withoutMobilePath(String value) {
    var endpoint = value.trim();
    while (endpoint.endsWith('/')) {
      endpoint = endpoint.substring(0, endpoint.length - 1);
    }
    if (endpoint.endsWith('/mobile/v1')) {
      endpoint = endpoint.substring(0, endpoint.length - '/mobile/v1'.length);
    }
    return endpoint;
  }

  String? get _key {
    final value = _adminKey.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _load() async {
    final key = _key;
    if (key == null) {
      setState(() => _error = '请输入管理员 key');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      // Re-entering or refreshing the management page starts a new pairing
      // cycle.  The old ticket is invalidated server-side before the list is
      // shown again, so a QR left on another screen cannot be redeemed later.
      _qrDataUrl = null;
      _qrExpiresAt = null;
    });
    try {
      final api = ref.read(apiProvider);
      await api.adminInvalidatePairing(key);
      final clients = await api.adminClients(key);
      final deviceKeys = await api.adminKeys(key);
      final devices = ref.read(appStateProvider).devices;
      _selectedDevices
        ..clear()
        ..addAll(
          devices.where((device) => device.online).map((device) => device.id),
        );
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _deviceKeys = deviceKeys;
        _loaded = true;
        _busy = false;
        _logsLoaded = false;
        _logs = const <String>[];
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
          _loaded = false;
        });
      }
    }
  }

  Future<void> _createPairing() async {
    final key = _key;
    final endpoint = _withoutMobilePath(_endpoint.text);
    if (key == null || endpoint.isEmpty || _selectedDevices.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiProvider)
          .adminCreatePairing(
            key,
            deviceIds: _selectedDevices.toList(),
            endpoint: endpoint,
          );
      if (mounted) {
        setState(() {
          _qrDataUrl = result['qrDataUrl']?.toString();
          _qrExpiresAt = _parseDate(result['expiresAt']);
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _invalidatePairing() async {
    final key = _key;
    if (key == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).adminInvalidatePairing(key);
      if (mounted) {
        setState(() {
          _busy = false;
          _qrDataUrl = null;
          _qrExpiresAt = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _loadLogs() async {
    final key = _key;
    if (key == null) return;
    setState(() => _busy = true);
    try {
      final logs = await ref.read(apiProvider).adminLogs(key);
      if (mounted) {
        setState(() {
          _logs = logs;
          _logsLoaded = true;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<String?> _askText(
    String title,
    String label, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _popDialog(dialogContext, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    _disposeDialogControllerLater(controller);
    return value;
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _popDialog(dialogContext, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _renameClient(MobileClient client) async {
    final key = _key;
    if (key == null) return;
    final name = await _askText('重命名移动设备', '设备名称', initial: client.name);
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiProvider).adminRenameClient(key, client.id, name);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _revokeClient(MobileClient client) async {
    final key = _key;
    if (key == null ||
        !await _confirm('撤销手机凭据', '撤销「${client.name}」后需要重新扫码或输入管理员 key。')) {
      return;
    }
    try {
      await ref.read(apiProvider).adminRevokeClient(key, client.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _registerKey() async {
    final key = _key;
    if (key == null) return;
    final deviceKey = await _askText('登记设备 key', 'A2Switch 本机设备 key');
    if (deviceKey == null || deviceKey.isEmpty) return;
    final label = await _askText('登记设备 key', '备注名', initial: '新电脑');
    if (label == null || label.isEmpty) return;
    try {
      await ref.read(apiProvider).adminRegisterKey(key, deviceKey, label);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _revokeKey(Map<String, dynamic> item) async {
    final key = _key;
    final id = item['id']?.toString();
    if (key == null || id == null || id.isEmpty) return;
    final label = item['label']?.toString() ?? '这台电脑';
    if (!await _confirm('吊销设备 key', '吊销「$label」后，该电脑上的智能体会被服务器拒绝重连。')) return;
    try {
      await ref.read(apiProvider).adminRevokeKey(key, id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _editKey(Map<String, dynamic> item) async {
    final key = _key;
    final id = item['id']?.toString();
    if (key == null || id == null || id.isEmpty) return;
    final label = await _askText(
      '编辑设备 key',
      '备注名',
      initial: item['label']?.toString() ?? '',
    );
    if (label == null) return;
    final replacement = await _askText('编辑设备 key', '新 key（留空表示不替换）');
    if (replacement == null) return;
    if (label.trim().isEmpty && replacement.trim().isEmpty) return;
    try {
      await ref
          .read(apiProvider)
          .adminUpdateKey(
            key,
            id,
            label: label.trim().isEmpty ? null : label.trim(),
            deviceKey: replacement.trim().isEmpty ? null : replacement.trim(),
          );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  DateTime? _parseDate(Object? value) {
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse('$value');
  }

  Widget _sectionCard(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  Widget _rowAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: _busy ? null : onTap,
  );

  Widget _pairingImage() {
    final value = _qrDataUrl;
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    try {
      final encoded = value.contains(',') ? value.split(',').last : value;
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(
            base64Decode(encoded),
            width: 250,
            height: 250,
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (_) {
      return const Text('二维码图像无法显示，请重新生成。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('服务器管理')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        children: <Widget>[
          _sectionCard('管理员验证', <Widget>[
            Text(
              '管理员 key 只在当前页面内存中使用，不会保存到手机。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adminKey,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '管理员 key',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy ? null : _load,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(_loaded ? '重新验证并刷新' : '验证管理员 key'),
            ),
          ]),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            _ErrorBanner(message: _error!, onRetry: _load),
          ],
          if (_loaded) ...<Widget>[
            const SizedBox(height: 12),
            _sectionCard('一次性配对二维码', <Widget>[
              TextField(
                controller: _endpoint,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '手机可访问的服务器端点',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 10),
              if (app.devices.isEmpty)
                const Text('当前没有可授权的电脑。')
              else
                ...app.devices.map(
                  (device) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selectedDevices.contains(device.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedDevices.add(device.id);
                        } else {
                          _selectedDevices.remove(device.id);
                        }
                        // A ticket encodes the complete device selection.  A
                        // change therefore invalidates the displayed ticket;
                        // the next Generate action issues a fresh one.
                        if (_qrDataUrl != null) {
                          _qrDataUrl = null;
                          _qrExpiresAt = null;
                          unawaited(_invalidatePairing());
                        }
                      });
                    },
                    title: Text(device.label),
                    subtitle: Text(
                      '${device.online ? '在线' : '离线'} · ${device.agents.length} 个智能体',
                    ),
                  ),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || _selectedDevices.isEmpty
                          ? null
                          : _createPairing,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('生成二维码'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '立即作废',
                    onPressed: _busy ? null : _invalidatePairing,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                ],
              ),
              _pairingImage(),
              if (_qrExpiresAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '有效期至 ${_qrExpiresAt!.toLocal()}；扫描成功后立即失效。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            _sectionCard('移动设备', <Widget>[
              if (_clients.isEmpty)
                const Text('还没有配对的移动设备。')
              else
                ..._clients.map(
                  (client) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android_rounded),
                    title: Text(client.name),
                    subtitle: Text(
                      '${client.platform ?? 'android'} · ${client.appVersion ?? 'unknown'} · 授权 ${client.authorizedDevices.length} 台电脑',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rename') _renameClient(client);
                        if (value == 'revoke') _revokeClient(client);
                      },
                      itemBuilder: (_) => const <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'rename', child: Text('重命名')),
                        PopupMenuItem(value: 'revoke', child: Text('撤销')),
                      ],
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            _sectionCard('设备 key', <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _registerKey,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('登记设备 key'),
                ),
              ),
              if (_deviceKeys.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('还没有登记设备 key。'),
                )
              else
                ..._deviceKeys.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.computer_rounded),
                    title: Text(item['label']?.toString() ?? '未命名电脑'),
                    subtitle: Text(
                      '${item['fingerprint'] ?? '无指纹'}${item['instanceIds'] is List ? ' · ${(item['instanceIds'] as List).length} 个实例' : ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editKey(item);
                        if (value == 'revoke') _revokeKey(item);
                      },
                      itemBuilder: (_) => const <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'revoke', child: Text('吊销')),
                      ],
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            _sectionCard('服务日志', <Widget>[
              _rowAction(
                icon: Icons.receipt_long_outlined,
                title: '读取最近 200 行日志',
                subtitle: _logsLoaded ? '已加载 ${_logs.length} 行' : '按需读取，不自动保存',
                onTap: _loadLogs,
              ),
              if (_logsLoaded)
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _logs.isEmpty ? '暂无日志' : _logs.join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onUnlock});
  final Device device;
  final VoidCallback onUnlock;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: device.unlocked
                      ? scheme.tertiaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  device.unlocked
                      ? Icons.lock_open_rounded
                      : Icons.computer_rounded,
                  color: device.unlocked
                      ? scheme.onTertiaryContainer
                      : scheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device.online ? '在线' : '离线'} · ${device.agents.length} 个智能体',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              device.unlocked
                  ? Chip(
                      avatar: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: scheme.onTertiaryContainer,
                      ),
                      label: const Text('已解锁'),
                    )
                  : FilledButton.tonal(
                      onPressed: onUnlock,
                      child: const Text('解锁'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});
  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  bool _handled = false;
  final MobileScannerController _scanner = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();
  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _pairingFromCapture(BarcodeCapture? capture) {
    final raw = capture?.barcodes
        .map((item) => item.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map &&
          decoded['type'] == 'a2s-pairing' &&
          decoded['ticket'] != null &&
          decoded['endpoint'] != null) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // The scanner can also receive arbitrary QR contents; keep the camera
      // active and show a recoverable message below.
    }
    return null;
  }

  void _invalidPairingMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('这不是有效的 A2S 配对二维码')));
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final data = _pairingFromCapture(capture);
    if (data == null) return;
    await _redeemPairing(data, resumeCamera: true);
  }

  Future<void> _pickImage() async {
    if (_handled) return;
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final capture = await _scanner.analyzeImage(
        image.path,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
      final data = _pairingFromCapture(capture);
      if (data == null) {
        _invalidPairingMessage();
        return;
      }
      await _redeemPairing(data, resumeCamera: false);
    } on UnimplementedError {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前设备不支持图片二维码识别')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片识别失败：$error')));
    }
  }

  Future<void> _redeemPairing(
    Map<String, dynamic> data, {
    required bool resumeCamera,
  }) async {
    _handled = true;
    if (resumeCamera) await _scanner.stop();
    try {
      await ref
          .read(appStateProvider.notifier)
          .redeemPairing(PairingPayload.fromJson(data));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配对成功，已解锁所选电脑')));
    } catch (error) {
      _handled = false;
      if (!mounted) return;
      if (resumeCamera) await _scanner.start();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('扫描配对二维码'),
      actions: <Widget>[
        IconButton(
          tooltip: '从图片识别',
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_library_outlined),
        ),
        IconButton(
          tooltip: '打开或关闭手电筒',
          onPressed: () => _scanner.toggleTorch(),
          icon: const Icon(Icons.flashlight_on_rounded),
        ),
      ],
    ),
    body: Stack(
      children: <Widget>[
        MobileScanner(
          controller: _scanner,
          onDetect: _onDetect,
          onDetectError: (error, _) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('二维码识别失败：$error')));
          },
          errorBuilder: (context, error) => Center(
            child: Card(
              margin: const EdgeInsets.all(28),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.no_photography_outlined, size: 42),
                    const SizedBox(height: 12),
                    const Text('相机不可用或权限被拒绝'),
                    const SizedBox(height: 6),
                    Text(
                      error.errorCode.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('从图片识别'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 16,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  child: Text(
                    '将服务器设置中的二维码放入取景框',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});
  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(appStateProvider.notifier).openStats(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final stats = app.stats ?? <String, dynamic>{};
    final relay = stats['relay'] is Map
        ? Map<String, dynamic>.from(stats['relay'] as Map)
        : stats;
    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Row(
            children: <Widget>[
              _MetricCard(
                label: '电脑',
                value: '${app.devices.length}',
                icon: Icons.computer_rounded,
              ),
              const SizedBox(width: 10),
              _MetricCard(
                label: '在线',
                value: '${app.devices.where((item) => item.online).length}',
                icon: Icons.cloud_done_rounded,
              ),
              const SizedBox(width: 10),
              _MetricCard(
                label: '会话',
                value: '${app.sessions.length}',
                icon: Icons.forum_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '服务器状态',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoLine(
                    label: '服务',
                    value: '${stats['service'] ?? 'a2s-server-api'}',
                  ),
                  _InfoLine(label: '实例', value: '${relay['instances'] ?? '—'}'),
                  _InfoLine(label: '在线实例', value: '${relay['online'] ?? '—'}'),
                  _InfoLine(
                    label: '实时连接',
                    value: app.sseConnected ? '已连接' : '等待连接',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 7),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class TerminalPage extends ConsumerStatefulWidget {
  const TerminalPage({super.key, required this.instanceId});
  final String instanceId;
  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  final _input = TextEditingController();
  late final Terminal _terminal;
  Timer? _keepAliveTimer;
  ProviderSubscription<AppState>? _appSubscription;
  String _status = '';
  bool _opened = false;
  String? _terminalId;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 5000);
    _terminal.onOutput = (data) {
      if (_opened && _terminalId != null) {
        unawaited(_sendRaw(data));
      }
    };
    _terminal.onResize = (cols, rows, _, __) {
      if (_opened && _terminalId != null) {
        unawaited(_resizeRemote(cols, rows));
      }
    };
    _appSubscription = ref.listenManual<AppState>(appStateProvider, (
      previous,
      next,
    ) {
      final id = _terminalId;
      if (id == null) return;
      final before = previous?.terminalOutputs[id] ?? '';
      final after = next.terminalOutputs[id] ?? '';
      if (after.isEmpty || after == before) return;
      final delta = after.startsWith(before)
          ? after.substring(before.length)
          : '\r\n$after';
      _terminal.write(delta);
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _appSubscription?.close();
    _input.dispose();
    if (_terminalId != null) {
      ref.read(apiProvider).call(
        widget.instanceId,
        'terminal.close',
        <String, dynamic>{'terminalId': _terminalId},
      );
    }
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final api = ref.read(apiProvider);
      dynamic result;
      try {
        final listed = await api.call(widget.instanceId, 'terminal.list');
        final items = listed is Map && listed['items'] is List
            ? (listed['items'] as List).whereType<Map>().toList()
            : const <Map>[];
        if (items.isNotEmpty) {
          final existing = items.first['terminalId']?.toString();
          if (existing != null && existing.isNotEmpty) {
            result = await api.call(
              widget.instanceId,
              'terminal.attach',
              <String, dynamic>{'terminalId': existing},
            );
          }
        }
      } catch (_) {
        // Older bridges may not expose terminal.list/attach; open a fresh lease.
      }
      result ??= await api.call(
        widget.instanceId,
        'terminal.open',
        <String, dynamic>{'cols': 80, 'rows': 24},
      );
      if (!mounted) return;
      final id = result is Map
          ? result['terminalId']?.toString()
          : result?.toString();
      if (id == null || id.isEmpty) throw StateError('服务器没有返回终端编号');
      setState(() {
        _terminalId = id;
        _opened = true;
        _status = '终端已连接\n';
      });
      final replay = result is Map ? result['replay']?.toString() : null;
      if (replay != null && replay.isNotEmpty) _terminal.write(replay);
      _keepAliveTimer?.cancel();
      _keepAliveTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _keepAlive(),
      );
    } catch (error) {
      if (mounted) setState(() => _status = '连接失败：$error\n');
    }
  }

  Future<void> _keepAlive() async {
    final id = _terminalId;
    if (!_opened || id == null) return;
    try {
      await ref.read(apiProvider).call(
        widget.instanceId,
        'terminal.keepAlive',
        <String, dynamic>{'terminalId': id},
      );
    } catch (error) {
      if (mounted) setState(() => _status = '终端保活失败：$error\n');
    }
  }

  Future<void> _resizeRemote(int cols, int rows) async {
    final id = _terminalId;
    if (!_opened || id == null) return;
    try {
      await ref.read(apiProvider).call(
        widget.instanceId,
        'terminal.resize',
        <String, dynamic>{'terminalId': id, 'cols': cols, 'rows': rows},
      );
    } catch (_) {
      // A resize is advisory; a bridge without PTY resizing can keep output usable.
    }
  }

  Future<void> _sendRaw(String data) async {
    final id = _terminalId;
    if (!_opened || id == null || data.isEmpty) return;
    try {
      await ref.read(apiProvider).call(
        widget.instanceId,
        'terminal.write',
        <String, dynamic>{'terminalId': id, 'data': data},
      );
    } catch (error) {
      if (mounted) setState(() => _status = '终端输入失败：$error\n');
    }
  }

  Future<void> _write() async {
    final value = _input.text;
    if (value.isEmpty || _terminalId == null) return;
    _input.clear();
    await _sendRaw('$value\r');
  }

  void _sendControl(String data) => unawaited(_sendRaw(data));

  Future<void> _close() async {
    final id = _terminalId;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    if (id != null) {
      try {
        await ref.read(apiProvider).call(
          widget.instanceId,
          'terminal.close',
          <String, dynamic>{'terminalId': id},
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _opened = false;
        _terminalId = null;
        _status = '终端已关闭\n';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final terminalText = _terminalId == null
        ? _status
        : '$_status${app.terminalOutputs[_terminalId] ?? ''}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程终端'),
        actions: <Widget>[
          IconButton(
            tooltip: '关闭终端',
            onPressed: _opened ? _close : null,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10131A),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: _opened
                  ? TerminalView(
                      _terminal,
                      autofocus: true,
                      padding: const EdgeInsets.all(14),
                      backgroundOpacity: 0,
                      keyboardType: TextInputType.text,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: SelectableText(
                        terminalText,
                        style: const TextStyle(
                          color: Color(0xFFE7EDF7),
                          fontFamily: 'monospace',
                          height: 1.45,
                        ),
                      ),
                    ),
            ),
          ),
          if (_opened)
            SizedBox(
              height: 46,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  _TerminalKey(
                    label: 'Ctrl',
                    onTap: () => _sendControl('\x03'),
                  ),
                  _TerminalKey(label: 'Esc', onTap: () => _sendControl('\x1b')),
                  _TerminalKey(label: 'Tab', onTap: () => _sendControl('\t')),
                  _TerminalKey(
                    icon: const Icon(Icons.arrow_upward_rounded),
                    semanticLabel: '向上',
                    onTap: () => _sendControl('\x1b[A'),
                  ),
                  _TerminalKey(
                    icon: const Icon(Icons.arrow_downward_rounded),
                    semanticLabel: '向下',
                    onTap: () => _sendControl('\x1b[B'),
                  ),
                  _TerminalKey(
                    icon: const Icon(Icons.arrow_back_rounded),
                    semanticLabel: '向左',
                    onTap: () => _sendControl('\x1b[D'),
                  ),
                  _TerminalKey(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    semanticLabel: '向右',
                    onTap: () => _sendControl('\x1b[C'),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: _opened,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(hintText: '输入命令'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _opened ? _write : _open,
                    child: Text(_opened ? '发送' : '连接'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalKey extends StatelessWidget {
  const _TerminalKey({
    this.label,
    this.icon,
    this.semanticLabel,
    required this.onTap,
  });
  final String? label;
  final Widget? icon;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ActionChip(
      label: icon ?? Text(label ?? ''),
      tooltip: semanticLabel,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    ),
  );
}

class WorkspacePage extends ConsumerStatefulWidget {
  const WorkspacePage({super.key, required this.instanceId});
  final String instanceId;

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  List<Map<String, dynamic>> _workspaces = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _entries = const <Map<String, dynamic>>[];
  String? _path;
  Map<String, dynamic>? _preview;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadWorkspaces);
  }

  List<Map<String, dynamic>> _maps(Object? value, [String key = 'items']) {
    final source = value is Map ? value[key] : value;
    return source is List
        ? source
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : const <Map<String, dynamic>>[];
  }

  Future<void> _loadWorkspaces() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiProvider)
          .call(widget.instanceId, 'workspace.list');
      final workspaces = _maps(result);
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _busy = false;
      });
      if (_path == null && workspaces.isNotEmpty) {
        final path = workspaces.first['path']?.toString();
        if (path != null && path.isNotEmpty) await _openPath(path);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _openPath(String path) async {
    setState(() {
      _busy = true;
      _path = path;
      _preview = null;
      _error = null;
    });
    try {
      final result = await ref.read(apiProvider).call(
        widget.instanceId,
        'workspace.fs.list',
        <String, dynamic>{'path': path},
      );
      if (!mounted) return;
      setState(() {
        _entries = _maps(result, 'entries');
        _busy = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _readFile(Map<String, dynamic> entry) async {
    final path = entry['path']?.toString();
    if (path == null || path.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiProvider).call(
        widget.instanceId,
        'workspace.fs.read',
        <String, dynamic>{'path': path},
      );
      if (mounted) {
        setState(() {
          _preview = result is Map
              ? Map<String, dynamic>.from(result)
              : {'text': '$result'};
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _mkdir() async {
    final parent = _path;
    if (parent == null) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建目录'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '目录名'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _popDialog(dialogContext, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    _disposeDialogControllerLater(controller);
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiProvider).call(
        widget.instanceId,
        'workspace.fs.mkdir',
        <String, dynamic>{'path': parent, 'name': name},
      );
      await _openPath(parent);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _createWorkspace() async {
    final pathController = TextEditingController();
    final titleController = TextEditingController();
    final value = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建工作区'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: pathController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '电脑上的目录路径',
                  hintText: r'D:\Project\my-workspace',
                  prefixIcon: Icon(Icons.folder_open_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '显示名称（可选）',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () {
              final path = pathController.text.trim();
              if (path.isEmpty) return;
              _popDialog(dialogContext, <String, String>{
                'path': path,
                'title': titleController.text.trim(),
              });
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('创建'),
          ),
        ],
      ),
    );
    _disposeDialogControllerLater(pathController);
    _disposeDialogControllerLater(titleController);
    if (value == null || value['path'] == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiProvider)
          .call(widget.instanceId, 'workspace.create', <String, dynamic>{
            'path': value['path'],
            if ((value['title'] ?? '').isNotEmpty) 'title': value['title'],
          });
      await _loadWorkspaces();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _renameWorkspace(Map<String, dynamic> workspace) async {
    final path = workspace['path']?.toString();
    if (path == null || path.isEmpty) return;
    final controller = TextEditingController(
      text:
          workspace['title']?.toString() ?? workspace['name']?.toString() ?? '',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名工作区'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '显示名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _popDialog(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    _disposeDialogControllerLater(controller);
    if (title == null || title.isEmpty) return;
    try {
      await ref.read(apiProvider).call(
        widget.instanceId,
        'workspace.rename',
        <String, dynamic>{'path': path, 'title': title},
      );
      await _loadWorkspaces();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _removeWorkspace(Map<String, dynamic> workspace) async {
    final path = workspace['path']?.toString();
    if (path == null || path.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除工作区登记？'),
        content: Text('只移除服务器登记，不会删除电脑上的文件。\n\n$path'),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _popDialog(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).call(
        widget.instanceId,
        'workspace.remove',
        <String, dynamic>{'path': path},
      );
      if (_path == path && mounted) {
        setState(() {
          _path = null;
          _entries = const <Map<String, dynamic>>[];
        });
      }
      await _loadWorkspaces();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _loadRoots() async {
    try {
      final result = await ref
          .read(apiProvider)
          .call(widget.instanceId, 'workspace.fs.roots');
      if (!mounted) return;
      final text = const JsonEncoder.withIndent('  ').convert(result);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('可用目录根'),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: <Widget>[
            TextButton(
              onPressed: () => _popDialog(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _showPreview() {
    final preview = _preview;
    if (preview == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(preview['path']?.toString() ?? '文件预览'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              preview['binary'] == true
                  ? '二进制文件 · ${preview['mime'] ?? '未知类型'} · ${preview['size'] ?? 0} bytes'
                  : preview['text']?.toString() ?? '没有可显示的文本内容',
              style: const TextStyle(fontFamily: 'monospace', height: 1.4),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final agent = ref.read(appStateProvider).selectedAgent;
    // Capabilities come from the bridge's live `instance.info` frame.  Treat
    // an omitted flag as unsupported so a stale/partial bootstrap cannot make
    // a write or file read button appear usable and fail only after tapping.
    final canBrowse = agent?.capabilities['fileBrowser'] == true;
    final canMutate = agent?.capabilities['workspaceMutation'] == true;
    final canDirectories = agent?.capabilities['directoryMutation'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('工作区与文件'),
        actions: <Widget>[
          IconButton(
            tooltip: '新建工作区',
            onPressed: canMutate ? _createWorkspace : null,
            icon: const Icon(Icons.create_new_folder_rounded),
          ),
          IconButton(
            tooltip: '可用目录根',
            onPressed: canBrowse ? _loadRoots : null,
            icon: const Icon(Icons.account_tree_outlined),
          ),
          if (_preview != null)
            IconButton(
              tooltip: '查看预览',
              onPressed: _showPreview,
              icon: const Icon(Icons.visibility_outlined),
            ),
          if (_path != null)
            IconButton(
              tooltip: '新建目录',
              onPressed: canDirectories ? _mkdir : null,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
          IconButton(
            tooltip: '刷新',
            onPressed: _loadWorkspaces,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _loadWorkspaces)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                if (_path != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: Text(_path!),
                      subtitle: Text('${_entries.length} 个条目'),
                      trailing: IconButton(
                        tooltip: '返回工作区',
                        onPressed: () => setState(() {
                          _path = null;
                          _entries = const <Map<String, dynamic>>[];
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                if (_path == null) ...<Widget>[
                  Text(
                    '已登记工作区',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_workspaces.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.folder_off_outlined),
                        title: Text('暂无工作区'),
                        subtitle: Text('智能体尚未登记可浏览的工作目录。'),
                      ),
                    ),
                  ..._workspaces.map(
                    (workspace) => Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.folder_rounded,
                          color: scheme.primary,
                        ),
                        title: Text(
                          workspace['title']?.toString() ??
                              workspace['path']?.toString() ??
                              '未命名工作区',
                        ),
                        subtitle: Text(workspace['path']?.toString() ?? '没有路径'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') _renameWorkspace(workspace);
                            if (value == 'remove') _removeWorkspace(workspace);
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem(value: 'rename', child: Text('重命名')),
                            PopupMenuItem(value: 'remove', child: Text('移除登记')),
                          ],
                        ),
                        onTap: !canBrowse || workspace['path'] == null
                            ? null
                            : () => _openPath(workspace['path'].toString()),
                      ),
                    ),
                  ),
                ] else ...<Widget>[
                  if (_entries.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.folder_open_outlined),
                        title: Text('目录为空'),
                      ),
                    ),
                  ..._entries.map(
                    (entry) => Card(
                      child: ListTile(
                        leading: Icon(
                          entry['type'] == 'dir'
                              ? Icons.folder_rounded
                              : Icons.description_outlined,
                        ),
                        title: Text(entry['name']?.toString() ?? '未命名'),
                        subtitle: Text(
                          entry['type'] == 'dir'
                              ? '目录'
                              : '${entry['size'] ?? 0} bytes',
                        ),
                        trailing: entry['type'] == 'dir'
                            ? const Icon(Icons.chevron_right_rounded)
                            : const Icon(Icons.visibility_outlined),
                        onTap: entry['type'] == 'dir'
                            ? () => _openPath(entry['path'].toString())
                            : () => _readFile(entry),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class TrajectoryPage extends ConsumerStatefulWidget {
  const TrajectoryPage({super.key, required this.instanceId, this.sessionId});
  final String instanceId;
  final String? sessionId;

  @override
  ConsumerState<TrajectoryPage> createState() => _TrajectoryPageState();
}

class _TrajectoryPageState extends ConsumerState<TrajectoryPage> {
  List<Map<String, dynamic>> _events = const <Map<String, dynamic>>[];
  String? _error;
  bool _busy = false;

  String? get _sessionId =>
      widget.sessionId ?? ref.read(appStateProvider).selectedSessionId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      setState(() => _error = '请先选择一个会话');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await ref.read(apiProvider).call(
        widget.instanceId,
        'session.get',
        <String, dynamic>{'sessionId': sessionId},
      );
      final map = detail is Map
          ? Map<String, dynamic>.from(detail)
          : <String, dynamic>{};
      final snapshot = map['snapshot'] is Map
          ? Map<String, dynamic>.from(map['snapshot'] as Map)
          : const <String, dynamic>{};
      final throughSeq =
          (map['seq'] as num?)?.toInt() ??
          (snapshot['asOfSeq'] as num?)?.toInt() ??
          0;
      final result = await ref.read(apiProvider).call(
        widget.instanceId,
        'session.events',
        <String, dynamic>{
          'sessionId': sessionId,
          'throughSeq': throughSeq,
          'limit': 500,
        },
      );
      final raw = result is Map ? result['events'] ?? result['items'] : result;
      final events = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _events = events;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final turns = _buildTrajectoryTurns(_events);
    return Scaffold(
      appBar: AppBar(
        title: const Text('运行轨迹'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _events.isEmpty
          ? const Center(child: Text('当前会话还没有可显示的事件'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              children: <Widget>[
                _TrajectoryOverview(turns: turns),
                const SizedBox(height: 12),
                ...turns.asMap().entries.map(
                  (entry) => _TrajectoryTurnCard(
                    turn: entry.value,
                    initiallyExpanded: entry.key == turns.length - 1,
                  ),
                ),
              ],
            ),
    );
  }
}

class _TrajectoryTurn {
  _TrajectoryTurn({required this.number});

  final int number;
  final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
  int? startedAt;
  int? endedAt;
  int? inputTokens;
  int? outputTokens;
  int? cachedTokens;
  int? reasoningTokens;
  bool error = false;

  int? get durationMs => startedAt == null || endedAt == null
      ? null
      : (endedAt! - startedAt!).clamp(0, 24 * 60 * 60 * 1000);

  int get steps => events.where((event) {
    final type = _trajectoryType(event);
    return type == 'step/start' || type == 'assistant/message';
  }).length;

  int get tools => events.where((event) {
    final type = _trajectoryType(event);
    return type == 'tool/call' || type == 'tool/result';
  }).length;
}

String _trajectoryType(Map<String, dynamic> event) =>
    event['type']?.toString() ?? event['kind']?.toString() ?? 'event';

Map<String, dynamic> _trajectoryData(Map<String, dynamic> event) {
  final data = event['data'];
  return data is Map
      ? Map<String, dynamic>.from(data)
      : Map<String, dynamic>.from(event);
}

int? _trajectoryNumber(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

int? _trajectoryTime(Map<String, dynamic> event) {
  final value = event['time'] ?? event['ts'] ?? event['timestamp'];
  if (value is num) return value.toInt();
  return DateTime.tryParse('$value')?.millisecondsSinceEpoch;
}

String _trajectoryText(Object? value) {
  if (value is String) return value;
  if (value is List) return value.map(_trajectoryText).join();
  if (value is Map) {
    return _trajectoryText(
      value['text'] ?? value['content'] ?? value['message'],
    );
  }
  return value?.toString() ?? '';
}

List<_TrajectoryTurn> _buildTrajectoryTurns(List<Map<String, dynamic>> events) {
  final turns = <_TrajectoryTurn>[];
  var currentNumber = 1;
  for (final event in events) {
    final type = _trajectoryType(event);
    final data = _trajectoryData(event);
    final explicit = _trajectoryNumber(data['turn'] ?? event['turn']);
    if (explicit != null) {
      currentNumber = explicit;
    } else if (type == 'turn/start' && turns.isNotEmpty) {
      currentNumber = turns.last.number + 1;
    }
    var turn = turns.where((item) => item.number == currentNumber).firstOrNull;
    if (turn == null) {
      turn = _TrajectoryTurn(number: currentNumber);
      turns.add(turn);
    }
    turn.events.add(event);
    final time = _trajectoryTime(event);
    if (time != null) {
      turn.startedAt = turn.startedAt == null
          ? time
          : (time < turn.startedAt! ? time : turn.startedAt);
      turn.endedAt = turn.endedAt == null
          ? time
          : (time > turn.endedAt! ? time : turn.endedAt);
    }
    if (type == 'turn/end') {
      final reason = data['reason'];
      turn.error = reason is Map && reason['kind']?.toString() == 'error';
    }
    final usage = data['usage'];
    if (usage is Map) {
      turn.inputTokens = _addNumber(
        turn.inputTokens,
        usage['inputTokens'] ?? usage['input_tokens'] ?? usage['input'],
      );
      turn.outputTokens = _addNumber(
        turn.outputTokens,
        usage['outputTokens'] ?? usage['output_tokens'] ?? usage['output'],
      );
      turn.cachedTokens = _addNumber(
        turn.cachedTokens,
        usage['cacheReadTokens'] ??
            usage['cache_read_tokens'] ??
            usage['cacheRead'],
      );
      turn.reasoningTokens = _addNumber(
        turn.reasoningTokens,
        usage['reasoningTokens'] ??
            usage['reasoning_tokens'] ??
            usage['reasoning'],
      );
    }
  }
  turns.sort((a, b) => a.number.compareTo(b.number));
  return turns;
}

int? _addNumber(int? current, Object? value) {
  final parsed = _trajectoryNumber(value);
  if (parsed == null) return current;
  return (current ?? 0) + parsed;
}

class _TrajectoryOverview extends StatelessWidget {
  const _TrajectoryOverview({required this.turns});
  final List<_TrajectoryTurn> turns;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalEvents = turns.fold<int>(
      0,
      (sum, item) => sum + item.events.length,
    );
    final totalTools = turns.fold<int>(0, (sum, item) => sum + item.tools);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.timeline_rounded, color: scheme.primary),
                const SizedBox(width: 9),
                Text(
                  '会话轨迹',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${turns.length} 轮',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _TrajectoryMetric(label: '事件', value: '$totalEvents'),
                const SizedBox(width: 8),
                _TrajectoryMetric(
                  label: '步骤',
                  value:
                      '${turns.fold<int>(0, (sum, item) => sum + item.steps)}',
                ),
                const SizedBox(width: 8),
                _TrajectoryMetric(label: '工具', value: '$totalTools'),
              ],
            ),
            if (turns.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              SizedBox(
                height: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: turns
                        .map(
                          (turn) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: turn.error
                                      ? scheme.error
                                      : scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrajectoryMetric extends StatelessWidget {
  const _TrajectoryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );
}

class _TrajectoryTurnCard extends StatelessWidget {
  const _TrajectoryTurnCard({
    required this.turn,
    required this.initiallyExpanded,
  });
  final _TrajectoryTurn turn;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = turn.durationMs == null
        ? '—'
        : _formatTrajectoryDuration(turn.durationMs!);
    final status = turn.error ? '失败' : '完成';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: turn.error
              ? scheme.errorContainer
              : scheme.primaryContainer,
          foregroundColor: turn.error
              ? scheme.onErrorContainer
              : scheme.onPrimaryContainer,
          child: Text('${turn.number}'),
        ),
        title: Text(
          '第 ${turn.number} 轮',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Text('$status · $duration'),
              if (turn.inputTokens != null || turn.outputTokens != null)
                Text(
                  '输入 ${turn.inputTokens ?? 0} · 输出 ${turn.outputTokens ?? 0}',
                ),
            ],
          ),
        ),
        children: <Widget>[
          for (var index = 0; index < turn.events.length; index++)
            _TrajectoryEventRow(
              event: turn.events[index],
              last: index == turn.events.length - 1,
            ),
        ],
      ),
    );
  }
}

String _formatTrajectoryDuration(int milliseconds) {
  if (milliseconds < 1000) return '${milliseconds}ms';
  final seconds = milliseconds / 1000;
  return seconds < 60
      ? '${seconds.toStringAsFixed(1)}s'
      : '${(seconds / 60).toStringAsFixed(1)}m';
}

class _TrajectoryEventRow extends StatelessWidget {
  const _TrajectoryEventRow({required this.event, required this.last});
  final Map<String, dynamic> event;
  final bool last;

  String _label(String type) => switch (type) {
    'turn/start' => '开始一轮对话',
    'turn/end' => '结束一轮对话',
    'step/start' => '模型步骤开始',
    'step/end' => '模型步骤完成',
    'assistant/message' => '助手回复',
    'tool/call' || 'tool-call' => '工具调用',
    'tool/result' || 'tool-result' => '工具结果',
    'reasoning' || 'assistant/reasoning' => '推理过程',
    _ => type,
  };

  IconData _icon(String type) => switch (type) {
    'turn/start' => Icons.play_circle_outline_rounded,
    'turn/end' => Icons.check_circle_outline_rounded,
    'step/start' => Icons.bolt_rounded,
    'step/end' => Icons.done_all_rounded,
    'assistant/message' => Icons.auto_awesome_rounded,
    'tool/call' || 'tool-call' => Icons.build_outlined,
    'tool/result' || 'tool-result' => Icons.output_rounded,
    'reasoning' || 'assistant/reasoning' => Icons.psychology_alt_outlined,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final type = _trajectoryType(event);
    final data = _trajectoryData(event);
    final scheme = Theme.of(context).colorScheme;
    final text = _trajectoryText(
      data['message'] ??
          data['content'] ??
          data['text'] ??
          data['result'] ??
          data['reason'],
    ).trim();
    final name = data['name']?.toString() ?? data['toolName']?.toString();
    final detail = text.isNotEmpty ? text : (name ?? '查看事件详情');
    final seq = event['seq']?.toString() ?? data['seq']?.toString();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Column(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon(type), size: 15, color: scheme.primary),
                ),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(width: 1, color: scheme.outlineVariant),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: scheme.surfaceContainerLow,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                title: Text(_label(type)),
                subtitle: Text(
                  [
                    if (name != null) name,
                    if (seq != null) 'seq $seq',
                    detail,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                children: <Widget>[
                  if (text.isNotEmpty &&
                      (type == 'assistant/message' ||
                          type.contains('reasoning')))
                    MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(p: Theme.of(context).textTheme.bodyMedium),
                    )
                  else
                    SelectableText(
                      _trajectoryDetail(event),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _trajectoryDetail(Map<String, dynamic> event) {
  final data = Map<String, dynamic>.from(event);
  data.remove('stream');
  try {
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    return encoded.length > 12000
        ? '${encoded.substring(0, 12000)}\n…'
        : encoded;
  } catch (_) {
    return '$event';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );
}

class SessionInsightsPage extends ConsumerStatefulWidget {
  const SessionInsightsPage({
    super.key,
    required this.instanceId,
    required this.sessionId,
  });
  final String instanceId;
  final String sessionId;

  @override
  ConsumerState<SessionInsightsPage> createState() =>
      _SessionInsightsPageState();
}

class _SessionInsightsPageState extends ConsumerState<SessionInsightsPage> {
  Map<String, dynamic> _detail = const <String, dynamic>{};
  List<Map<String, dynamic>> _events = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _feedback = const <Map<String, dynamic>>[];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final rawDetail = await api.call(
        widget.instanceId,
        'session.get',
        <String, dynamic>{'sessionId': widget.sessionId},
      );
      final detail = rawDetail is Map
          ? Map<String, dynamic>.from(rawDetail)
          : <String, dynamic>{};
      final projections = detail['projections'];
      final asOfSeq = projections is Map ? projections['asOfSeq'] : null;
      var through = _number(detail['seq']) ?? _number(asOfSeq) ?? 0;
      dynamic rawEvents;
      ApiException? last;
      for (var attempt = 0; attempt < 8; attempt += 1) {
        try {
          rawEvents = await api.call(
            widget.instanceId,
            'session.events',
            <String, dynamic>{
              'sessionId': widget.sessionId,
              'throughSeq': through,
              'limit': 1000,
            },
          );
          break;
        } on ApiException catch (error) {
          last = error;
          if (through > 0 && error.message.contains('past cursor')) {
            through -= 1;
            continue;
          }
          rethrow;
        }
      }
      if (rawEvents == null && last != null) throw last;
      final raw = rawEvents is Map
          ? rawEvents['events'] ?? rawEvents['items']
          : rawEvents;
      final events = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const <Map<String, dynamic>>[];
      List<Map<String, dynamic>> feedback = const <Map<String, dynamic>>[];
      try {
        final result = await api.call(
          widget.instanceId,
          'message.feedback.list',
          <String, dynamic>{'sessionId': widget.sessionId},
        );
        final rows = result is Map ? result['items'] : result;
        if (rows is List) {
          feedback = rows
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _detail = detail;
          _events = events;
          _feedback = feedback;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  int? _number(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  String _detailTitle() {
    final direct = _detail['title']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final projections = _detail['projections'];
    final values = projections is Map ? projections['values'] : null;
    final projected = values is Map ? values['title']?.toString() : null;
    if (projected != null && projected.isNotEmpty) return projected;
    return '会话详情';
  }

  Map<String, dynamic> _usage(Map<String, dynamic> event) {
    final data = event['data'];
    if (data is Map && data['usage'] is Map) {
      return Map<String, dynamic>.from(data['usage'] as Map);
    }
    return const <String, dynamic>{};
  }

  int _sumUsage(List<String> keys) {
    var total = 0;
    for (final event in _events) {
      final usage = _usage(event);
      for (final key in keys) {
        final value = usage[key];
        final number = value is num ? value.toInt() : int.tryParse('$value');
        if (number != null) {
          total += number;
          break;
        }
      }
    }
    return total;
  }

  Future<void> _fork() async {
    try {
      final result = await ref.read(apiProvider).call(
        widget.instanceId,
        'session.fork',
        <String, dynamic>{'sessionId': widget.sessionId},
      );
      final data = result is Map
          ? Map<String, dynamic>.from(result)
          : const <String, dynamic>{};
      final forkedId = data['sessionId']?.toString() ?? data['id']?.toString();
      final state = ref.read(appStateProvider.notifier);
      await state.loadSessions();
      if (forkedId != null && forkedId.isNotEmpty) {
        Session? forked;
        for (final item in ref.read(appStateProvider).sessions) {
          if (item.sessionId == forkedId) {
            forked = item;
            break;
          }
        }
        if (forked != null) await state.selectSession(forked);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已创建会话分支')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建分支失败：$error')));
      }
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(
      text: _detail['title']?.toString() ?? '新对话',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '对话标题'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _popDialog(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    _disposeDialogControllerLater(controller);
    if (title == null || title.isEmpty) return;
    try {
      await ref.read(apiProvider).call(
        widget.instanceId,
        'session.rename',
        <String, dynamic>{'sessionId': widget.sessionId, 'title': title},
      );
      await ref.read(appStateProvider.notifier).loadSessions();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('重命名失败：$error')));
      }
    }
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final input = _sumUsage(const <String>[
      'inputTokens',
      'input_tokens',
      'promptTokens',
      'input',
    ]);
    final output = _sumUsage(const <String>[
      'outputTokens',
      'output_tokens',
      'completionTokens',
      'output',
    ]);
    final cached = _sumUsage(const <String>[
      'cacheReadTokens',
      'cache_read_input_tokens',
      'cachedInputTokens',
      'cacheRead',
      'cacheTokens',
    ]);
    final total = _sumUsage(const <String>[
      'totalTokens',
      'total_tokens',
      'total',
    ]);
    final reasoning = _sumUsage(const <String>[
      'reasoningTokens',
      'reasoning_tokens',
      'reasoning',
    ]);
    final cacheWrite = _sumUsage(const <String>[
      'cacheCreationInputTokens',
      'cache_creation_input_tokens',
      'cacheWriteTokens',
      'cacheWrite',
    ]);
    final totalInput = input + cached;
    final hitRate = totalInput == 0 ? 0 : cached / totalInput;
    final effectiveTotal = total == 0 ? input + output + cached : total;
    final title = _detailTitle();
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '会话 ID：${widget.sessionId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_detail['cwd'] != null)
                          Text(
                            '项目：${_detail['cwd']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: _fork,
                              icon: const Icon(Icons.call_split_rounded),
                              label: const Text('创建分支'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _rename,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('重命名'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TrajectoryPage(
                                    instanceId: widget.instanceId,
                                    sessionId: widget.sessionId,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.timeline_rounded),
                              label: const Text('运行轨迹'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _metric(context, '输入 token', '$input', Icons.login_rounded),
                    const SizedBox(width: 8),
                    _metric(
                      context,
                      '输出 token',
                      '$output',
                      Icons.logout_rounded,
                    ),
                    const SizedBox(width: 8),
                    _metric(
                      context,
                      '缓存命中',
                      '${(hitRate * 100).toStringAsFixed(1)}%',
                      Icons.cached_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _metric(
                      context,
                      '总 token',
                      '$effectiveTotal',
                      Icons.functions_rounded,
                    ),
                    const SizedBox(width: 8),
                    _metric(
                      context,
                      '推理 token',
                      '$reasoning',
                      Icons.psychology_alt_outlined,
                    ),
                    const SizedBox(width: 8),
                    _metric(
                      context,
                      '缓存写入',
                      '$cacheWrite',
                      Icons.save_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.timeline_rounded),
                        title: const Text('运行事件'),
                        trailing: Text('${_events.length}'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.speed_rounded),
                        title: const Text('最后序号'),
                        trailing: Text('${_detail['seq'] ?? '—'}'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.thumb_up_alt_outlined),
                        title: const Text('消息反馈'),
                        trailing: Text('${_feedback.length} 条'),
                      ),
                      if (_feedback.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Wrap(
                            spacing: 8,
                            children: _feedback
                                .map(
                                  (item) => Chip(
                                    label: Text(
                                      'seq ${item['seq']}: ${item['rating']}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          OperationsPage(instanceId: widget.instanceId),
                    ),
                  ),
                  icon: const Icon(Icons.apps_rounded),
                  label: const Text('打开全部服务能力'),
                ),
              ],
            ),
    );
  }
}

class OperationsPage extends ConsumerStatefulWidget {
  const OperationsPage({super.key, required this.instanceId});
  final String instanceId;

  @override
  ConsumerState<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends ConsumerState<OperationsPage> {
  String _output = '';
  bool _busy = false;
  Map<String, dynamic>? _goal;

  String? get _sessionId => ref.read(appStateProvider).selectedSessionId;

  Future<void> _run(
    String method, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) async {
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      final result = await ref
          .read(apiProvider)
          .call(widget.instanceId, method, params);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _output = const JsonEncoder.withIndent('  ').convert(result);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _output = '$error';
        });
      }
    }
  }

  Future<String?> _textDialog(
    String title,
    String label, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popDialog(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _popDialog(dialogContext, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    _disposeDialogControllerLater(controller);
    return value;
  }

  Future<void> _loadGoal() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      final result = await ref.read(apiProvider).call(
        widget.instanceId,
        'goal.get',
        <String, dynamic>{'sessionId': sessionId},
      );
      final map = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      final goal = map['goal'];
      if (mounted) {
        setState(() {
          _goal = goal is Map ? Map<String, dynamic>.from(goal) : null;
          _busy = false;
          _output = const JsonEncoder.withIndent('  ').convert(result);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _output = '$error';
        });
      }
    }
  }

  Future<void> _goalAction(String action) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final goal = _goal;
    await _run('goal.$action', <String, dynamic>{
      'sessionId': sessionId,
      if (goal?['id'] != null) 'goalId': goal!['id'],
      if (goal?['revision'] is num)
        'revision': (goal!['revision'] as num).toInt(),
    });
    await _loadGoal();
  }

  Future<void> _jobAction(String action) async {
    final jobId = await _textDialog('后台任务', '任务 ID');
    if (jobId == null || jobId.isEmpty) return;
    await _run('job.$action', <String, dynamic>{
      'jobId': jobId,
      if (_sessionId != null) 'sessionId': _sessionId,
    });
  }

  Future<void> _loadArchives() async {
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      final result = await ref.read(apiProvider).archives(widget.instanceId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _output = const JsonEncoder.withIndent('  ').convert(result);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _output = '$error';
        });
      }
    }
  }

  Future<void> _archiveSelected(String scope) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      final result = await ref
          .read(apiProvider)
          .archiveSession(widget.instanceId, sessionId, scope: scope);
      await ref.read(appStateProvider.notifier).loadSessions();
      if (mounted) {
        setState(() {
          _busy = false;
          _output = const JsonEncoder.withIndent('  ').convert(result);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _output = '$error';
        });
      }
    }
  }

  Future<void> _restoreSelected() async {
    var sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = await _textDialog('恢复会话归档', 'sessionId');
    }
    if (sessionId == null || sessionId.isEmpty) return;
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      final result = await ref
          .read(apiProvider)
          .restoreSession(widget.instanceId, sessionId);
      await ref.read(appStateProvider.notifier).loadSessions();
      if (mounted) {
        setState(() {
          _busy = false;
          _output = const JsonEncoder.withIndent('  ').convert(result);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _output = '$error';
        });
      }
    }
  }

  Future<void> _loadSessionCache({required bool snapshot}) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      final result = snapshot
          ? await ref.read(apiProvider).snapshot(widget.instanceId, sessionId)
          : await ref
                .read(apiProvider)
                .sessionEvents(widget.instanceId, sessionId);
      if (mounted) {
        setState(() {
          _busy = false;
          _output = const JsonEncoder.withIndent('  ').convert(result);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _output = '$error';
        });
      }
    }
  }

  Widget _section(String title, List<Widget> children) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 7),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ...children,
      ],
    ),
  );

  ListTile _action(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    const capabilityByTitle = <String, String>{
      '搜索会话': 'sessionSearch',
      '重命名当前会话': 'sessionRename',
      '分叉当前会话': 'sessionFork',
      '归档当前会话': 'sessionArchive',
      // DSH exposes pause/resume through the same session gate that advertises
      // queue editing.  Codex/Claude intentionally leave this flag off.
      '暂停当前会话': 'queueUpdate',
      '恢复当前会话': 'queueUpdate',
      '取消当前执行': 'sessionInterrupt',
      '更新排队输入': 'queueUpdate',
      '模型目录': 'modelCatalog',
      '权限预设': 'permissionPresets',
      '审批策略': 'approvalPolicy',
      '选择模型': 'sessionSelectModel',
      '命令清单': 'commands',
      '运行斜杠命令': 'commands',
      '回答审批': 'approvalAnswer',
      '消息反馈': 'messageFeedback',
      '反馈记录': 'messageFeedback',
      '智能体预设': 'agentPresets',
      '选择智能体预设': 'agentPresets',
      '读取智能体预设': 'agentPresets',
      '复制智能体预设': 'agentPresets',
      '删除智能体预设': 'agentPresets',
      '获取附件': 'attachments',
      '后台任务': 'jobs',
      '读取任务输出': 'jobs',
      '停止后台任务': 'jobs',
      '当前目标': 'goals',
      '插件清单': 'pluginManagement',
      '插件配置': 'pluginManagement',
      '启用或禁用插件': 'pluginManagement',
      '插件设置': 'pluginManagement',
      '工作区管理': 'workspaceMutation',
    };
    final capability = capabilityByTitle[title];
    final agent = ref.read(appStateProvider).selectedAgent;
    final supported =
        capability == null ||
        agent == null ||
        agent.capabilities[capability] == true;
    return ListTile(
      enabled: supported,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(supported ? subtitle : '当前智能体未声明此能力'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _busy || !supported ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = _sessionId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务能力'),
        actions: <Widget>[
          IconButton(
            tooltip: '高级方法',
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MethodConsolePage(instanceId: widget.instanceId),
                    ),
                  ),
            icon: const Icon(Icons.terminal_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(),
          _section('会话管理', <Widget>[
            _action('搜索会话', '按标题或正文查询服务器历史', Icons.search_rounded, () async {
              final query = await _textDialog('搜索会话', '关键词');
              if (query != null && query.isNotEmpty) {
                await _run('session.search', <String, dynamic>{'query': query});
              }
            }),
            _action('重命名当前会话', '更新网页端和手机端显示标题', Icons.edit_outlined, () async {
              if (sessionId == null) return;
              final title = await _textDialog('重命名会话', '新标题');
              if (title != null && title.isNotEmpty) {
                await _run('session.rename', <String, dynamic>{
                  'sessionId': sessionId,
                  'title': title,
                });
                await ref.read(appStateProvider.notifier).loadSessions();
              }
            }),
            _action(
              '分叉当前会话',
              '从当前会话创建新的工作分支',
              Icons.call_split_rounded,
              () async {
                if (sessionId != null) {
                  await _run('session.fork', <String, dynamic>{
                    'sessionId': sessionId,
                  });
                  await ref.read(appStateProvider.notifier).loadSessions();
                }
              },
            ),
            _action('归档当前会话', '保留记录并从最近列表移除', Icons.archive_outlined, () async {
              if (sessionId != null) {
                await _run('session.archive', <String, dynamic>{
                  'sessionId': sessionId,
                });
                await ref.read(appStateProvider.notifier).loadSessions();
              }
            }),
            _action(
              '暂停当前会话',
              '停止当前轮次并暂存后续输入',
              Icons.pause_circle_outline_rounded,
              () async {
                if (sessionId != null) {
                  await _run('session.pause', <String, dynamic>{
                    'sessionId': sessionId,
                  });
                }
              },
            ),
            _action(
              '恢复当前会话',
              '继续执行并发送暂存输入',
              Icons.play_circle_outline_rounded,
              () async {
                if (sessionId != null) {
                  await _run('session.resume', <String, dynamic>{
                    'sessionId': sessionId,
                  });
                }
              },
            ),
            _action(
              '取消当前执行',
              '停止执行并清空排队输入',
              Icons.stop_circle_outlined,
              () async {
                if (sessionId != null) {
                  await _run('session.cancel', <String, dynamic>{
                    'sessionId': sessionId,
                  });
                }
              },
            ),
            _action(
              '更新排队输入',
              '查看或替换当前会话等待发送的消息',
              Icons.queue_play_next_rounded,
              () async {
                if (sessionId == null) return;
                final json = await _textDialog(
                  '更新排队输入',
                  'JSON 参数，例如 {"items":[]}',
                  initial: '{"items":[]}',
                );
                if (json == null || json.isEmpty) return;
                try {
                  final value = jsonDecode(json);
                  if (value is! Map) throw const FormatException('必须是 JSON 对象');
                  await _run('session.queueUpdate', <String, dynamic>{
                    'sessionId': sessionId,
                    ...Map<String, dynamic>.from(value),
                  });
                } catch (error) {
                  if (mounted) setState(() => _output = '参数错误：$error');
                }
              },
            ),
          ]),
          _section('模型与交互', <Widget>[
            _action(
              '模型目录',
              '查看当前智能体支持的模型和推理强度',
              Icons.model_training_outlined,
              () => _run('session.modelCatalog'),
            ),
            _action('权限预设', '读取当前会话的权限和审批策略', Icons.policy_outlined, () {
              if (sessionId != null) {
                _run('session.permission', <String, dynamic>{
                  'sessionId': sessionId,
                });
              }
            }),
            _action('审批策略', '在询问和自动拒绝之间切换', Icons.gpp_maybe_outlined, () async {
              if (sessionId == null) return;
              final policy = await _textDialog(
                '审批策略',
                '输入 ask 或 never',
                initial: 'ask',
              );
              if (policy == 'ask' || policy == 'never') {
                await _run('session.approvalPolicy', <String, dynamic>{
                  'sessionId': sessionId,
                  'policy': policy,
                });
              }
            }),
            _action('选择模型', '设置当前会话下次请求使用的模型', Icons.tune_rounded, () async {
              if (sessionId == null) return;
              final provider = await _textDialog('选择模型', 'Provider，例如 openai');
              if (provider == null || provider.isEmpty) return;
              final model = await _textDialog('选择模型', '模型 ID，例如 gpt-5');
              if (model != null && model.isNotEmpty) {
                await _run('session.selectModel', <String, dynamic>{
                  'sessionId': sessionId,
                  'provider': provider,
                  'model': model,
                });
              }
            }),
            _action('命令清单', '查看可用斜杠命令及参数', Icons.code_rounded, () {
              if (sessionId != null) {
                _run('command.list', <String, dynamic>{'sessionId': sessionId});
              }
            }),
            _action(
              '运行斜杠命令',
              '直接调用当前智能体的命令注册表',
              Icons.terminal_outlined,
              () async {
                if (sessionId == null) return;
                final line = await _textDialog('运行命令', '命令，例如 /compact');
                if (line != null && line.startsWith('/')) {
                  await _run('command.run', <String, dynamic>{
                    'sessionId': sessionId,
                    'line': line,
                  });
                }
              },
            ),
            _action(
              '回答审批',
              '输入转发的 requestId 和 allowed-once/rejected/cancelled',
              Icons.fact_check_outlined,
              () async {
                final requestId = await _textDialog('回答审批', 'requestId');
                if (requestId == null || requestId.isEmpty) return;
                final outcome = await _textDialog(
                  '回答审批',
                  '结果',
                  initial: 'allowed-once',
                );
                if (outcome == 'allowed-once' ||
                    outcome == 'rejected' ||
                    outcome == 'cancelled') {
                  await _run('approval.respond', <String, dynamic>{
                    'requestId': requestId,
                    'outcome': outcome,
                  });
                }
              },
            ),
            _action(
              '消息反馈',
              '按轨迹 seq 为助手消息点赞或点踩',
              Icons.thumb_up_alt_outlined,
              () async {
                if (sessionId == null) return;
                final seq = await _textDialog('消息反馈', 'assistant message seq');
                final rating = await _textDialog(
                  '消息反馈',
                  'like、dislike 或 none',
                  initial: 'like',
                );
                final value = int.tryParse(seq ?? '');
                if (value != null &&
                    (rating == 'like' ||
                        rating == 'dislike' ||
                        rating == 'none')) {
                  await _run('message.feedback', <String, dynamic>{
                    'sessionId': sessionId,
                    'seq': value,
                    'rating': rating,
                  });
                }
              },
            ),
            _action('反馈记录', '查看当前会话所有点赞和点踩', Icons.rate_review_outlined, () {
              if (sessionId != null) {
                _run('message.feedback.list', <String, dynamic>{
                  'sessionId': sessionId,
                });
              }
            }),
            _action(
              '智能体预设',
              '查看、选择、复制或删除 Agent 预设',
              Icons.person_pin_outlined,
              () => _run('agentPreset.list'),
            ),
            _action(
              '选择智能体预设',
              '输入预设 ID 并应用到当前会话',
              Icons.person_search_outlined,
              () async {
                final preset = await _textDialog('选择智能体预设', '预设 ID');
                if (preset != null && preset.isNotEmpty) {
                  await _run('agentPreset.select', <String, dynamic>{
                    'sessionId': sessionId,
                    'agentPreset': preset,
                  });
                }
              },
            ),
            _action('读取智能体预设', '查看一个预设的完整内容', Icons.article_outlined, () async {
              final preset = await _textDialog('读取智能体预设', '预设名称');
              if (preset != null && preset.isNotEmpty) {
                await _run('agentPreset.read', <String, dynamic>{
                  'agentPreset': preset,
                });
              }
            }),
            _action(
              '复制智能体预设',
              '从已有预设复制一个可编辑版本',
              Icons.content_copy_outlined,
              () async {
                final json = await _textDialog(
                  '复制智能体预设',
                  'JSON，例如 {"from":"standard","agentPreset":"my-preset"}',
                  initial: '{"from":"","agentPreset":""}',
                );
                if (json == null || json.isEmpty) return;
                try {
                  final value = jsonDecode(json);
                  if (value is! Map) throw const FormatException('必须是 JSON 对象');
                  await _run(
                    'agentPreset.copy',
                    Map<String, dynamic>.from(value),
                  );
                } catch (error) {
                  if (mounted) setState(() => _output = '参数错误：$error');
                }
              },
            ),
            _action(
              '删除智能体预设',
              '删除一个用户自定义预设',
              Icons.delete_outline_rounded,
              () async {
                final preset = await _textDialog('删除智能体预设', '预设名称');
                if (preset != null && preset.isNotEmpty) {
                  await _run('agentPreset.delete', <String, dynamic>{
                    'agentPreset': preset,
                  });
                }
              },
            ),
            _action('获取附件', '按附件编号读取已上传文件', Icons.download_outlined, () async {
              final id = await _textDialog('获取附件', 'attachmentId');
              if (id != null && id.isNotEmpty) {
                await _run('attachment.get', <String, dynamic>{
                  'attachmentId': id,
                });
              }
            }),
          ]),
          _section('任务、目标与插件', <Widget>[
            _action(
              '后台任务',
              '查看、读取或停止任务输出',
              Icons.work_history_outlined,
              () => _run(
                'job.list',
                sessionId == null
                    ? const <String, dynamic>{}
                    : <String, dynamic>{'sessionId': sessionId},
              ),
            ),
            _action(
              '读取任务输出',
              '按任务 ID 继续读取后台输出',
              Icons.description_outlined,
              () => _jobAction('read'),
            ),
            _action(
              '停止后台任务',
              '按任务 ID请求取消任务',
              Icons.cancel_outlined,
              () => _jobAction('kill'),
            ),
            _action('当前目标', '查看目标状态并继续或暂停自动执行', Icons.flag_outlined, () {
              _loadGoal();
            }),
            if (_goal != null) ...<Widget>[
              _action(
                '暂停目标',
                '暂停自动续作并保留目标',
                Icons.pause_rounded,
                () => _goalAction('pause'),
              ),
              _action(
                '恢复目标',
                '重新武装目标续作',
                Icons.play_arrow_rounded,
                () => _goalAction('resume'),
              ),
              _action(
                '完成目标',
                '将当前目标标记为已完成',
                Icons.task_alt_rounded,
                () => _goalAction('complete'),
              ),
              _action(
                '清除目标',
                '移除当前会话的目标',
                Icons.delete_outline_rounded,
                () => _goalAction('clear'),
              ),
              _action(
                '解除目标武装',
                '解除当前目标的自动续作',
                Icons.shield_outlined,
                () => _goalAction('disarm'),
              ),
            ],
            _action(
              '插件清单',
              '读取插件配置能力和启用状态',
              Icons.extension_outlined,
              () => _run('plugin.list'),
            ),
            _action(
              '插件配置',
              '读取当前插件的配置项',
              Icons.settings_input_component_outlined,
              () => _run('plugin.config'),
            ),
            _action(
              '启用或禁用插件',
              '输入插件 ID 和 enabled 布尔值',
              Icons.toggle_on_outlined,
              () async {
                final json = await _textDialog(
                  '插件开关',
                  'JSON，例如 {"pluginId":"x","enabled":true}',
                  initial: '{"id":"","enabled":true}',
                );
                if (json == null || json.isEmpty) return;
                try {
                  final value = jsonDecode(json);
                  if (value is! Map) throw const FormatException('必须是 JSON 对象');
                  await _run(
                    'plugin.setEnabled',
                    Map<String, dynamic>.from(value),
                  );
                } catch (error) {
                  if (mounted) setState(() => _output = '参数错误：$error');
                }
              },
            ),
            _action('插件设置', '写入插件配置 JSON', Icons.tune_outlined, () async {
              final json = await _textDialog(
                '插件设置',
                'JSON 参数',
                initial: '{"id":"","patch":{}}',
              );
              if (json == null || json.isEmpty) return;
              try {
                final value = jsonDecode(json);
                if (value is! Map) throw const FormatException('必须是 JSON 对象');
                await _run(
                  'plugin.setConfig',
                  Map<String, dynamic>.from(value),
                );
              } catch (error) {
                if (mounted) setState(() => _output = '参数错误：$error');
              }
            }),
            _action(
              '工作区管理',
              '新建、重命名、删除、浏览项目文件',
              Icons.folder_copy_outlined,
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkspacePage(instanceId: widget.instanceId),
                ),
              ),
            ),
          ]),
          _section('归档与快照', <Widget>[
            _action(
              '归档列表',
              '查看服务器保存的会话归档',
              Icons.inventory_2_outlined,
              _loadArchives,
            ),
            _action(
              '服务器归档当前会话',
              '只隐藏手机和网页端列表，保留主机历史',
              Icons.archive_outlined,
              () => _archiveSelected('server'),
            ),
            _action(
              '主机归档当前会话',
              '同时调用智能体归档并隐藏服务器条目',
              Icons.archive_rounded,
              () => _archiveSelected('host'),
            ),
            _action(
              '恢复当前会话归档',
              '从服务器归档列表恢复显示',
              Icons.unarchive_outlined,
              _restoreSelected,
            ),
            _action(
              '会话缓存事件',
              '读取服务器缓存的事件、目标和待办快照',
              Icons.event_note_outlined,
              () => _loadSessionCache(snapshot: false),
            ),
            _action(
              '会话快照',
              '读取服务器保存的当前会话快照',
              Icons.camera_alt_outlined,
              () => _loadSessionCache(snapshot: true),
            ),
          ]),
          _section('实例与协议', <Widget>[
            _action(
              '实例健康',
              '读取连接、版本和运行状态',
              Icons.health_and_safety_outlined,
              () => _run('instance.health'),
            ),
            _action(
              '实例信息',
              '读取能力位和支持的方法',
              Icons.info_outline_rounded,
              () => _run('instance.info'),
            ),
            _action(
              '实例连通性',
              '发送 ping 检查服务器往返',
              Icons.network_check_rounded,
              () => _run('instance.ping'),
            ),
          ]),
          if (_output.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _output,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A protocol-aware escape hatch for operations that are available on a
/// particular agent but do not yet have a dedicated mobile card.
class MethodConsolePage extends ConsumerStatefulWidget {
  const MethodConsolePage({super.key, required this.instanceId});
  final String instanceId;
  @override
  ConsumerState<MethodConsolePage> createState() => _MethodConsolePageState();
}

class _MethodConsolePageState extends ConsumerState<MethodConsolePage> {
  final _method = TextEditingController(text: 'session.list');
  final _params = TextEditingController(text: '{}');
  String _result = '输入协议方法并执行。';
  bool _running = false;

  @override
  void dispose() {
    _method.dispose();
    _params.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    Map<String, dynamic> params;
    try {
      final decoded = jsonDecode(
        _params.text.trim().isEmpty ? '{}' : _params.text,
      );
      if (decoded is! Map) throw const FormatException('params 必须是 JSON 对象');
      params = Map<String, dynamic>.from(decoded);
    } catch (error) {
      setState(() => _result = '参数错误：$error');
      return;
    }
    final method = _method.text.trim();
    if (method.isEmpty) return;
    setState(() => _running = true);
    try {
      final result = await ref
          .read(apiProvider)
          .call(widget.instanceId, method, params);
      if (mounted) {
        setState(
          () => _result = const JsonEncoder.withIndent('  ').convert(result),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _result = '$error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('高级方法')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: <Widget>[
          Text(
            '完整协议入口',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '这里可以调用当前智能体声明的任意服务端方法，例如文件、任务、审批、目标、插件和会话方法。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _method,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '方法名',
              prefixIcon: Icon(Icons.code_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _params,
            autocorrect: false,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'JSON 参数',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: const Text('执行方法'),
          ),
          const SizedBox(height: 18),
          Card(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _result,
                style: const TextStyle(fontFamily: 'monospace', height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showManualConnect(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ManualConnectSheet(ref: ref),
  );
}

class _ManualConnectSheet extends StatefulWidget {
  const _ManualConnectSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_ManualConnectSheet> createState() => _ManualConnectSheetState();
}

class _ManualConnectSheetState extends State<_ManualConnectSheet> {
  late final TextEditingController _endpoint;
  late final TextEditingController _key;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final saved = widget.ref.read(appStateProvider).endpoint.trim();
    _endpoint = TextEditingController(
      text: saved.isEmpty ? 'http://127.0.0.1:50443/a2s-api' : saved,
    );
    _key = TextEditingController();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '连接服务器',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _endpoint,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'API 端点',
              hintText: 'http://127.0.0.1:50443/a2s-api',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入端点' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(labelText: '管理 key'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入管理 key' : null,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              if (!(_form.currentState?.validate() ?? false)) return;
              final endpoint = _endpoint.text.trim();
              final key = _key.text;
              Navigator.of(context).pop();
              try {
                await widget.ref
                    .read(appStateProvider.notifier)
                    .connectWithAdmin(endpoint, key);
              } catch (_) {}
            },
            icon: const Icon(Icons.link_rounded),
            label: const Text('验证并连接'),
          ),
        ],
      ),
    ),
  );
}

RelativeRect _selectorMenuPosition(BuildContext context) {
  final overlay = Overlay.of(context).context.findRenderObject();
  final anchor = context.findRenderObject();
  if (overlay is! RenderBox || anchor is! RenderBox) {
    return RelativeRect.fromLTRB(16, kToolbarHeight + 12, 16, 0);
  }
  final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final anchorRect = topLeft & anchor.size;
  // Popup menus should read as a dropdown from the selector, so place the
  // menu's top edge just below the anchor instead of covering the selector.
  final menuTop = anchorRect.bottom + 8;
  return RelativeRect.fromLTRB(
    anchorRect.left,
    menuTop,
    overlay.size.width - anchorRect.right,
    overlay.size.height - menuTop,
  );
}

Future<void> showDevicePicker(BuildContext context, WidgetRef ref) async {
  final app = ref.read(appStateProvider);
  final devices = app.devices;
  if (devices.isEmpty) return;
  final selected = await showMenu<Device>(
    context: context,
    position: _selectorMenuPosition(context),
    constraints: const BoxConstraints(
      minWidth: 300,
      maxWidth: 420,
      maxHeight: 560,
    ),
    items: devices
        .map(
          (device) => PopupMenuItem<Device>(
            value: device,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Row(
              children: <Widget>[
                Icon(
                  device.unlocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        device.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.online ? _t(context, app.locale, '在线', 'Online') : _t(context, app.locale, '离线', 'Offline')} · ${device.agents.length} ${_t(context, app.locale, '个智能体', 'agents')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  device.unlocked
                      ? Icons.check_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
  if (selected == null || !context.mounted) return;
  if (selected.unlocked) {
    ref.read(appStateProvider.notifier).selectDevice(selected);
  } else {
    await showUnlock(context, ref, selected);
  }
}

Future<void> showAgentPicker(BuildContext context, WidgetRef ref) async {
  var device = ref.read(appStateProvider).selectedDevice;
  if (device == null) {
    await showDevicePicker(context, ref);
    device = ref.read(appStateProvider).selectedDevice;
  }
  if (device == null || !context.mounted) return;
  final app = ref.read(appStateProvider);
  final selected = await showMenu<AgentInstance>(
    context: context,
    position: _selectorMenuPosition(context),
    constraints: const BoxConstraints(
      minWidth: 300,
      maxWidth: 420,
      maxHeight: 560,
    ),
    items: device.agents
        .map(
          (agent) => PopupMenuItem<AgentInstance>(
            value: agent,
            enabled: agent.online,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Row(
              children: <Widget>[
                _AgentIcon(type: agent.agentType, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        agent.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        agent.online
                            ? '${_t(context, app.locale, '在线', 'Online')} · ${agent.capabilities.length} ${_t(context, app.locale, '项能力', 'capabilities')}'
                            : _t(context, app.locale, '离线', 'Offline'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                if (agent.instanceId == app.selectedInstanceId)
                  const Icon(Icons.check_rounded, size: 20),
              ],
            ),
          ),
        )
        .toList(),
  );
  if (selected != null && context.mounted && selected.online) {
    ref.read(appStateProvider.notifier).selectAgent(selected);
  }
}

Future<void> showUnlock(
  BuildContext context,
  WidgetRef ref,
  Device device,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UnlockSheet(ref: ref, device: device),
  );
}

class _UnlockSheet extends StatefulWidget {
  const _UnlockSheet({required this.ref, required this.device});

  final WidgetRef ref;
  final Device device;

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  late final TextEditingController _key;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _key.text;
    Navigator.of(context).pop();
    try {
      await widget.ref
          .read(appStateProvider.notifier)
          .unlock(widget.device, value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '解锁 ${widget.device.label}',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '输入 A2Switch 中显示的本机设备 key。key 只用于本次服务器验证，不会保存。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _key,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '设备 key',
            prefixIcon: Icon(Icons.key_rounded),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.lock_open_rounded),
          label: const Text('解锁'),
        ),
      ],
    ),
  );
}

Future<void> showNewConversation(BuildContext context, WidgetRef ref) async {
  final app = ref.read(appStateProvider);
  final agent = app.selectedAgent;
  if (agent == null) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _NewConversationSheet(
      instanceId: agent.instanceId,
      workspaces: app.workspaces,
      ref: ref,
    ),
  );
}

class _NewConversationSheet extends StatefulWidget {
  const _NewConversationSheet({
    required this.instanceId,
    required this.workspaces,
    required this.ref,
  });
  final String instanceId;
  final List<Workspace> workspaces;
  final WidgetRef ref;

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  late final TextEditingController _title;
  String? _path;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: '新对话');
    _path = widget.workspaces.isEmpty ? null : widget.workspaces.first.path;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.ref
          .read(appStateProvider.notifier)
          .createSession(
            cwd: _path,
            title: _title.text.trim().isEmpty ? '新对话' : _title.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新建对话失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '新建对话',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: '对话标题',
            prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.workspaces.isEmpty)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('暂时没有项目'),
              subtitle: Text('创建后可在项目中管理对话。'),
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _path,
            decoration: const InputDecoration(
              labelText: '项目 / 工作区',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            items: widget.workspaces
                .map(
                  (workspace) => DropdownMenuItem<String>(
                    value: workspace.path,
                    child: Text(
                      workspace.displayTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _path = value),
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _create,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: const Text('创建并打开'),
        ),
      ],
    ),
  );
}

Future<void> showTools(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onPickImage,
  VoidCallback? onPickFile,
}) async {
  final agent = ref.read(appStateProvider).selectedAgent;
  if (agent == null) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '工作台工具',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (onPickImage != null && agent.supports('attachments'))
                    _ToolChip(
                      icon: Icons.photo_library_outlined,
                      label: '图片附件',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onPickImage();
                      },
                    ),
                  if (onPickFile != null && agent.supports('attachments'))
                    _ToolChip(
                      icon: Icons.attach_file_rounded,
                      label: '文件附件',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onPickFile();
                      },
                    ),
                  if (agent.supports('fileBrowser'))
                    _ToolChip(
                      icon: Icons.folder_open_rounded,
                      label: '文件',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                WorkspacePage(instanceId: agent.instanceId),
                          ),
                        );
                      },
                    ),
                  _ToolChip(
                    icon: Icons.timeline_rounded,
                    label: '轨迹',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TrajectoryPage(instanceId: agent.instanceId),
                        ),
                      );
                    },
                  ),
                  _ToolChip(
                    icon: Icons.analytics_outlined,
                    label: '会话统计',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      final sessionId = ref
                          .read(appStateProvider)
                          .selectedSessionId;
                      if (sessionId == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SessionInsightsPage(
                            instanceId: agent.instanceId,
                            sessionId: sessionId,
                          ),
                        ),
                      );
                    },
                  ),
                  _ToolChip(
                    icon: Icons.terminal_rounded,
                    label: '终端',
                    onTap: agent.supports('terminal')
                        ? () {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    TerminalPage(instanceId: agent.instanceId),
                              ),
                            );
                          }
                        : () => showInfo(
                            context,
                            '终端未启用',
                            '请在服务器对应的 A2Switch 设置中开启远程终端后再使用。',
                          ),
                  ),
                  _ToolChip(
                    icon: Icons.insights_rounded,
                    label: '能力',
                    onTap: () => showCapabilities(context, agent),
                  ),
                  _ToolChip(
                    icon: Icons.apps_rounded,
                    label: '服务能力',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              OperationsPage(instanceId: agent.instanceId),
                        ),
                      );
                    },
                  ),
                  _ToolChip(
                    icon: Icons.terminal_rounded,
                    label: '高级方法',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MethodConsolePage(instanceId: agent.instanceId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onPressed: onTap,
  );
}

Future<void> showCapabilities(BuildContext context, AgentInstance agent) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: <Widget>[
          Text(
            '${agent.title} 的能力',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ...agent.capabilities.entries
                  .where((item) => item.value == true)
                  .map((item) => Chip(label: Text(capLabel(item.key)))),
            ],
          ),
        ],
      ),
    ),
  );
}

String capLabel(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .replaceAll('_', ' ')
    .trim();
Future<void> showInfo(BuildContext context, String title, String message) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: .2,
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            color: Theme.of(context).colorScheme.onErrorContainer,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );
}

class _A2sMark extends StatelessWidget {
  const _A2sMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: size,
      height: size,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          brightness == Brightness.dark ? Colors.white : Colors.black,
          BlendMode.srcIn,
        ),
        child: Image.asset(
          'assets/a2s-logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'A2S 图标',
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.dataUrl, this.size = 36});
  final String? dataUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = dataUrl;
    if (value == null || value.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _A2sMark(size: size * .58),
      );
    }
    try {
      final comma = value.indexOf(',');
      if (comma < 0) throw const FormatException('invalid avatar');
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          base64Decode(value.substring(comma + 1)),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _AvatarImage(dataUrl: null, size: size),
        ),
      );
    } catch (_) {
      return _AvatarImage(dataUrl: null, size: size);
    }
  }
}

class _AgentIcon extends StatelessWidget {
  const _AgentIcon({required this.type, required this.size});
  final String type;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = switch (type) {
      'claude-code' => 'claude',
      'openai' => 'codex',
      'deepseek' || 'deepseek-harness' => 'dsh',
      _ => type,
    };
    final color = normalized == 'claude'
        ? const Color(0xFFD97757)
        : normalized == 'codex'
        ? scheme.primary
        : normalized == 'dsh'
        ? const Color(0xFF4B7BEC)
        : scheme.tertiary;
    // Keep the brand mark itself visible.  A colored rounded square around a
    // logo reads as a substitute icon and also makes the compact header noisy;
    // surface/state treatment belongs to the selector button instead.
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * .08),
        child: _agentBrandGraphic(normalized, color),
      ),
    );
  }
}

Widget _agentBrandGraphic(String type, Color color) {
  final asset = switch (type) {
    'claude' => 'assets/brands/claude.svg',
    'codex' => 'assets/brands/openai.svg',
    'dsh' => 'assets/brands/deepseek.svg',
    _ => null,
  };
  if (asset != null) {
    return SvgPicture.asset(
      asset,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: type == 'claude'
          ? 'Claude'
          : type == 'codex'
          ? 'OpenAI Codex'
          : 'DeepSeek Harness',
    );
  }
  return Icon(
    Icons.smart_toy_outlined,
    color: color,
    size: 24,
    semanticLabel: '智能体',
  );
}

String themeLabel(ThemeMode value) => value == ThemeMode.light
    ? '浅色'
    : value == ThemeMode.dark
    ? '深色'
    : '跟随系统';
String motionLabel(MotionPreference value) => value == MotionPreference.reduced
    ? '减少动画'
    : value == MotionPreference.off
    ? '关闭动画'
    : '跟随系统';
