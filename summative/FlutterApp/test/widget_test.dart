import 'package:debt_predictor/logic/api.dart';
import 'package:debt_predictor/logic/form_controller.dart';
import 'package:debt_predictor/theme/app_theme.dart';
import 'package:debt_predictor/ui/predict_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client ok() => MockClient((_) async => http.Response('{"predicted_median_debt_usd": 19355.26}', 200));

Future<FormController> pump(WidgetTester t, {http.Client? client, Size size = const Size(420, 2600)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final form = FormController(api: Api(client: client ?? ok()));
  await t.pumpWidget(MaterialApp(theme: buildTheme(), home: PredictPage(form: form)));
  return form;
}

Future<void> tapPredict(WidgetTester t) async {
  await t.tap(find.byKey(const Key('predict')));
  await t.pumpAndSettle();
}

String resultText(WidgetTester t) =>
    t.widgetList<Text>(find.descendant(of: find.byKey(const Key('result')), matching: find.byType(Text)))
        .map((w) => w.data ?? '')
        .join(' | ');

void main() {
  testWidgets('rubric: all 11 labelled text fields on the page at start, a "Predict" button, one result area', (t) async {
    await pump(t);
    expect(find.byType(TextField), findsNWidgets(11)); // every section starts expanded — nothing hidden
    for (final label in ['Who runs the school?', 'Region', 'Undergraduate students', 'Students with Pell grants',
        'Average faculty salary per month']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Predict'), findsOneWidget);
    expect(find.byKey(const Key('result')), findsOneWidget);
  });

  testWidgets('a section can still be collapsed and re-opened', (t) async {
    await pump(t);
    await t.tap(find.text('Size & cost'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(8));
    await t.tap(find.text('Size & cost'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(11));
  });

  testWidgets('example + Predict shows the result, then Predict again', (t) async {
    await pump(t);
    await t.ensureVisible(find.byKey(const Key('example1')));
    await t.tap(find.byKey(const Key('example1')));
    await t.pumpAndSettle();
    await tapPredict(t);
    expect(resultText(t), contains('\$19,355'));
    expect(resultText(t), contains('Typical'));
    expect(find.text('Predict again'), findsOneWidget);
  });

  testWidgets('missing, wrong type and out-of-range values show errors in the result area', (t) async {
    final form = await pump(t);
    await tapPredict(t); // everything empty
    expect(resultText(t), contains('11 fields need attention'));

    form.applyExample(0);
    form.text['UGDS']!.text = 'abc';
    form.text['PCTPELL']!.text = '140';
    await tapPredict(t);
    expect(resultText(t), contains('2 fields need attention'));
    expect(resultText(t), contains('Undergraduate students — enter a whole number'));
    expect(resultText(t), contains('Students with Pell grants — must be between 0 and 100 %'));
    expect(find.text('Fix 2 inputs to continue'), findsOneWidget);
  });

  testWidgets('server 422 is shown against the field', (t) async {
    final c = MockClient((_) async => http.Response(
        '{"detail":[{"loc":["body","REGION"],"msg":"Input should be less than or equal to 9"}]}', 422));
    final form = await pump(t, client: c);
    form.applyExample(0);
    await t.pumpAndSettle();
    await tapPredict(t);
    expect(resultText(t), contains('Region — input should be less than or equal to 9'));
  });

  testWidgets('network failure shows Retry; editing after a result marks it stale', (t) async {
    var fail = true;
    final c = MockClient((_) async =>
        fail ? throw http.ClientException('down') : http.Response('{"predicted_median_debt_usd": 19355.26}', 200));
    final form = await pump(t, client: c);
    form.applyExample(2);
    await t.pumpAndSettle();
    await tapPredict(t);
    expect(resultText(t), contains("Couldn't reach the server"));
    fail = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(resultText(t), contains('\$19,355'));
    form.text['TUITIONFEE_IN']!.text = '45,000';
    await t.pumpAndSettle();
    expect(resultText(t), contains('Inputs changed'));
    expect(find.text('Update estimate'), findsOneWidget);
  });

  testWidgets('code chips fill the text field and region sheet picks a region', (t) async {
    final form = await pump(t);
    await t.tap(find.text('Private nonprofit'));
    await t.pumpAndSettle();
    expect(form.text['CONTROL']!.text, '2');
    await t.tap(find.text('See all 9 regions'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('region6')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('useRegion')));
    await t.pumpAndSettle();
    expect(form.text['REGION']!.text, '6');
  });

  testWidgets('wide (browser) layout renders both columns', (t) async {
    await pump(t, size: const Size(1440, 1400));
    expect(find.text('How it works'), findsOneWidget);
    expect(find.byKey(const Key('result')), findsOneWidget);
    expect(find.text('Predict'), findsOneWidget);
  });
}
