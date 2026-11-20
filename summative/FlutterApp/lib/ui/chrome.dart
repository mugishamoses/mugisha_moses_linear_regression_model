import 'package:flutter/material.dart';

import '../logic/field_specs.dart';
import '../logic/form_controller.dart';
import '../logic/insight.dart';
import '../theme/tokens.dart';
import 'atoms.dart';
import 'molecules.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.inverted = false, this.size = 44});
  final bool inverted;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: inverted ? C.white : C.forest, borderRadius: BorderRadius.circular(size * .28)),
        child: Icon(Icons.school_outlined, color: inverted ? C.forest : C.white, size: size * .58),
      );
}

/// Green header with title (phone). The result card overlaps its bottom edge.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.onAbout, this.bottomSpace = 80});
  final VoidCallback onAbout;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: C.forest,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(R.header)),
        ),
        padding: EdgeInsets.fromLTRB(S.side, MediaQuery.paddingOf(context).top + S.lg, S.side, bottomSpace),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const LogoMark(inverted: true),
            const SizedBox(width: S.md),
            Expanded(child: Text('Graduate Debt', style: T.section.copyWith(color: C.white, fontSize: 18))),
            CircleIconButton(Icons.info_outline_rounded,
                onPressed: onAbout, tooltip: 'About this estimate', bg: C.white.withValues(alpha: .15), fg: C.white),
          ]),
          const SizedBox(height: S.xxl),
          Text('What will graduates owe?', style: T.hero),
          const SizedBox(height: 6),
          Text("Estimate a school's typical student debt in under a minute.",
              style: T.body.copyWith(color: C.white.withValues(alpha: .8))),
        ]),
      );
}

/// Slim bar that appears once the header scrolls away (designs S2/S3).
class CompactTopBar extends StatelessWidget {
  const CompactTopBar(this.form, {super.key, required this.onAbout});
  final FormController form;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final estimate = form.phase == Phase.result ? moneyK(form.debt!) : '—';
    return Container(
      padding: EdgeInsets.fromLTRB(S.side, MediaQuery.paddingOf(context).top + 8, S.side, 10),
      decoration: const BoxDecoration(
        color: C.cream,
        border: Border(bottom: BorderSide(color: C.divider)),
        boxShadow: [BoxShadow(color: Color(0x0F14201A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(children: [
        const LogoMark(size: 40),
        const SizedBox(width: S.md),
        Expanded(child: Text('Graduate Debt', style: T.section.copyWith(fontSize: 18))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: C.white, borderRadius: BorderRadius.circular(R.pill), border: Border.all(color: C.divider)),
          child: Text('Estimate: $estimate', style: T.label.copyWith(fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        CircleIconButton(Icons.info_outline_rounded, onPressed: onAbout, tooltip: 'About this estimate', bg: C.skeleton),
      ]),
    );
  }
}

class ExampleChipsRow extends StatelessWidget {
  const ExampleChipsRow(this.form, {super.key, this.onDark = false});
  final FormController form;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(onDark ? 'Try an example' : 'TRY AN EXAMPLE',
            style: onDark ? T.label.copyWith(color: C.white.withValues(alpha: .8)) : T.overline),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(children: [
            for (final (i, e) in examples.indexed) ...[
              PillChip(e.label,
                  key: Key('example$i'),
                  style: ChipStyle.example,
                  icon: Icons.auto_awesome_outlined,
                  selected: form.example == i,
                  onDark: onDark,
                  enabled: !form.busy,
                  onTap: () => form.applyExample(i)),
              const SizedBox(width: 10),
            ],
            TextButton(
              onPressed: form.busy ? null : form.clear,
              child: Text('Clear', style: T.label.copyWith(color: onDark ? C.white : C.forest, fontSize: 15)),
            ),
          ]),
        ),
      ]);
}

/// Sticky bottom action bar. The button reads exactly "Predict" until a result exists.
class PredictBar extends StatelessWidget {
  const PredictBar(this.form, {super.key, this.inline = false});
  final FormController form;
  final bool inline; // desktop: sits under the result card instead of the screen bottom

  @override
  Widget build(BuildContext context) {
    final hasResult = form.debt != null && form.phase == Phase.result;
    final label = form.busy
        ? 'Predicting…'
        : hasResult
            ? (form.stale ? 'Update estimate' : 'Predict again')
            : 'Predict';
    final errors = form.phase == Phase.inputError ? form.issues.length : 0;
    final caption = switch (form.phase) {
      Phase.loading => 'This usually takes a few seconds',
      Phase.inputError => 'Fix $errors input${errors == 1 ? '' : 's'} to continue',
      Phase.networkError => 'Inputs saved · tap Retry or Predict',
      Phase.result when form.stale => 'Inputs changed since last estimate',
      Phase.result => 'Edit any section to update the estimate',
      Phase.idle => form.readyCount == 0 ? '11 inputs · takes a few seconds' : '${form.readyCount} of 11 inputs ready',
    };
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        if (hasResult && !form.busy) ...[
          CircleIconButton(Icons.refresh_rounded,
              onPressed: form.clear, tooltip: 'Start over', size: 56, bg: C.white, fg: C.forest, outline: true),
          const SizedBox(width: S.md),
        ],
        Expanded(
          child: PrimaryButton(label,
              key: const Key('predict'),
              loading: form.busy,
              badge: form.stale,
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                FocusScope.of(context).unfocus();
                form.predict();
              }),
        ),
      ]),
      const SizedBox(height: 8),
      Text(caption,
          style: T.small.copyWith(fontSize: 13, color: errors > 0 ? C.error : C.muted, fontWeight: errors > 0 ? FontWeight.w600 : null)),
    ]);
    if (inline) return content;
    return Container(
      decoration: const BoxDecoration(color: C.cream, border: Border(top: BorderSide(color: C.divider))),
      padding: EdgeInsets.fromLTRB(S.side, S.md, S.side, MediaQuery.paddingOf(context).bottom + S.md),
      child: content,
    );
  }
}

// ---------------- sheets ----------------

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.icon, this.title, {this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: C.softGreen, shape: BoxShape.circle),
          child: Icon(icon, color: C.forest, size: 26),
        ),
        const SizedBox(width: S.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.title),
            if (subtitle != null) Text(subtitle!, style: T.small.copyWith(fontSize: 13)),
          ]),
        ),
        CircleIconButton(Icons.close_rounded, onPressed: () => Navigator.pop(context), tooltip: 'Close'),
      ]);
}

Future<void> showAboutSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      barrierColor: C.ink.withValues(alpha: .45),
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        maxChildSize: .92,
        builder: (c, scroll) => ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(S.side, 0, S.side, MediaQuery.paddingOf(c).bottom + S.xl),
          children: [
            const _SheetHeader(Icons.school_outlined, 'About this estimate'),
            const SizedBox(height: S.xl),
            const _AboutBlock(Icons.track_changes_rounded, 'What it predicts',
                "The median federal loan debt that students leave a school with, based on the school's profile."),
            const Divider(height: 32, color: C.dividerSoft),
            const _AboutBlock(Icons.storage_rounded, 'Where the data comes from',
                'U.S. Department of Education — College Scorecard. ${ModelFacts.institutions} U.S. institutions, 11 inputs.',
                link: 'collegescorecard.ed.gov'),
            const Divider(height: 32, color: C.dividerSoft),
            const _AboutBlock(Icons.bar_chart_rounded, 'How accurate it is', null),
            const SizedBox(height: S.md),
            const Row(children: [
              StatTile(ModelFacts.model, 'Model'),
              SizedBox(width: 8),
              StatTile(ModelFacts.rmse, 'Typical error'),
              SizedBox(width: 8),
              StatTile('4 models', 'Compared'),
            ]),
            const SizedBox(height: S.md),
            Text('We tested four models and kept the one with the lowest error on schools it had never seen.',
                style: T.body.copyWith(color: C.muted)),
            const Divider(height: 32, color: C.dividerSoft),
            const InlineBanner(
              kind: BannerKind.warning,
              icon: Icons.info_outline_rounded,
              title: 'Good to know',
              body: 'This is an estimate for comparing schools, not financial advice. Individual debt varies.',
            ),
            const SizedBox(height: S.xl),
            PrimaryButton('Got it', onPressed: () => Navigator.pop(c)),
          ],
        ),
      ),
    );

class _AboutBlock extends StatelessWidget {
  const _AboutBlock(this.icon, this.title, this.body, {this.link});
  final IconData icon;
  final String title;
  final String? body, link;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: C.forest, size: 28),
        const SizedBox(width: S.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.section.copyWith(fontSize: 17)),
            if (body != null) ...[const SizedBox(height: 4), Text(body!, style: T.body.copyWith(color: C.muted))],
            if (link != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.open_in_new_rounded, size: 18, color: C.forest),
                const SizedBox(width: 6),
                SelectableText(link!, style: T.label.copyWith(color: C.forest)),
              ]),
            ],
          ]),
        ),
      ]);
}

/// Region picker; returns the chosen code (design S9).
Future<int?> showRegionSheet(BuildContext context, int? current) => showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      barrierColor: C.ink.withValues(alpha: .45),
      builder: (c) => _RegionSheet(current),
    );

class _RegionSheet extends StatefulWidget {
  const _RegionSheet(this.current);
  final int? current;

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  late int? selected = widget.current;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final query = q.trim().toLowerCase();
    final shown = regions
        .where((r) => query.isEmpty || r.name.toLowerCase().contains(query) || r.states.toLowerCase().contains(query) ||
            _stateNames[r.code]!.contains(query))
        .toList();
    final sel = selected == null ? null : regions.firstWhere((r) => r.code == selected);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      maxChildSize: .94,
      builder: (c, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.side),
          child: Column(children: [
            const _SheetHeader(Icons.location_on_outlined, 'Choose a region',
                subtitle: 'Regions group U.S. states. Pick where the school is.'),
            const SizedBox(height: S.lg),
            TextField(
              onChanged: (v) => setState(() => q = v),
              style: T.value,
              decoration: InputDecoration(
                hintText: 'Search a state, e.g. Texas',
                prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
                fillColor: C.cream,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.pill), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(R.pill), borderSide: const BorderSide(color: C.forest, width: 1.5)),
              ),
            ),
            const SizedBox(height: S.md),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: S.side),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _RegionRow(shown[i], selected == shown[i].code, () => setState(() => selected = shown[i].code)),
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.dividerSoft))),
          padding: EdgeInsets.fromLTRB(S.side, S.md, S.side, MediaQuery.paddingOf(c).bottom + S.md),
          child: PrimaryButton(sel == null ? 'Choose a region' : 'Use region ${sel.code} · ${sel.name}',
              key: const Key('useRegion'), onPressed: sel == null ? null : () => Navigator.pop(c, sel.code)),
        ),
      ]),
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow(this.r, this.selected, this.onTap);
  final Region r;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? C.softGreen : C.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.row), side: BorderSide(color: selected ? C.softGreen : C.dividerSoft)),
          child: InkWell(
            key: Key('region${r.code}'),
            borderRadius: BorderRadius.circular(R.row),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: selected ? C.forest : C.cream, borderRadius: BorderRadius.circular(10)),
                  child: Text('${r.code}', style: T.section.copyWith(color: selected ? C.white : C.ink, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: S.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: T.section.copyWith(fontSize: 15)),
                    Text(r.states, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? C.forest : C.border, size: 24),
              ]),
            ),
          ),
        ),
      );
}

/// Full state names so "Texas" finds Southwest.
const _stateNames = {
  1: 'connecticut maine massachusetts new hampshire rhode island vermont',
  2: 'delaware district of columbia maryland new jersey new york pennsylvania',
  3: 'illinois indiana michigan ohio wisconsin',
  4: 'iowa kansas minnesota missouri nebraska north dakota south dakota',
  5: 'alabama arkansas florida georgia kentucky louisiana mississippi north carolina south carolina tennessee virginia west virginia',
  6: 'arizona new mexico oklahoma texas',
  7: 'colorado idaho montana utah wyoming',
  8: 'alaska california hawaii nevada oregon washington',
  9: 'puerto rico guam virgin islands american samoa marshall islands micronesia palau northern mariana',
};
