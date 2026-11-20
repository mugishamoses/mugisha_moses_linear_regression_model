import 'package:flutter/material.dart';

import '../logic/field_specs.dart';
import '../logic/form_controller.dart';
import '../logic/insight.dart';
import '../theme/tokens.dart';
import 'atoms.dart';
import 'molecules.dart';

/// The single results area: intro, loading, result, input errors, network error, stale (designs S1, S4–S7).
/// Every prediction and every error message is shown here.
class ResultCard extends StatelessWidget {
  const ResultCard(this.form, {super.key, required this.onAbout, this.wide = false});
  final FormController form;
  final VoidCallback onAbout;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final (child, accent, tag) = switch (form.phase) {
      Phase.idle => (_intro(), null, 'intro'),
      Phase.loading => (_loading(), null, 'loading'),
      Phase.result => (_result(context), null, 'result'),
      Phase.inputError => (_inputError(), C.error, 'error'),
      Phase.networkError => (_network(), null, 'network'),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: CardBox(
        key: const Key('result'),
        shadow: true,
        accent: accent,
        radius: wide ? R.cardWide : R.card,
        padding: EdgeInsets.all(wide ? 28 : S.xl),
        child: AnimatedSize(
          duration: motion(context, D.medium),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: motion(context, D.fast),
            child: KeyedSubtree(key: ValueKey(tag + (form.stale ? 's' : '')), child: child),
          ),
        ),
      ),
    );
  }

  Widget _intro() => Column(children: [
        const Row(children: [
          IconCircle(Icons.school_outlined, size: 56),
          SizedBox(width: S.lg),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your estimate will appear here', style: T.section),
              SizedBox(height: 4),
              Text('Fill the 4 short sections, or tap an example to start.', style: T.small),
            ]),
          ),
        ]),
        const SizedBox(height: S.xl),
        const ComparisonBar(),
      ]);

  Widget _loading() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Median graduate debt', style: T.section)),
          const Spinner(),
          const SizedBox(width: 8),
          Text('Calculating…', style: T.small),
        ]),
        const SizedBox(height: S.lg),
        const Row(children: [
          Skeleton(width: 170, height: 48),
          SizedBox(width: S.md),
          Skeleton(width: 90, height: 30, radius: 99),
        ]),
        const SizedBox(height: S.xl),
        const ComparisonBar(),
        const SizedBox(height: S.lg),
        const Skeleton(width: double.infinity, height: 12),
        const SizedBox(height: 8),
        const FractionallySizedBox(widthFactor: .7, child: Skeleton(width: double.infinity, height: 12)),
        const SizedBox(height: S.lg),
        InlineBanner(
          kind: BannerKind.info,
          title: 'Contacting server…',
          body: form.waking ? 'Waking up the free server — this can take up to a minute.' : 'This usually takes a few seconds.',
        ),
      ]);

  Widget _result(BuildContext context) {
    final debt = form.debt!;
    final band = bandOf(debt);
    final stale = form.stale;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (stale) ...[
        const InlineBanner(kind: BannerKind.warning, title: 'Inputs changed — press Predict to update'),
        const SizedBox(height: S.lg),
      ],
      Opacity(
        opacity: stale ? .45 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Median graduate debt', style: T.section.copyWith(color: stale ? C.muted : C.ink))),
            if (!stale) ...[
              const Icon(Icons.schedule_rounded, size: 16, color: C.muted),
              const SizedBox(width: 4),
              Text('Updated just now', style: T.small),
            ],
          ]),
          const SizedBox(height: S.sm),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: S.md, runSpacing: 6, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: stale ? debt : 0, end: debt),
              duration: motion(context, D.slow),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(money(v),
                  key: const Key('debt'), style: T.result.copyWith(fontSize: wide ? 56 : 44), semanticsLabel: 'Predicted ${money(debt)}'),
            ),
            StatusPill(bandLabel(band),
                large: true,
                kind: band == Band.high ? PillKind.warning : PillKind.success,
                icon: switch (band) {
                  Band.high => Icons.north_east_rounded,
                  Band.low => Icons.south_east_rounded,
                  Band.typical => Icons.check_rounded,
                }),
          ]),
          const SizedBox(height: S.lg),
          ComparisonBar(debt: debt),
          const Divider(height: 32, color: C.dividerSoft),
          InsightRow(insightFor(form.lastInputs)),
          const Divider(height: 32, color: C.dividerSoft),
        ]),
      ),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: [
        Text('${ModelFacts.rmse} typical error · College Scorecard data', style: T.small),
        InkWell(
          onTap: onAbout,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('How is this calculated?', style: T.small.copyWith(color: C.forest, fontWeight: FontWeight.w600)),
              const Icon(Icons.chevron_right_rounded, color: C.forest, size: 18),
            ]),
          ),
        ),
      ]),
    ]);
  }

  Widget _inputError() {
    final n = form.issues.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const IconCircle(Icons.warning_amber_rounded, size: 52, bg: C.errorTint, fg: C.error),
        const SizedBox(width: S.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n field${n == 1 ? '' : 's'} need${n == 1 ? 's' : ''} attention', style: T.section.copyWith(fontSize: 18)),
            Text('Fix ${n == 1 ? 'it' : 'them'} to get your estimate.', style: T.small.copyWith(fontSize: 13)),
          ]),
        ),
      ]),
      const SizedBox(height: 6),
      for (final i in form.issues.take(4))
        ErrorRow('${spec(i.key).label} — ${i.message.toLowerCase()}', onTap: () => form.jumpTo(i.key)),
      if (n > 4) Padding(padding: const EdgeInsets.only(top: 8), child: Text('+ ${n - 4} more', style: T.small)),
      const SizedBox(height: S.md),
      Text('Tap an item to jump to it', style: T.small),
    ]);
  }

  Widget _network() => Column(children: [
        const IconCircle(Icons.wifi_off_rounded, size: 64, bg: C.errorTint, fg: C.error),
        const SizedBox(height: S.lg),
        Text("Couldn't reach the server", style: T.section.copyWith(fontSize: 18), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Check your internet connection and try again. Your inputs are saved.',
            style: T.body.copyWith(color: C.muted), textAlign: TextAlign.center),
        const SizedBox(height: S.lg),
        OutlinePillButton('Retry', icon: Icons.refresh_rounded, onPressed: form.predict),
        const SizedBox(height: S.md),
        Text(form.networkDetail, style: T.small),
      ]);
}
