import 'package:flutter/material.dart';

import '../theme/tokens.dart';

bool reduceMotion(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;
Duration motion(BuildContext c, Duration d) => reduceMotion(c) ? Duration.zero : d;

enum Tone { forest, error, outline, muted }

/// Numbered circle used by section cards.
class NumberBadge extends StatelessWidget {
  const NumberBadge(this.n, {super.key, this.tone = Tone.forest, this.size = 32});
  final int n;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      Tone.forest => (C.forest, C.white, C.forest),
      Tone.error => (C.error, C.white, C.error),
      Tone.outline || Tone.muted => (C.white, C.forest, C.forest),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: border, width: 1.5)),
      child: Text('$n', style: T.label.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

enum PillKind { success, error, warning, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.kind = PillKind.success, this.icon, this.large = false});
  final String text;
  final PillKind kind;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.success => (C.softGreen, C.forest),
      PillKind.error => (C.errorTint, C.error),
      PillKind.warning => (C.warningTint, C.warningText),
      PillKind.neutral => (C.cream, C.muted),
    };
    final style = (large ? T.label.copyWith(fontSize: 15) : T.small).copyWith(color: fg, fontWeight: FontWeight.w600);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 7 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(R.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: large ? 18 : 14, color: fg), const SizedBox(width: 4)],
        Text(text, style: style),
      ]),
    );
  }
}

enum DotState { done, current, empty, error }

class ProgressDot extends StatelessWidget {
  const ProgressDot(this.state, {super.key});
  final DotState state;

  @override
  Widget build(BuildContext context) {
    final (fill, border) = switch (state) {
      DotState.done => (C.forest, C.forest),
      DotState.current => (C.lime, C.lime),
      DotState.empty => (Colors.transparent, C.muted),
      DotState.error => (C.errorTint, C.error),
    };
    return AnimatedContainer(
      duration: motion(context, D.fast),
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: border, width: 1.5)),
    );
  }
}

/// Thin bar under percentage fields.
class MiniBar extends StatelessWidget {
  const MiniBar(this.value, {super.key, this.error = false});
  final double value; // 0..1 (anything above 1 is shown full red)
  final bool error;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(R.pill),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: error ? 1 : value.clamp(0, 1)),
          duration: motion(context, D.fast),
          builder: (_, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 5,
            backgroundColor: C.dividerSoft,
            color: error ? C.error : C.forest,
          ),
        ),
      );
}

class ProgressRing extends StatelessWidget {
  const ProgressRing(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(value: value, strokeWidth: 3, backgroundColor: C.dividerSoft, color: C.forest),
      );
}

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.color = C.forest, this.size = 18});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color, backgroundColor: C.lime.withValues(alpha: .35)),
      );
}

/// Full-width pill button. [loading] shows a spinner and disables taps.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.loading = false, this.icon, this.badge = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading, badge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: AnimatedOpacity(
          opacity: loading ? .65 : 1,
          duration: motion(context, D.fast),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: loading ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: C.forest,
                disabledBackgroundColor: C.forest,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Stack(alignment: Alignment.center, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (loading) ...[const Spinner(color: C.white), const SizedBox(width: 12)],
                  Flexible(child: Text(label, style: T.button, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (!loading && icon != null) ...[const SizedBox(width: 8), Icon(icon, color: C.white, size: 20)],
                ]),
                if (badge)
                  const Positioned(right: 4, child: CircleAvatar(radius: 6, backgroundColor: C.lime)),
              ]),
            ),
          ),
        ),
      );
}

class OutlinePillButton extends StatelessWidget {
  const OutlinePillButton(this.label, {super.key, required this.onPressed, this.icon});
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon == null ? null : Icon(icon, size: 20, color: C.forest),
          label: Text(label, style: T.button.copyWith(color: C.forest, fontSize: 15)),
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: const BorderSide(color: C.forest, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 28),
          ),
        ),
      );
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton(this.icon,
      {super.key, required this.onPressed, required this.tooltip, this.size = 40, this.bg = C.cream, this.fg = C.ink, this.outline = false});
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double size;
  final Color bg, fg;
  final bool outline;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          shape: CircleBorder(side: outline ? const BorderSide(color: C.forest, width: 1.5) : BorderSide.none),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: size, height: size, child: Icon(icon, color: fg, size: size * .48)),
          ),
        ),
      );
}

enum ChipStyle { example, code }

class PillChip extends StatelessWidget {
  const PillChip(this.label,
      {super.key, required this.onTap, this.selected = false, this.style = ChipStyle.code, this.icon, this.enabled = true, this.onDark = false});
  final String label;
  final VoidCallback onTap;
  final bool selected, enabled, onDark;
  final ChipStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final example = style == ChipStyle.example;
    final bg = selected ? (onDark ? C.white : C.forest) : (example ? C.softGreen : C.white);
    final fg = selected ? (onDark ? C.forest : C.white) : (example ? C.forest : C.ink);
    final shownIcon = selected ? Icons.check_circle_rounded : icon;
    return Opacity(
      opacity: enabled ? 1 : .6,
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: bg,
          shape: StadiumBorder(side: BorderSide(color: selected || example ? bg : C.forest.withValues(alpha: .35))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled ? onTap : null,
            child: AnimatedPadding(
              duration: motion(context, D.fast),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (shownIcon != null) ...[Icon(shownIcon, size: 18, color: fg), const SizedBox(width: 6)],
                Text(label, style: T.label.copyWith(color: fg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.width, required this.height, this.radius = 10});
  final double width, height, radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * _c.value - 1, -.3),
              end: Alignment(3 * _c.value - 1, .3),
              colors: const [C.skeleton, Color(0xFFF5F3EE), C.skeleton],
            ),
          ),
        ),
      );
}

enum BannerKind { info, warning, error }

class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key, required this.kind, required this.title, this.body, this.icon});
  final BannerKind kind;
  final String title;
  final String? body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, ic) = switch (kind) {
      BannerKind.info => (C.softGreen, C.forest, Icons.hourglass_bottom_rounded),
      BannerKind.warning => (C.warningTint, C.warning, Icons.sync_problem_rounded),
      BannerKind.error => (C.errorTint, C.error, Icons.error_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(S.md),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(R.row)),
        child: Row(children: [
          Icon(icon ?? ic, color: fg, size: 22),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.label.copyWith(fontWeight: FontWeight.w600)),
              if (body != null) Text(body!, style: T.small),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// White rounded card; [shadow] only for the result card.
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(S.xl), this.shadow = false, this.color = C.white, this.accent, this.radius = R.card});
  final Widget child;
  final EdgeInsets padding;
  final bool shadow;
  final Color color;
  final Color? accent; // coloured left bar
  final double radius;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: motion(context, D.fast),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow ? cardShadow : null,
          border: Border.all(color: color == C.white ? C.dividerSoft : Colors.transparent),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(border: accent == null ? null : Border(left: BorderSide(color: accent!, width: 4))),
          padding: padding,
          child: child,
        ),
      );
}
