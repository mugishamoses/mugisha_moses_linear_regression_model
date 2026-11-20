// Renders every app state with real fonts for visual comparison with design/S*.png.
// Run: flutter test test/screens_test.dart --update-goldens   → images in build/screens/
@Tags(['screens'])
library;

import 'dart:async';
import 'dart:io';

import 'package:debt_predictor/logic/api.dart';
import 'package:debt_predictor/logic/form_controller.dart';
import 'package:debt_predictor/theme/app_theme.dart';
import 'package:debt_predictor/ui/predict_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> loadFonts() async {
  Future<ByteData> f(String p) async => ByteData.sublistView(await File(p).readAsBytes());
  final jakarta = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    jakarta.addFont(f('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();
  final sdk = Platform.environment['FLUTTER_ROOT']!;
  await (FontLoader('MaterialIcons')..addFont(f('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'))).load();
}

http.Client fixed(double v) => MockClient((_) async => http.Response('{"predicted_median_debt_usd": $v}', 200));

void main() {
  setUpAll(loadFonts);

  Future<FormController> pump(WidgetTester t, {http.Client? client, Size size = const Size(390, 844)}) async {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    t.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(t.view.reset);
    final form = FormController(api: Api(client: client ?? fixed(19355.26)));
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: PredictPage(form: form)));
    await t.pumpAndSettle();
    return form;
  }

  Future<void> shot(WidgetTester t, String name) async {
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screens/$name.png'));
  }

  Future<void> scrollBy(WidgetTester t, double dy) async {
    await t.drag(find.byType(SingleChildScrollView).first, Offset(0, -dy));
    await t.pumpAndSettle();
  }

  testWidgets('S1 intro', (t) async {
    await pump(t);
    await shot(t, 'S1_intro');
  });

  testWidgets('S2 filling', (t) async {
    final form = await pump(t);
    form.applyExample(1);
    form.text['TUITIONFEE_IN']!.text = '72,69';
    form.text['INEXPFTE']!.text = '31,9k8';
    form.text['TUITIONFEE_IN']!.text = '72,69';
    form.open = 1;
    form.notifyListeners();
    await t.pumpAndSettle();
    form.focus['TUITIONFEE_IN']!.requestFocus();
    await scrollBy(t, 520);
    await shot(t, 'S2_filling');
  });

  testWidgets('S3 percent fields', (t) async {
    final form = await pump(t);
    form.applyExample(1);
    form.text['UG25ABV']!.text = '';
    form.open = 2;
    form.notifyListeners();
    await t.pumpAndSettle();
    await scrollBy(t, 560);
    await shot(t, 'S3_percent');
  });

  testWidgets('S4 loading', (t) async {
    final never = Completer<http.Response>();
    final form = await pump(t, client: MockClient((_) => never.future));
    form.applyExample(1);
    unawaited(form.predict());
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(milliseconds: 700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screens/S4_loading.png'));
    never.complete(http.Response('{"predicted_median_debt_usd": 1}', 200));
    await t.pumpAndSettle();
  });

  testWidgets('S5 result', (t) async {
    final form = await pump(t, client: fixed(23412));
    form.applyExample(1);
    await form.predict();
    await shot(t, 'S5_result');
  });

  testWidgets('S6 input errors', (t) async {
    final form = await pump(t);
    form.applyExample(1);
    form.text['PCTPELL']!.text = '140';
    form.text['REGION']!.text = '';
    await form.predict();
    await t.pumpAndSettle();
    await shot(t, 'S6_errors');
  });

  testWidgets('S7a network error', (t) async {
    final form = await pump(t, client: MockClient((_) async => throw http.ClientException('down')));
    form.applyExample(1);
    await form.predict();
    await shot(t, 'S7a_network');
  });

  testWidgets('S7b stale', (t) async {
    final form = await pump(t, client: fixed(23412));
    form.applyExample(1);
    await form.predict();
    form.text['TUITIONFEE_IN']!.text = '45,000';
    await shot(t, 'S7b_stale');
  });

  testWidgets('S8 about', (t) async {
    final form = await pump(t, client: fixed(23412));
    form.applyExample(1);
    await form.predict();
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('About this estimate').first);
    await shot(t, 'S8_about');
  });

  testWidgets('S9 region', (t) async {
    await pump(t);
    await t.ensureVisible(find.text('See all 9 regions'));
    await t.pumpAndSettle();
    await t.tap(find.text('See all 9 regions'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('region2')));
    await shot(t, 'S9_region');
  });

  testWidgets('S10 wide result', (t) async {
    final form = await pump(t, client: fixed(23412), size: const Size(1440, 900));
    form.applyExample(1);
    await form.predict();
    form.open = 2;
    form.notifyListeners();
    await shot(t, 'S10_wide');
  });
}
