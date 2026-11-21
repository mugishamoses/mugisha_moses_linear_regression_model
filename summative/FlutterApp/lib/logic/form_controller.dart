import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api.dart';
import 'field_specs.dart';
import 'insight.dart';

enum Phase { idle, loading, result, inputError, networkError }

enum SectionState { notStarted, inProgress, complete, error }

class FieldIssue {
  const FieldIssue(this.key, this.message);
  final String key, message;
}

/// All page state: field text, validation, section progress, request phase.
class FormController extends ChangeNotifier {
  FormController({Api? api}) : api = api ?? Api() {
    for (final f in fields) {
      text[f.key] = TextEditingController()..addListener(() => _onEdit(f.key));
      focus[f.key] = FocusNode();
    }
  }

  final Api api;
  final text = <String, TextEditingController>{};
  final focus = <String, FocusNode>{};

  Phase phase = Phase.idle;
  bool stale = false, waking = false, submitted = false;
  double? debt;
  Map<String, double> lastInputs = {};
  List<FieldIssue> issues = [];
  String networkDetail = '';
  String? serverIssueKey, serverIssue;
  int? example;
  // All 4 sections start expanded so every one of the 11 input fields is visible on the page.
  Set<int> open = {0, 1, 2, 3};
  bool _bulk = false;
  Timer? _wakeTimer;

  bool get busy => phase == Phase.loading;

  // ---------- parsing & validation ----------
  static String clean(String s) => s.replaceAll(RegExp(r'[,\s$%]'), '');

  double? parse(String key) => double.tryParse(clean(text[key]!.text));

  /// null = valid; '' = empty; otherwise the message.
  String? check(String key) {
    final f = spec(key), raw = clean(text[key]!.text);
    if (raw.isEmpty) return '';
    final v = f.isInt ? int.tryParse(raw) : double.tryParse(raw);
    if (v == null) {
      return f.isInt ? 'Enter a whole number' : 'Enter numbers only — e.g. ${f.hint.replaceFirst('e.g. ', '')}';
    }
    if (v < f.min || v > f.max) {
      return switch (f.kind) {
        Kind.code => 'Enter a number from ${f.min} to ${f.max}',
        Kind.percent => 'Must be between 0 and 100 %',
        _ => 'Must be between ${grouped(f.min)} and ${grouped(f.max)}',
      };
    }
    if (key == serverIssueKey) return serverIssue;
    return null;
  }

  bool isValid(String key) => check(key) == null;

  /// Error text to show under a field now (empty fields only complain after Predict was pressed).
  String? errorFor(String key) {
    final c = check(key);
    if (c == null) return null;
    if (c.isEmpty) return submitted ? 'Enter a value' : null;
    return c;
  }

  int get readyCount => fields.where((f) => isValid(f.key)).length;

  SectionState sectionState(int s) {
    final fs = fieldsOf(s);
    if (fs.any((f) => errorFor(f.key) != null)) return SectionState.error;
    final ok = fs.where((f) => isValid(f.key)).length;
    if (ok == fs.length) return SectionState.complete;
    final touched = fs.any((f) => text[f.key]!.text.isNotEmpty);
    return touched ? SectionState.inProgress : SectionState.notStarted;
  }

  /// First section that still needs input (highlighted in the progress dots), or null when all are done.
  int? get firstIncomplete {
    for (var i = 0; i < 4; i++) {
      if (sectionState(i) != SectionState.complete) return i;
    }
    return null;
  }

  int sectionDone(int s) => fieldsOf(s).where((f) => isValid(f.key)).length;
  int get sectionsComplete => List.generate(4, sectionState).where((x) => x == SectionState.complete).length;
  int get sectionsWithErrors => List.generate(4, sectionState).where((x) => x == SectionState.error).length;

  List<FieldIssue> currentIssues() => [
        for (final f in fields)
          if (errorFor(f.key) case final m?) FieldIssue(f.key, m),
      ];

  // ---------- editing ----------
  final _last = <String, String>{};

  void _onEdit(String key) {
    final now = text[key]!.text;
    if (_bulk || _last[key] == now) return; // cursor/focus changes fire the listener too
    _last[key] = now;
    if (key == serverIssueKey) serverIssueKey = serverIssue = null;
    example = null;
    if (phase == Phase.result) stale = true;
    if (phase == Phase.inputError) {
      issues = currentIssues();
      if (issues.isEmpty) phase = debt != null ? Phase.result : Phase.idle;
    }
    notifyListeners();
  }

  void toggle(int s) {
    open.contains(s) ? open.remove(s) : open.add(s);
    notifyListeners();
  }

  void setCode(String key, int code) => text[key]!.text = '$code';

  void applyExample(int i) {
    _setAll(examples[i].values);
    example = i;
    notifyListeners();
  }

  void clear() {
    _setAll({});
    phase = Phase.idle;
    debt = null;
    stale = submitted = false;
    issues = [];
    example = null;
    open = {0, 1, 2, 3};
    notifyListeners();
  }

  void _setAll(Map<String, String> values) {
    _bulk = true;
    for (final f in fields) {
      text[f.key]!.text = _last[f.key] = values[f.key] ?? '';
    }
    _bulk = false;
    serverIssueKey = serverIssue = null;
    if (phase == Phase.result) stale = true;
    if (phase == Phase.inputError || phase == Phase.networkError) phase = debt != null ? Phase.result : Phase.idle;
  }

  /// Opens the field's section and focuses it (the scroll view brings it into view).
  void jumpTo(String key) {
    open.add(spec(key).section);
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus[key]!.requestFocus());
  }

  // ---------- request ----------
  Map<String, num> body() => {
        for (final f in fields)
          f.key: f.kind == Kind.percent
              ? parse(f.key)! / 100
              : (f.isInt ? parse(f.key)!.round() : parse(f.key)!),
      };

  Future<void> predict() async {
    if (busy) return;
    submitted = true;
    issues = currentIssues();
    if (issues.isNotEmpty) {
      phase = Phase.inputError;
      open.add(spec(issues.first.key).section);
      notifyListeners();
      return;
    }
    final req = body();
    final inputs = {for (final f in fields) f.key: parse(f.key)!};
    phase = Phase.loading;
    waking = false;
    _wakeTimer = Timer(const Duration(seconds: 5), () {
      waking = true;
      notifyListeners();
    });
    notifyListeners();
    try {
      debt = await api.predict(req);
      lastInputs = inputs;
      phase = Phase.result;
      stale = false;
    } on ApiFieldError catch (e) {
      final known = fields.any((f) => f.key == e.key);
      serverIssueKey = known ? e.key : null;
      serverIssue = e.message;
      issues = [FieldIssue(known ? e.key : fields.first.key, e.message)];
      phase = Phase.inputError;
      if (known) open.add(spec(e.key).section);
    } on ApiNetworkError catch (e) {
      networkDetail = e.detail;
      phase = Phase.networkError;
    } finally {
      _wakeTimer?.cancel();
      waking = false;
      notifyListeners();
    }
  }

  /// One-line summary of a section's values, e.g. "2,030 students · $72,690 tuition".
  String summary(int s) {
    String show(FieldSpec f) {
      final v = parse(f.key);
      if (!isValid(f.key) || v == null) return '—';
      return switch (f.kind) {
        Kind.code => f.key == 'REGION'
            ? regions.firstWhere((r) => r.code == v.round()).name
            : f.chips.firstWhere((c) => c.code == v.round()).label,
        Kind.count => '${grouped(v)} ${f.short}',
        Kind.money => f.key == 'AVGFACSAL' ? '${money(v)}${f.short}' : '${money(v)} ${f.short}',
        Kind.percent => '${clean(text[f.key]!.text)}% ${f.short}',
      };
    }

    return fieldsOf(s).map(show).join(' · ');
  }

  @override
  void dispose() {
    _wakeTimer?.cancel();
    for (final c in text.values) {
      c.dispose();
    }
    for (final f in focus.values) {
      f.dispose();
    }
    super.dispose();
  }
}
