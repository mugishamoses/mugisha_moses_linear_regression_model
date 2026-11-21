import 'package:flutter/material.dart';

import '../logic/field_specs.dart';
import '../logic/form_controller.dart';
import '../theme/tokens.dart';
import 'atoms.dart';
import 'molecules.dart';

/// Collapsible group of 2–3 fields (designs S0, S2, S3, S5, S6).
class SectionCard extends StatelessWidget {
  const SectionCard(this.form, this.index, {super.key, required this.onRegionTap, this.wide = false});
  final FormController form;
  final int index;
  final VoidCallback onRegionTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final state = form.sectionState(index);
    final open = form.open.contains(index);
    final fs = fieldsOf(index);
    final done = form.sectionDone(index);
    final issues = fs.where((f) => form.errorFor(f.key) != null).length;
    final complete = state == SectionState.complete;

    final badgeTone = switch (state) {
      SectionState.error => Tone.error,
      SectionState.notStarted when !open => Tone.outline,
      _ => Tone.forest,
    };
    final Widget status = switch (state) {
      SectionState.error => StatusPill('$issues issue${issues == 1 ? '' : 's'}', kind: PillKind.error, icon: Icons.error_rounded),
      SectionState.complete => StatusPill(wide ? '$done/${fs.length}' : '', icon: Icons.check_rounded),
      SectionState.inProgress => Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$done/${fs.length}', style: T.small.copyWith(fontSize: 14)),
          const SizedBox(width: 8),
          ProgressRing(done / fs.length),
        ]),
      SectionState.notStarted => Text('0/${fs.length}', style: T.small.copyWith(fontSize: 14)),
    };

    final header = InkWell(
      onTap: () => form.toggle(index),
      borderRadius: BorderRadius.circular(R.card),
      child: Padding(
        padding: EdgeInsets.fromLTRB(S.lg, S.lg, S.md, open ? S.sm : S.lg),
        child: Row(children: [
          NumberBadge(index + 1, tone: badgeTone),
          const SizedBox(width: S.lg),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sectionTitles[index], style: T.section),
              if (!open && state != SectionState.notStarted) ...[
                const SizedBox(height: 2),
                Text(form.summary(index), style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: FittedBox(fit: BoxFit.scaleDown, child: status)),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: open ? .5 : 0,
            duration: motion(context, D.fast),
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: C.ink),
          ),
        ]),
      ),
    );

    Widget fieldWidget(FieldSpec f) => f.kind == Kind.code
        ? CodeField(form, f, onRegionTap: onRegionTap)
        : LabeledField(form, f, compact: wide && index == 2);

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(S.lg, 0, S.lg, S.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (index == 2)
          Padding(
            padding: const EdgeInsets.only(bottom: S.md),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: C.forest),
              const SizedBox(width: 8),
              Expanded(child: Text('Enter percentages from 0 to 100', style: T.small.copyWith(fontSize: 13))),
            ]),
          ),
        if (wide && index == 2)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, f) in fs.indexed) ...[
              if (i > 0) const SizedBox(width: S.lg),
              Expanded(child: fieldWidget(f)),
            ],
          ])
        else
          for (final (i, f) in fs.indexed) ...[
            if (i > 0) const SizedBox(height: S.lg),
            fieldWidget(f),
          ],
      ]),
    );

    final accent = state == SectionState.error ? C.error : (open ? C.forest : null);
    return Semantics(
      label: 'Section ${index + 1}: ${sectionTitles[index]}',
      expanded: open,
      child: CardBox(
        padding: EdgeInsets.zero,
        radius: wide ? R.cardWide : R.card,
        color: complete && !open ? C.softGreen.withValues(alpha: .55) : C.white,
        accent: accent,
        child: AnimatedSize(
          duration: motion(context, D.fast),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(children: [header, if (open) body]),
        ),
      ),
    );
  }
}
