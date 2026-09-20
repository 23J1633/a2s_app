import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:a2s_app/main.dart';

void main() {
  testWidgets('renders the connection landing screen with the brand mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ConnectLanding(),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('A2S 图标'), findsOneWidget);
    expect(find.text('连接你的 AI 工作区'), findsOneWidget);
  });
}
