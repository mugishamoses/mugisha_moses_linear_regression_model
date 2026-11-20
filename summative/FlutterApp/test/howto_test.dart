// End-to-end "how to use it" walkthrough: drives the real app with taps and typing and saves annotated
// screenshots (3x) per process. Predictions come from a fake server that returns the real values the
// production API gave for these exact inputs.
// Run: flutter test test/howto_test.dart --update-goldens --run-skipped   → images in build/howto/
@Tags(['screens'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:debt_predictor/logic/api.dart';
import 'package:debt_predictor/logic/form_controller.dart';
import 'package:debt_predictor/theme/app_theme.dart';
import 'package:debt_predictor/theme/tokens.dart';
import 'package:debt_predictor/ui/molecules.dart';
import 'package:debt_predictor/ui/predict_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Production API answers for the inputs used below (keyed by in-state tuition).
const live = {3000: 19021.21, 72690: 19494.70, 45000: 19807.25, 15535: 13952.12, 10762: 19059.20, 38360: 23335.92};

class Note {
  const Note(this.step, this.title, this.body, this.rings);
  final int step;
  final String title, body;
  final List<Rect> rings;
}

final note = ValueNotifier<Note?>(null);
const rootKey = Key('howto-root');
const ringColor = Color(0xFFFF5A1F);

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

class Harness extends StatelessWidget {
  const Harness({super.key, required this.screen, required this.form});
  final Size screen;
  final FormController form;

  @override
  Widget build(BuildContext context) {
    final wide = screen.width > 900;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        key: rootKey,
        color: const Color(0xFFE9E6DD),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: screen.width,
            height: screen.height,
            child: Stack(children: [
              MediaQuery(
                data: MediaQueryData(
                  size: screen,
                  devicePixelRatio: 3,
                  padding: wide ? EdgeInsets.zero : const EdgeInsets.only(top: 47, bottom: 34),
                  viewPadding: wide ? EdgeInsets.zero : const EdgeInsets.only(top: 47, bottom: 34),
                ),
                child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: PredictPage(form: form)),
              ),
              IgnorePointer(
                child: ValueListenableBuilder(
                  valueListenable: note,
                  builder: (_, n, _) => Stack(children: [
                    for (final r in n?.rings ?? const <Rect>[])
                      Positioned.fromRect(
                        rect: r.inflate(12),
                        child: Container(
                          // outline only: soft halo band + solid ring, the target stays fully visible
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: ringColor.withValues(alpha: .25), width: 5),
                          ),
                          padding: const EdgeInsets.all(1),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(color: ringColor, width: 3.5),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          // instruction strip
          ValueListenableBuilder(
            valueListenable: note,
            builder: (_, n, _) => Container(
              width: screen.width,
              height: wide ? 120 : 150,
              color: C.white,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: n == null
                  ? null
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: ringColor, shape: BoxShape.circle),
                        child: Text('${n.step}', style: T.section.copyWith(color: C.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: T.section.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(n.body, style: T.body.copyWith(color: C.muted, fontSize: 14)),
                        ]),
                      ),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Fake server: answers with the real production value for the input set; [gate] holds the reply (loading shots).
class Server {
  Completer<void>? gate;
  bool down = false;
  http.Client get client => MockClient((req) async {
        if (gate != null) await gate!.future;
        if (down) throw http.ClientException('down');
        final tuition = (jsonDecode(req.body)['TUITIONFEE_IN'] as num).round();
        return http.Response('{"predicted_median_debt_usd": ${live[tuition] ?? 19494.70}}', 200);
      });
}

void main() {
  setUpAll(loadFonts);

  late WidgetTester tt;
  late String folder;
  var step = 0;

  Future<FormController> start(WidgetTester t, String dir, {Size screen = const Size(390, 844), Server? server}) async {
    tt = t;
    folder = dir;
    step = 0;
    final wide = screen.width > 900;
    final total = Size(screen.width, screen.height + (wide ? 120 : 150));
    t.view.physicalSize = total * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final form = FormController(api: Api(client: (server ?? Server()).client));
    await t.pumpWidget(Harness(screen: screen, form: form));
    await t.pumpAndSettle();
    return form;
  }

  Future<void> settle() async {
    await tt.pump(const Duration(milliseconds: 50));
    await tt.pumpAndSettle();
  }

  /// Scrolls [f] into a comfortable position (clear of the top bar and the sticky Predict bar).
  Future<void> reveal(Finder f) async {
    await Scrollable.ensureVisible(tt.element(f.first), alignment: .35);
    await settle();
  }

  Future<void> snap(String title, String body, {List<Finder> rings = const [], bool settleFirst = true}) async {
    if (settleFirst) await settle();
    step++;
    note.value = Note(step, title, body, [for (final f in rings) tt.getRect(f.first)]);
    await tt.pump();
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    await expectLater(find.byKey(rootKey),
        matchesGoldenFile('../build/howto/$folder/${step.toString().padLeft(2, '0')}_$slug.png'));
    note.value = null;
    await tt.pump();
  }

  Finder key(String k) => find.byKey(Key(k));
  Finder field(String k) => find.byKey(Key(k));
  Future<void> type(String k, String text, {bool next = true}) async {
    await reveal(field(k));
    await tt.enterText(field(k), text);
    if (next) await tt.testTextInput.receiveAction(TextInputAction.next);
    await settle();
  }

  Future<void> tap(Finder f) async {
    await reveal(f);
    await tt.tap(f.first);
    await settle();
  }

  Future<void> top() async {
    await tt.drag(find.byType(SingleChildScrollView).first, const Offset(0, 4000));
    await settle();
  }

  Future<void> fillManually() async {
    await tap(find.text('Private nonprofit'));
    await tap(find.text("Bachelor's"));
    await tap(find.text('See all 9 regions'));
    await tt.tap(key('region2'));
    await settle();
    await tt.tap(key('useRegion'));
    await settle();
    for (final (k, v) in [
      ('UGDS', '2030'), ('TUITIONFEE_IN', '72690'), ('INEXPFTE', '31938'),
      ('PCTFLOAN', '28'), ('PCTPELL', '20'), ('UG25ABV', '0.2'), ('MD_EARN_WNE_P10', '84956'),
    ]) {
      await type(k, v);
    }
    await type('AVGFACSAL', '12404', next: false);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
  }

  testWidgets('01 open the app', (t) async {
    await start(t, '01_open_the_app');
    await snap('Open the app', 'This is the only screen. Everything happens here — no menus, no extra pages.');
    await snap('Your estimate appears here', 'This card shows the predicted debt once you press Predict. Errors are explained here too.',
        rings: [key('result')]);
    await snap('Shortcut: try an example', 'Tap an example to fill all 11 inputs with a real school in one tap.',
        rings: [key('example0'), key('example1')]);
    await reveal(find.text('School type'));
    await snap('Fill 4 short sections', '11 inputs grouped in 4 sections. Section 1 "School type" starts open.',
        rings: [find.text('Your inputs')]);
    await snap('Then press Predict', 'The button stays at the bottom. It sends your inputs to the prediction API.',
        rings: [key('predict')]);
  });

  testWidgets('02 fill in the form yourself', (t) async {
    await start(t, '02_fill_in_the_form_yourself');
    await snap('Who runs the school?', 'Tap a chip — "Private nonprofit" — or type 2 in the box (1 public, 2 private nonprofit, 3 for-profit).',
        rings: [find.text('Private nonprofit')]);
    await tap(find.text('Private nonprofit'));
    await snap('Main degree awarded', 'Tap "Bachelor\'s" (or type 3). The box fills in and gets a green check.',
        rings: [find.text("Bachelor's")]);
    await tap(find.text("Bachelor's"));
    await reveal(find.text('See all 9 regions'));
    await snap('Choose the region', 'Type 1–9, or tap "See all 9 regions" to pick from a list.', rings: [find.text('See all 9 regions')]);
    await tap(find.text('See all 9 regions'));
    await snap('Pick "Mid East"', 'Regions group U.S. states. You can also search a state name, e.g. "New York".', rings: [key('region2')]);
    await tt.tap(key('region2'));
    await snap('Confirm the region', 'Tap the green button to put 2 into the Region box.', rings: [key('useRegion')]);
    await tt.tap(key('useRegion'));
    await settle();
    await reveal(field('UGDS'));
    await snap('Section 2 opens: Size & cost', 'Section 1 is done (green check). Now type the number of undergraduates: 2030.',
        rings: [field('UGDS')]);
    await type('UGDS', '2030');
    await snap('In-state tuition per year', 'Type 72690 — commas are added for you. Money fields have a \$ sign.',
        rings: [field('TUITIONFEE_IN')]);
    await type('TUITIONFEE_IN', '72690');
    await snap('Teaching spend per student', 'Type 31938 and press Next on the keyboard.', rings: [field('INEXPFTE')]);
    await type('INEXPFTE', '31938');
    await reveal(field('PCTFLOAN'));
    await snap('Section 3: Students (percentages)', 'Type shares as 0–100. Students who take federal loans: 28 (means 28 %).',
        rings: [field('PCTFLOAN')]);
    await type('PCTFLOAN', '28');
    await snap('Students with Pell grants', 'Type 20. The thin bar under each box shows the share.', rings: [field('PCTPELL')]);
    await type('PCTPELL', '20');
    await snap('Students aged 25 or older', 'Type 0.2 (decimals are allowed).', rings: [field('UG25ABV')]);
    await type('UG25ABV', '0.2');
    await reveal(field('MD_EARN_WNE_P10'));
    await snap('Section 4: Outcomes & staff', 'Median earnings 10 years after entry: type 84956.', rings: [field('MD_EARN_WNE_P10')]);
    await type('MD_EARN_WNE_P10', '84956');
    await snap('Average faculty salary per month', 'Type 12404. That is the last of the 11 inputs.', rings: [field('AVGFACSAL')]);
    await type('AVGFACSAL', '12404', next: false);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    await snap('All 11 inputs ready', 'Every section shows a green check and a summary. "11 of 11 inputs ready" — tap Predict.',
        rings: [key('predict')]);
  });

  testWidgets('03 get your estimate', (t) async {
    final server = Server();
    final form = await start(t, '03_get_your_estimate', server: server);
    await fillManually();
    await snap('Tap Predict', 'Your inputs are checked, then sent to the live prediction API on Render.', rings: [key('predict')]);
    server.gate = Completer();
    await t.tap(key('predict'));
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(milliseconds: 700));
    await snap('Wait a moment', 'The card shows a loading state. The free server may need up to a minute to wake up the first time.',
        rings: [key('result')], settleFirst: false);
    server.gate!.complete();
    server.gate = null;
    await settle();
    expect(form.debt, 19494.70);
    await snap('Read your estimate', 'Median graduate debt: \$19,495. The pill says how it compares: Typical.', rings: [key('debt')]);
    await snap('Compare with other schools', 'The bar shows Low / Typical / High ranges from the dataset; the marker is this school.',
        rings: [find.byType(ComparisonBar)]);
    await snap('Why this number', 'One plain sentence names the main driver, plus the model\'s typical error (±\$3.5k).',
        rings: [find.byIcon(Icons.lightbulb_outline_rounded)]);
    await reveal(find.text('Your inputs'));
    await snap('Your inputs, summarised', 'Each section collapses to a one-line summary. Tap any section to change it.',
        rings: [find.text('Your inputs')]);
  });

  testWidgets('04 learn how it works', (t) async {
    final form = await start(t, '04_learn_how_it_works');
    form.applyExample(1);
    await form.predict();
    await settle();
    await snap('Tap "How is this calculated?"', 'Or the ⓘ button at the top right — both open the same explanation.',
        rings: [find.text('How is this calculated?'), find.byTooltip('About this estimate').first]);
    await tap(find.text('How is this calculated?'));
    await snap('About this estimate', 'What is predicted, where the data comes from (College Scorecard), and how accurate the model is.');
    await snap('Close it', 'Tap "Got it" (or ✕, or swipe down) to return to your result.', rings: [find.text('Got it')]);
    await tt.tap(find.text('Got it'));
    await snap('Back to your result', 'Nothing was lost — your estimate and inputs are still there.', rings: [key('result')]);
  });

  testWidgets('05 change an input and update', (t) async {
    final form = await start(t, '05_change_an_input_and_update');
    await fillManually();
    await form.predict();
    await settle();
    await reveal(find.text('Size & cost'));
    await snap('Open the section to change', 'Tap "Size & cost" to expand it.', rings: [find.text('Size & cost')]);
    await tap(find.text('Size & cost'));
    await snap('Edit a value', 'Change in-state tuition from 72,690 to 45000.', rings: [field('TUITIONFEE_IN')]);
    await type('TUITIONFEE_IN', '45000', next: false);
    FocusManager.instance.primaryFocus?.unfocus();
    await top();
    await snap('The old result is marked out of date', 'The card fades and says "Inputs changed — press Predict to update".',
        rings: [key('result')]);
    await snap('Tap "Update estimate"', 'The button changes name after a result; the lime dot means there are unsaved changes.',
        rings: [key('predict')]);
    await tt.tap(key('predict'));
    await settle();
    expect(form.debt, 19807.25);
    await snap('New estimate', 'Updated instantly: \$19,807 with the lower tuition.', rings: [key('debt')]);
    await snap('Start over any time', 'The circular button clears every input and returns to the start.',
        rings: [find.byTooltip('Start over')]);
  });

  testWidgets('06 fix mistakes', (t) async {
    final form = await start(t, '06_fix_mistakes');
    form.applyExample(1);
    await settle();
    await tap(find.text('Size & cost'));
    await snap('Wrong type: letters in a number', 'Type "2,0a0" in Undergraduate students — the box turns red right away.',
        rings: [field('UGDS')]);
    await type('UGDS', '2,0a0', next: false);
    await snap('The message tells you what to do', '"Enter a whole number". The section header shows "1 issue".',
        rings: [field('UGDS'), find.text('Enter a whole number')]);
    await tap(find.text('Students'));
    await type('PCTPELL', '140', next: false);
    await snap('Out of range', 'A share above 100 % is impossible: "Must be between 0 and 100 %".',
        rings: [field('PCTPELL')]);
    await tap(find.text('School type'));
    await type('REGION', '', next: false);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    await snap('Missing value', 'Leave Region empty, then tap Predict to see what happens.', rings: [field('REGION'), key('predict')]);
    await tt.tap(key('predict'));
    await settle();
    await snap('Errors are listed in the result card', '"3 fields need attention" — each problem with its fix. No prediction is made.',
        rings: [key('result')]);
    await snap('Tap a problem to jump to it', 'Tap "Region — enter a value".', rings: [find.textContaining('Region —')]);
    await tt.tap(find.textContaining('Region —'));
    await settle();
    await snap('Fix it', 'The section opens on the field. Type 4.', rings: [field('REGION')]);
    await type('REGION', '4', next: false);
    await top();
    await snap('The list updates as you fix', 'Region is gone from the list. Fix the other two the same way.',
        rings: [key('result')]);
    await tt.tap(find.textContaining('Undergraduate students —'));
    await settle();
    await type('UGDS', '1175', next: false);
    await top();
    await tt.tap(find.textContaining('Students with Pell grants —'));
    await settle();
    await type('PCTPELL', '29.4', next: false);
    FocusManager.instance.primaryFocus?.unfocus();
    await top();
    await snap('All fixed — Predict again', 'The card is back to normal and every section is green.', rings: [key('predict')]);
    await tt.tap(key('predict'));
    await settle();
    expect(form.debt, 23335.92);
    await snap('Estimate ready', '\$23,336 for this school.', rings: [key('debt')]);
  });

  testWidgets('07 use an example', (t) async {
    final form = await start(t, '07_use_an_example');
    await snap('Tap "For-profit"', 'Fills all 11 inputs with a real for-profit certificate school.', rings: [key('example2')]);
    await tap(key('example2'));
    await reveal(find.text('Your inputs'));
    await snap('Everything is filled in', '4 of 4 sections complete. You can still change any value.', rings: [find.text('Your inputs')]);
    await snap('Tap Predict', '', rings: [key('predict')]);
    await tt.tap(key('predict'));
    await settle();
    expect(form.debt, 13952.12);
    await snap('Estimate for a for-profit school', '\$13,952 — short certificate programs usually mean less debt.', rings: [key('debt')]);
    await tap(key('example0'));
    await top();
    await snap('Try another example', 'Tapping "Public university" swaps the inputs; the old result is marked out of date.',
        rings: [key('example0'), key('result')]);
    await tt.tap(key('predict'));
    await settle();
    await snap('Public university estimate', '\$19,059.', rings: [key('debt')]);
    await tap(find.text('Clear'));
    await snap('Clear resets everything', 'Back to the start screen with empty inputs.', rings: [find.text('Clear')]);
  });

  testWidgets('08 when the server cannot be reached', (t) async {
    final server = Server()..down = true;
    final form = await start(t, '08_when_the_server_cannot_be_reached', server: server);
    form.applyExample(1);
    await settle();
    await tt.tap(key('predict'));
    await settle();
    await snap("Couldn't reach the server", 'No internet, or the server did not answer in 90 s. Your inputs are kept.',
        rings: [key('result')]);
    server.down = false;
    await snap('Tap Retry', 'When you are back online, tap Retry (or Predict).', rings: [find.text('Retry')]);
    await tt.tap(find.text('Retry'));
    await settle();
    await snap('It works again', 'The estimate appears as normal.', rings: [key('debt')]);
  });

  testWidgets('09 browser version', (t) async {
    final form = await start(t, '09_browser_version', screen: const Size(1440, 900));
    await snap('Wide screens get two columns', 'Same app in a browser: result on the left, the form on the right.');
    await tt.tap(key('example1'));
    await settle();
    await snap('Tap an example (or fill the form)', '"Private college" fills every section.', rings: [key('example1')]);
    await tt.tap(key('predict'));
    await settle();
    expect(form.debt, 23335.92);
    form.open = 2;
    form.notifyListeners();
    await snap('Result next to your inputs', 'Edit any section on the right — the estimate on the left stays in view.',
        rings: [key('result')]);
    await tt.tap(find.text('How it works'));
    await snap('"How it works" opens the explanation', 'Same About sheet as on the phone.');
  });

  testWidgets('10 my school', (t) async {
    final form = await start(t, '10_my_school');
    await reveal(key('example3'));
    await snap('Tap "My school"', 'The 4th example (swipe the example row left to reach it). Tuition is \$3,000 per year.',
        rings: [key('example3')]);
    await tap(key('example3'));
    await tap(find.text('Size & cost'));
    await snap('Check the tuition', 'In-state tuition per year shows 3,000 — that is \$250 a month.', rings: [field('TUITIONFEE_IN')]);
    await top();
    await snap('Tap Predict', '', rings: [key('predict')]);
    await tt.tap(key('predict'));
    await settle();
    expect(form.debt, 19021.21);
    await snap('Estimate for your school', '\$19,021 — Typical. "Low in-state tuition (\$3,000) helps keep debt down."',
        rings: [key('result')]);
  });
}
