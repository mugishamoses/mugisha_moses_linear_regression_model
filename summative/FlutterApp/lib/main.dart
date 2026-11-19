import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Deployed Render API. Override for local testing: flutter run --dart-define=API_URL=http://10.0.2.2:8000/predict
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://graduate-debt-api.onrender.com/predict');

/// One input per model feature: API key, label, hint, integer?, min, max (same ranges as the Pydantic model).
class Input {
  const Input(this.key, this.label, this.hint, this.isInt, this.min, this.max);
  final String key, label, hint;
  final bool isInt;
  final num min, max;
}

const inputs = [
  Input('UGDS', 'Undergraduate enrolment', 'e.g. 2030', true, 1, 200000),
  Input('TUITIONFEE_IN', 'In-state tuition & fees (USD/yr)', 'e.g. 72690', false, 0, 100000),
  Input('PCTPELL', 'Share with Pell grant (0-1)', 'e.g. 0.20', false, 0, 1),
  Input('PCTFLOAN', 'Share with federal loan (0-1)', 'e.g. 0.28', false, 0, 1),
  Input('UG25ABV', 'Share of students aged 25+ (0-1)', 'e.g. 0.01', false, 0, 1),
  Input('INEXPFTE', 'Instructional spend per student (USD)', 'e.g. 31938', false, 0, 300000),
  Input('MD_EARN_WNE_P10', 'Median earnings 10 yrs after entry (USD)', 'e.g. 84956', false, 10000, 200000),
  Input('AVGFACSAL', 'Avg monthly faculty salary (USD)', 'e.g. 12404', false, 500, 30000),
  Input('CONTROL', 'Control (1 public, 2 private NP, 3 for-profit)', '1-3', true, 1, 3),
  Input('PREDDEG', 'Degree (1 cert, 2 assoc, 3 bachelor)', '1-3', true, 1, 3),
  Input('REGION', 'Region code (1-9)', '1-9', true, 1, 9),
];

void main() => runApp(const MaterialApp(title: 'Graduate Debt Predictor', home: PredictPage()));

class PredictPage extends StatefulWidget {
  const PredictPage({super.key, this.client});
  final http.Client? client; // injectable for tests
  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  final controllers = {for (final i in inputs) i.key: TextEditingController()};
  String result = 'Enter all values and press Predict.';
  bool isError = false, loading = false;

  /// Returns the request body, or throws a readable message for missing / wrong-type / out-of-range values.
  Map<String, num> buildBody() {
    final body = <String, num>{};
    for (final i in inputs) {
      final text = controllers[i.key]!.text.trim();
      if (text.isEmpty) throw '${i.label}: value is missing.';
      final num? v = i.isInt ? int.tryParse(text) : double.tryParse(text);
      if (v == null) throw '${i.label}: must be ${i.isInt ? 'a whole number' : 'a number'}.';
      if (v < i.min || v > i.max) throw '${i.label}: must be between ${i.min} and ${i.max}.';
      body[i.key] = v;
    }
    return body;
  }

  Future<void> predict() async {
    setState(() => loading = true);
    try {
      final res = await (widget.client ?? http.Client())
          .post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(buildBody()))
          .timeout(const Duration(seconds: 90)); // free Render instance can take ~1 min to wake
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _show('Predicted median graduate debt: \$${(data['predicted_median_debt_usd'] as num).toStringAsFixed(0)}', false);
      } else if (res.statusCode == 422) {
        final d = (data['detail'] as List).first;
        _show('Invalid ${(d['loc'] as List).last}: ${d['msg']}', true);
      } else {
        _show('Server error ${res.statusCode}.', true);
      }
    } on String catch (msg) {
      _show(msg, true);
    } catch (e) {
      _show('Could not reach the API. Check your connection and try again.', true);
    }
  }

  void _show(String text, bool error) => setState(() {
        result = text;
        isError = error;
        loading = false;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Graduate Debt Predictor')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final i in inputs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  key: Key(i.key),
                  controller: controllers[i.key],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: i.label, hintText: i.hint, border: const OutlineInputBorder()),
                ),
              ),
            ElevatedButton(onPressed: loading ? null : predict, child: const Text('Predict')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: isError ? Colors.red : Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Text(result,
                      key: const Key('result'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: isError ? Colors.red : null)),
            ),
          ]),
        ),
      ),
    );
  }
}
