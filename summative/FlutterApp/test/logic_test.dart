import 'dart:convert';

import 'package:debt_predictor/logic/api.dart';
import 'package:debt_predictor/logic/field_specs.dart';
import 'package:debt_predictor/logic/form_controller.dart';
import 'package:debt_predictor/logic/insight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('11 fields in 4 sections, ranges match the API', () {
    expect(fields.length, 11);
    expect([for (var s = 0; s < 4; s++) fieldsOf(s).length], [3, 3, 3, 2]);
    expect(spec('REGION').max, 9);
    expect(spec('PCTPELL').max, 100); // shown as %, sent /100
  });

  test('validation messages', () {
    final f = FormController();
    f.text['UGDS']!.text = 'abc';
    expect(f.check('UGDS'), 'Enter a whole number');
    f.text['PCTPELL']!.text = '140';
    expect(f.check('PCTPELL'), 'Must be between 0 and 100 %');
    f.text['REGION']!.text = '12';
    expect(f.check('REGION'), 'Enter a number from 1 to 9');
    f.text['TUITIONFEE_IN']!.text = '31,9k8';
    expect(f.check('TUITIONFEE_IN'), startsWith('Enter numbers only'));
    f.text['TUITIONFEE_IN']!.text = '72,690';
    expect(f.check('TUITIONFEE_IN'), isNull);
    expect(f.errorFor('AVGFACSAL'), isNull); // empty is quiet until Predict is pressed
    f.submitted = true;
    expect(f.errorFor('AVGFACSAL'), 'Enter a value');
  });

  test('request body converts percent and strips commas', () {
    final f = FormController()..applyExample(1);
    final b = f.body();
    expect(b['PCTFLOAN'], closeTo(.541, 1e-9));
    expect(b['UGDS'], 1175);
    expect(b['TUITIONFEE_IN'], 38360);
    expect(b['CONTROL'], 2);
    expect(f.sectionsComplete, 4);
  });

  test('"My school" example sends \$3,000 tuition', () {
    final f = FormController()..applyExample(3);
    expect(examples[3].label, 'My school');
    expect(f.body()['TUITIONFEE_IN'], 3000);
    expect(f.sectionsComplete, 4);
    expect(insightFor({for (final e in f.body().entries) e.key: e.value.toDouble() * (e.key.startsWith('PCT') || e.key == 'UG25ABV' ? 100 : 1)}),
        contains('Low in-state tuition (\$3,000)'));
  });

  test('band, bar position and insight', () {
    expect(bandOf(19355), Band.typical);
    expect(bandOf(9000), Band.low);
    expect(bandOf(30000), Band.high);
    expect(barPosition(ModelFacts.q1), closeTo(1 / 3, 1e-9));
    expect(barPosition(ModelFacts.q3), closeTo(2 / 3, 1e-9));
    expect(barPosition(0), 0);
    expect(barPosition(1e6), 1);
    expect(insightFor({'PCTFLOAN': 54, 'TUITIONFEE_IN': 38360, 'PREDDEG': 3, 'CONTROL': 2}), contains('loan uptake (54%)'));
    expect(insightFor({'PCTFLOAN': 28, 'TUITIONFEE_IN': 72690, 'PREDDEG': 3, 'CONTROL': 2}), contains('High tuition'));
    expect(insightFor({'PCTFLOAN': 30, 'TUITIONFEE_IN': 9000, 'PREDDEG': 1, 'CONTROL': 3}), contains('certificate'));
  });

  test('api maps 200, 422 and network failure', () async {
    Api api(int code, String body) => Api(client: MockClient((_) async => http.Response(body, code)));
    expect(await api(200, '{"predicted_median_debt_usd": 19355.26}').predict({}), 19355.26);
    final e422 = jsonEncode({
      'detail': [
        {'loc': ['body', 'REGION'], 'msg': 'Input should be less than or equal to 9'}
      ]
    });
    await expectLater(api(422, e422).predict({}),
        throwsA(isA<ApiFieldError>().having((e) => e.key, 'key', 'REGION')));
    await expectLater(api(500, 'oops').predict({}), throwsA(isA<ApiNetworkError>()));
    final down = Api(client: MockClient((_) async => throw http.ClientException('down')));
    await expectLater(down.predict({}), throwsA(isA<ApiNetworkError>()));
  });
}
