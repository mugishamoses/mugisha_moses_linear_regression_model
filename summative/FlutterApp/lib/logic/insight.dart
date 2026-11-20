import 'field_specs.dart';

enum Band { low, typical, high }

Band bandOf(double debt) => debt < ModelFacts.q1 ? Band.low : (debt > ModelFacts.q3 ? Band.high : Band.typical);

String bandLabel(Band b) => switch (b) { Band.low => 'Below typical', Band.typical => 'Typical', Band.high => 'Above typical' };

/// 0..1 position on the comparison bar: three equal-width zones split at the quartiles.
double barPosition(double debt) {
  double seg(double v, double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
  if (debt <= ModelFacts.q1) return seg(debt, ModelFacts.min, ModelFacts.q1) / 3;
  if (debt <= ModelFacts.q3) return 1 / 3 + seg(debt, ModelFacts.q1, ModelFacts.q3) / 3;
  return 2 / 3 + seg(debt, ModelFacts.q3, ModelFacts.max) / 3;
}

String money(num v) => '\$${_group(v.round())}';
String moneyK(num v) => '\$${(v / 1000).toStringAsFixed(1)}k';
String _group(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String grouped(num v) => _group(v.round());

/// One plain-language sentence explaining the main driver. Rules use the values as typed (percent 0–100).
String insightFor(Map<String, double> v) {
  final loans = v['PCTFLOAN']!, tuition = v['TUITIONFEE_IN']!, degree = v['PREDDEG']!, control = v['CONTROL']!;
  String pct(double p) => '${p.toStringAsFixed(p < 10 ? 1 : 0)}%';
  if (loans >= 50) return 'High loan uptake (${pct(loans)}) is the biggest driver at schools like this.';
  if (degree == 3 && tuition >= 30000) {
    return "High tuition (${money(tuition)}) and a bachelor's focus push debt up at schools like this.";
  }
  if (degree == 1) return 'Short certificate programs usually mean less debt at graduation.';
  if (control == 1 && tuition < 15000) return 'Low in-state tuition (${money(tuition)}) helps keep debt down.';
  if (loans < 20) return 'Few students borrow (${pct(loans)}), which keeps typical debt lower.';
  return 'Loan uptake (${pct(loans)}) and tuition (${money(tuition)}) shape most of this estimate.';
}
