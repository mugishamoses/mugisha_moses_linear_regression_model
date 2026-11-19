import 'package:debt_predictor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const valid = {
  'UGDS': '2030', 'TUITIONFEE_IN': '72690', 'PCTPELL': '0.2', 'PCTFLOAN': '0.28', 'UG25ABV': '0.01',
  'INEXPFTE': '31938', 'MD_EARN_WNE_P10': '84956', 'AVGFACSAL': '12404', 'CONTROL': '2', 'PREDDEG': '3', 'REGION': '2',
};

Future<void> fill(WidgetTester t, Map<String, String> values) async {
  t.view.physicalSize = const Size(1080, 5000); // whole form on screen, no scrolling
  addTearDown(t.view.reset);
  await t.pump();
  for (final e in values.entries) {
    await t.enterText(find.byKey(Key(e.key)), e.value);
  }
  await t.tap(find.text('Predict'));
  await t.pumpAndSettle();
}

String result(WidgetTester t) => t.widget<Text>(find.byKey(const Key('result'))).data!;

void main() {
  final client = MockClient((_) async => http.Response('{"predicted_median_debt_usd": 19355.26}', 200));

  testWidgets('one field per input, Predict button, valid prediction', (t) async {
    await t.pumpWidget(MaterialApp(home: PredictPage(client: client)));
    expect(find.byType(TextField), findsNWidgets(inputs.length));
    await fill(t, valid);
    expect(result(t), contains('\$19355'));
  });

  testWidgets('missing, wrong type and out-of-range show errors', (t) async {
    await t.pumpWidget(MaterialApp(home: PredictPage(client: client)));
    await fill(t, {...valid, 'REGION': ''});
    expect(result(t), contains('missing'));
    await fill(t, {...valid, 'UGDS': 'abc'});
    expect(result(t), contains('whole number'));
    await fill(t, {...valid, 'PCTFLOAN': '5'});
    expect(result(t), contains('between'));
  });
}
