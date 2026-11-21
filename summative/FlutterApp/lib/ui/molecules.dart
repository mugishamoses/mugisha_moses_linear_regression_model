import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/field_specs.dart';
import '../logic/form_controller.dart';
import '../logic/insight.dart';
import '../theme/tokens.dart';
import 'atoms.dart';

/// Adds thousands separators while typing, but leaves anything non-numeric alone so the user sees what they typed.
class GroupingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(',', '');
    final m = RegExp(r'^(\d+)(\.\d*)?$').firstMatch(raw);
    if (m == null) return newValue;
    final out = grouped(int.parse(m[1]!)) + (m[2] ?? '');
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

/// Label + text field (+ $ prefix / % suffix / status icon) + helper or error + mini bar for percentages.
class LabeledField extends StatelessWidget {
  const LabeledField(this.form, this.f, {super.key, this.compact = false, this.onRegionTap});
  final FormController form;
  final FieldSpec f;
  final bool compact;
  final VoidCallback? onRegionTap;

  @override
  Widget build(BuildContext context) {
    final error = form.errorFor(f.key);
    final valid = form.isValid(f.key);
    final focusNode = form.focus[f.key]!;
    final last = fieldsOf(f.section).last.key == f.key;
    final value = form.parse(f.key);
    final icon = error != null
        ? const Icon(Icons.error_rounded, color: C.error, size: 22)
        : (valid ? const Icon(Icons.check_circle_rounded, color: C.forest, size: 22) : null);
    final validBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.field), borderSide: const BorderSide(color: C.forest, width: 1.5));

    final field = TextField(
      key: Key(f.key),
      controller: form.text[f.key],
      focusNode: focusNode,
      enabled: !form.busy,
      style: T.value,
      keyboardType: TextInputType.numberWithOptions(decimal: !f.isInt),
      textInputAction: last && f.section == 3 ? TextInputAction.done : TextInputAction.next,
      inputFormatters: [if (f.kind == Kind.count || f.kind == Kind.money) GroupingFormatter()],
      onTapOutside: (_) => focusNode.unfocus(),
      onEditingComplete: () {
        if (last && f.section == 3) {
          focusNode.unfocus();
          form.predict();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },
      decoration: InputDecoration(
        hintText: f.hint,
        errorText: error,
        errorStyle: const TextStyle(height: 0, fontSize: 0), // message rendered below with an icon instead
        enabledBorder: valid ? validBorder : null,
        prefixIcon: f.kind == Kind.money
            ? Container(
                width: 44,
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.center,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: C.divider))),
                child: Text('\$', style: T.value.copyWith(color: C.muted)),
              )
            : null,
        suffixIcon: (f.kind == Kind.percent || icon != null)
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (f.kind == Kind.percent)
                    Text('%', style: T.value.copyWith(color: error != null ? C.error : C.muted)),
                  if (icon != null) ...[const SizedBox(width: 10), icon],
                ]),
              )
            : null,
      ),
    );

    return Semantics(
      label: f.label,
      hint: f.helper,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.label, style: T.label.copyWith(color: error != null ? C.error : C.ink, fontSize: compact ? 13 : 14)),
        const SizedBox(height: 8),
        _Shake(trigger: error != null && form.submitted, child: field),
        if (f.kind == Kind.percent) ...[
          const SizedBox(height: 8),
          MiniBar((value ?? 0) / 100, error: error != null && value != null && value > 100),
        ],
        const SizedBox(height: 6),
        if (error != null)
          Row(children: [
            const Icon(Icons.warning_rounded, color: C.error, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(error, style: T.small.copyWith(color: C.error, fontWeight: FontWeight.w500))),
          ])
        else if (f.key == 'REGION' && onRegionTap != null)
          InkWell(
            onTap: onRegionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('See all 9 regions', style: T.label.copyWith(color: C.forest)),
                const Icon(Icons.chevron_right_rounded, color: C.forest, size: 20),
              ]),
            ),
          )
        else if (f.kind != Kind.code)
          Text(compact ? f.helper.split(',').first : f.helper, style: T.small),
      ]),
    );
  }
}

/// One horizontal shake when an error appears (skipped with reduced motion).
class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.child});
  final bool trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(trigger),
        tween: Tween(begin: trigger && !reduceMotion(context) ? 1 : 0, end: 0),
        duration: const Duration(milliseconds: 400),
        builder: (_, t, c) => Transform.translate(offset: Offset(8 * t * (t * 10 % 2 < 1 ? 1 : -1), 0), child: c),
        child: child,
      );
}

/// Code field (1–3 / 1–9) with tap-to-fill chips; chips and typed text stay in sync.
class CodeField extends StatelessWidget {
  const CodeField(this.form, this.f, {super.key, this.onRegionTap});
  final FormController form;
  final FieldSpec f;
  final VoidCallback? onRegionTap;

  @override
  Widget build(BuildContext context) {
    final current = form.isValid(f.key) ? form.parse(f.key)?.round() : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(form, f, onRegionTap: onRegionTap),
      if (f.chips.isNotEmpty) ...[
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in f.chips)
            PillChip(c.label,
                selected: current == c.code, enabled: !form.busy, onTap: () => form.setCode(f.key, c.code)),
        ]),
      ],
    ]);
  }
}

/// "Your inputs" + 4 dots + caption.
class ProgressRow extends StatelessWidget {
  const ProgressRow(this.form, {super.key, this.large = false});
  final FormController form;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final errors = form.sectionsWithErrors;
    final done = form.sectionsComplete;
    DotState dot(int i) => switch (form.sectionState(i)) {
          SectionState.complete => DotState.done,
          SectionState.error => DotState.error,
          _ => form.firstIncomplete == i ? DotState.current : DotState.empty,
        };
    return Row(children: [
      Expanded(child: Text('Your inputs', style: T.section.copyWith(fontSize: large ? 22 : 18))),
      for (var i = 0; i < 4; i++) ProgressDot(dot(i)),
      const SizedBox(width: 10),
      Flexible(flex: 0, child: Text(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        errors > 0 ? '$errors section${errors == 1 ? '' : 's'} need${errors == 1 ? 's' : ''} fixes' : '$done of 4 sections',
        style: T.small.copyWith(color: errors > 0 ? C.error : C.muted, fontSize: 13, fontWeight: errors > 0 ? FontWeight.w600 : null),
      )),
      if (done == 4) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check_rounded, size: 16, color: C.forest)),
    ]);
  }
}

/// Low / Typical / High track split at the dataset quartiles, with an animated marker + tooltip.
class ComparisonBar extends StatelessWidget {
  const ComparisonBar({super.key, this.debt, this.faded = false});
  final double? debt; // null = placeholder (no marker)
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final placeholder = debt == null;
    final zones = placeholder ? [C.skeleton, C.skeleton, C.skeleton] : [C.softGreen, C.midGreen, C.warningTint];
    return Opacity(
      opacity: faded ? .4 : 1,
      child: Column(children: [
        SizedBox(
          height: placeholder ? 14 : 56,
          child: LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth;
            return Stack(clipBehavior: Clip.none, alignment: Alignment.bottomLeft, children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(R.pill),
                  child: Row(children: [
                    for (final z in zones) Expanded(child: Container(height: 10, color: z)),
                  ]),
                ),
              ),
              if (!placeholder)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: barPosition(debt!)),
                  duration: motion(context, D.slow),
                  curve: Curves.easeOutCubic,
                  builder: (_, p, _) => Positioned(
                    left: (p * w - 12).clamp(-4, w - 20),
                    bottom: -5,
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(R.pill)),
                        child: Text(moneyK(debt!), style: T.small.copyWith(color: C.white, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: C.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.lime, width: 3),
                          boxShadow: const [BoxShadow(color: C.forest, spreadRadius: 3)],
                        ),
                      ),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _tick('Low', 'under ${moneyK(ModelFacts.q1)}', CrossAxisAlignment.start, placeholder),
          _tick('Typical', '${moneyK(ModelFacts.q1)}–${moneyK(ModelFacts.q3)}', CrossAxisAlignment.center, placeholder),
          _tick('High', 'over ${moneyK(ModelFacts.q3)}', CrossAxisAlignment.end, placeholder),
        ]),
      ]),
    );
  }

  Widget _tick(String a, String b, CrossAxisAlignment al, bool placeholder) => Expanded(
        child: Column(crossAxisAlignment: al, children: [
          Text(a, style: T.small.copyWith(fontSize: 13)),
          if (!placeholder) Text(b, style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w500)),
        ]),
      );
}

class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.size = 48, this.bg = C.softGreen, this.fg = C.forest});
  final IconData icon;
  final double size;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: size * .5),
      );
}

class InsightRow extends StatelessWidget {
  const InsightRow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        const IconCircle(Icons.lightbulb_outline_rounded, size: 40),
        const SizedBox(width: S.md),
        Expanded(child: Text(text, style: T.body)),
      ]);
}

class ErrorRow extends StatelessWidget {
  const ErrorRow(this.text, {super.key, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: C.errorTint,
          borderRadius: BorderRadius.circular(R.field),
          child: InkWell(
            borderRadius: BorderRadius.circular(R.field),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                const CircleAvatar(radius: 5, backgroundColor: C.error),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: T.label.copyWith(fontWeight: FontWeight.w400))),
                const Icon(Icons.chevron_right_rounded, color: C.ink),
              ]),
            ),
          ),
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile(this.value, this.label, {super.key});
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(R.row)),
          child: Column(children: [
            FittedBox(child: Text(value, style: T.section.copyWith(fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(height: 2),
            Text(label, style: T.small),
          ]),
        ),
      );
}
