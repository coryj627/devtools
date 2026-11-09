// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// Accessibility audit of a slice of DevTools screens (flutter_a11y_test, layer
// "runtime"), on this fork only: dogfood of https://github.com/coryj627/flutter-a11y.
//
// Each test pumps one screen body the way its own screen test does
// (`wrapWithControllers` plus the globals that screen reads) and runs the audit
// battery. Findings are RECORDED, not asserted: the RuntimeFindingsSink in
// test/flutter_test_config.dart writes them to .a11y/flutter/runtime-findings.json
// and `a11y_check_flutter scan` decides, against the committed baseline, what fails
// CI.
@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter_a11y_test/flutter_a11y_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/utils/deep_links_utils.dart';

const _windowSize = Size(1500.0, 1000.0);

/// The globals every screen body reads, around a fake service connection.
void _setGlobals(FakeServiceConnectionManager fake) {
  setGlobal(ServiceConnectionManager, fake);
  setGlobal(NotificationService, NotificationService());
  setGlobal(
    DevToolsEnvironmentParameters,
    ExternalDevToolsEnvironmentParameters(),
  );
  setGlobal(PreferencesController, PreferencesController());
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(OfflineDataController, OfflineDataController());
}

/// A fake connection to a non-web, debug-mode app with no errors badged on
/// [screenId], as the screen tests stub it.
FakeServiceConnectionManager _connectedTo(String screenId) {
  final fake = FakeServiceConnectionManager();
  when(fake.serviceManager.connectedApp!.isFlutterWebAppNow).thenReturn(false);
  when(fake.serviceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
  when(fake.serviceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
  when(
    fake.errorBadgeManager.errorCountNotifier(screenId),
  ).thenReturn(ValueNotifier<int>(0));
  return fake;
}

Future<void> _audit(WidgetTester tester, String screenId, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(seconds: 1));
  // DevTools is a desktop and web tool driven by a pointer: the mobile touch
  // guidelines (48/44 dp) do not apply; WCAG 2.5.8 (24 px) still does.
  final result = await auditScreen(
    tester,
    screenId: screenId,
    config: const A11yAuditConfig(platform: TargetPlatform.macOS),
  );
  // ignore: avoid_print
  print('a11y $screenId: ${result.findings.length} finding(s)');
}

void main() {
  tearDown(() {
    screenControllers.disposeConnectedControllers();
  });

  testWidgetsWithWindowSize('accessibility', _windowSize, (tester) async {
    _setGlobals(_connectedTo('accessibility'));
    await _audit(
      tester,
      'accessibility',
      wrapWithControllers(
        const AccessibilityScreenBody(),
        accessibility: AccessibilityController(),
      ),
    );
  });

  testWidgetsWithWindowSize('logging', _windowSize, (tester) async {
    _setGlobals(_connectedTo('logging'));
    await _audit(
      tester,
      'logging',
      wrapWithControllers(
        const LoggingScreenBody(),
        logging: createMockLoggingControllerWithDefaults(),
      ),
    );
  });

  testWidgetsWithWindowSize('network', _windowSize, (tester) async {
    _setGlobals(_connectedTo('network'));
    await _audit(
      tester,
      'network',
      wrapWithControllers(
        const NetworkScreenBody(),
        network: NetworkController(),
        debugger: createMockDebuggerControllerWithDefaults(),
      ),
    );
  });

  testWidgetsWithWindowSize('app size (no file loaded)', _windowSize, (
    tester,
  ) async {
    _setGlobals(FakeServiceConnectionManager());
    await _audit(
      tester,
      'app-size',
      wrapWithControllers(const AppSizeBody(), appSize: AppSizeController()),
    );
  });

  testWidgetsWithWindowSize('deep links (project selection)', _windowSize, (
    tester,
  ) async {
    _setGlobals(FakeServiceConnectionManager());
    final dtd = MockDTDManager();
    when(dtd.projectRoots()).thenAnswer(
      (_) async => UriList(uris: [Uri.parse('file:///Users/me/my_app/')]),
    );
    setGlobal(DTDManager, dtd);
    await _audit(
      tester,
      'deep-links',
      wrapWithControllers(
        const DeepLinkPage(),
        deepLink: TestDeepLinksController(),
      ),
    );
  });

  testWidgetsWithWindowSize('dtd tools (no connection)', _windowSize, (
    tester,
  ) async {
    _setGlobals(FakeServiceConnectionManager());
    final dtd = MockDTDManager();
    when(dtd.connection).thenReturn(const FixedValueListenable(null));
    setGlobal(DTDManager, dtd);
    await _audit(
      tester,
      'dtd-tools',
      wrapWithControllers(
        const DTDToolsScreenBody(),
        dtdTools: DTDToolsController(),
      ),
    );
  });
}
