import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/form_controller.dart';
import '../theme/tokens.dart';
import 'atoms.dart';
import 'chrome.dart';
import 'molecules.dart';
import 'result_card.dart';
import 'section_card.dart';

/// The app's single page. Phone: one column (S1–S7). Browser ≥ 900 px: two columns (S10).
class PredictPage extends StatefulWidget {
  const PredictPage({super.key, this.form});
  final FormController? form; // injectable for tests

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  late final form = widget.form ?? FormController();
  final scroll = ScrollController();
  final compact = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    scroll.addListener(() => compact.value = scroll.offset > 190);
    form.addListener(_onPhase);
  }

  Phase? _phase;
  void _onPhase() {
    final p = form.phase;
    if (p != _phase && p != Phase.loading && p != Phase.idle && scroll.hasClients) {
      scroll.animateTo(0, duration: motion(context, D.medium), curve: Curves.easeOutCubic);
    }
    _phase = p;
  }

  @override
  void dispose() {
    form.removeListener(_onPhase);
    if (widget.form == null) form.dispose();
    scroll.dispose();
    compact.dispose();
    super.dispose();
  }

  void about() => showAboutSheet(context);

  Future<void> pickRegion() async {
    final current = form.isValid('REGION') ? form.parse('REGION')!.round() : null;
    final code = await showRegionSheet(context, current);
    if (code != null) form.setCode('REGION', code);
  }

  List<Widget> sections({bool wide = false}) => [
        for (var i = 0; i < 4; i++) ...[
          SectionCard(form, i, onRegionTap: pickRegion, wide: wide),
          const SizedBox(height: S.md),
        ],
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: form,
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) => box.maxWidth >= D.wide ? _wide() : _phone(),
        ),
      );

  Widget _phone() => Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          SingleChildScrollView(
            controller: scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppHeader(onAbout: about, bottomSpace: 96),
              // content is lifted so the result card overlaps the header (leaves 72 px spare at the end)
              Transform.translate(
                offset: const Offset(0, -72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.side),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ResultCard(form, onAbout: about),
                    const SizedBox(height: S.xxl),
                    ExampleChipsRow(form),
                    const SizedBox(height: S.xxl),
                    ProgressRow(form),
                    const SizedBox(height: S.lg),
                    ...sections(),
                  ]),
                ),
              ),
            ]),
          ),
          ValueListenableBuilder(
            valueListenable: compact,
            builder: (_, show, _) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: show ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
              child: AnimatedSlide(
                offset: show ? Offset.zero : const Offset(0, -1),
                duration: motion(context, D.fast),
                child: CompactTopBar(form, onAbout: about),
              ),
            ),
          ),
        ]),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: PredictBar(form),
        ),
      );

  Widget _wide() => Scaffold(
        body: Column(children: [
          // top nav
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: S.xxxl + 16),
            decoration: const BoxDecoration(color: C.cream, border: Border(bottom: BorderSide(color: C.divider))),
            child: Row(children: [
              const LogoMark(),
              const SizedBox(width: S.md),
              Text('Graduate Debt', style: T.title.copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: about, child: Text('How it works', style: T.label.copyWith(color: C.muted, fontSize: 15))),
              const SizedBox(width: 8),
              CircleIconButton(Icons.info_outline_rounded, onPressed: about, tooltip: 'About this estimate', bg: C.white, outline: true),
            ]),
          ),
          // hero band
          Container(
            width: double.infinity,
            color: C.forest,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: S.xxxl + 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SizedBox(width: double.infinity, child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: S.xl,
                  spacing: S.xxxl,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('What will graduates owe?', style: T.hero.copyWith(fontSize: 40)),
                      const SizedBox(height: 8),
                      Text("Estimate a school's typical student debt in under a minute.",
                          style: T.body.copyWith(color: C.white.withValues(alpha: .8), fontSize: 17)),
                    ]),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: ExampleChipsRow(form, onDark: true)),
                  ],
                )),
              ),
            ),
          ),
          // two columns: sticky result on the left, scrolling form on the right
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200 + 2 * S.xxxl),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 460 + S.xxxl,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(S.xxxl, S.xxxl, 0, S.xxxl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        ResultCard(form, onAbout: about, wide: true),
                        const SizedBox(height: S.xxl),
                        PredictBar(form, inline: true),
                      ]),
                    ),
                  ),
                  const SizedBox(width: S.xxxl + 8),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, S.xxxl, S.xxxl, S.xxxl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        ProgressRow(form, large: true),
                        const SizedBox(height: S.lg),
                        ...sections(wide: true),
                        const SizedBox(height: S.xl),
                        Text('Data: U.S. Department of Education — College Scorecard · Estimates, not financial advice',
                            style: T.small, textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      );
}
