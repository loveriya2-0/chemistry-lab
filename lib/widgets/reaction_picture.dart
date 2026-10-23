import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';

/// One substance in an equation: "2H₂O(l)" → coefficient 2, H₂O, liquid.
@immutable
class EquationTerm {
  const EquationTerm({required this.formula, this.coefficient, this.state});

  final String formula;
  final int? coefficient;

  /// s, l, g or aq; null when the equation does not say.
  final String? state;

  /// "Heat", "energy" and similar written as a term.
  bool get isEnergy => const {'heat', 'energy', 'heat energy', 'light'}.contains(formula.toLowerCase());
}

/// A chemical equation split into what reacts and what forms, so it can be
/// drawn as a picture. Parsed from the display text in a note; anything
/// that is not a plain one-arrow equation is left as text.
@immutable
class ReactionEquation {
  const ReactionEquation({required this.reactants, required this.products, this.label, this.condition, this.reversible = false, this.note});

  final String? label;
  final List<EquationTerm> reactants;
  final List<EquationTerm> products;

  /// Written over the arrow: heat, catalyst, sunlight…
  final String? condition;
  final bool reversible;

  /// Text after a ";" such as "ΔH < 0".
  final String? note;

  static const _states = {'s', 'l', 'g', 'aq'};
  static final _termRe = RegExp(r'^(\d+)?(?=[A-Z(\[])(.+?)\s?(?:\((s|l|g|aq)\))?$');

  static ReactionEquation? tryParse(String text) {
    var s = text.trim();
    String? note;
    final semi = s.indexOf(';');
    if (semi > 0) {
      note = s.substring(semi + 1).trim();
      s = s.substring(0, semi).trim();
    }
    final arrows = RegExp('[→⇌]').allMatches(s).toList();
    if (arrows.length != 1) return null;
    String? label;
    final colon = s.indexOf(': ');
    if (colon > 0 && colon < arrows.single.start) {
      label = s.substring(0, colon).trim();
      s = s.substring(colon + 2);
    }
    final at = s.indexOf(RegExp('[→⇌]'));
    final reversible = s[at] == '⇌';
    final left = s.substring(0, at).trim();
    var right = s.substring(at + 1).trim();
    String? condition;
    // "→(heat) …": the condition written over the arrow.
    if (right.startsWith('(')) {
      final close = right.indexOf(')');
      if (close < 0) return null;
      condition = right.substring(1, close).trim();
      right = right.substring(close + 1).trim();
    }
    // "… (Fe, dark)" at the end: conditions written after the equation.
    final tail = RegExp(r'\s\(([^()]+)\)$').firstMatch(right);
    if (tail != null && !_states.contains(tail.group(1)!.trim())) {
      condition = [?condition, tail.group(1)!.trim()].join(', ');
      right = right.substring(0, tail.start).trim();
    }
    final reactants = _side(left);
    final products = _side(right);
    if (reactants == null || products == null) return null;
    return ReactionEquation(label: label, reactants: reactants, products: products, condition: condition, reversible: reversible, note: note);
  }

  static List<EquationTerm>? _side(String side) {
    if (side.isEmpty) return null;
    final terms = <EquationTerm>[];
    for (final raw in side.split(' + ')) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      final m = _termRe.firstMatch(t);
      if (m == null) {
        // Words such as "heat" or a name like "2,4,6-tribromophenol".
        terms.add(EquationTerm(formula: t));
      } else {
        terms.add(EquationTerm(formula: m.group(2)!.trim(), coefficient: int.tryParse(m.group(1) ?? ''), state: m.group(3)));
      }
    }
    return terms;
  }
}

/// [equation] drawn as reactant cards → product cards, with the number of
/// each unit and its state (solid, liquid, gas, in water).
class ReactionPicture extends StatelessWidget {
  const ReactionPicture({super.key, required this.equation});

  final ReactionEquation equation;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final (i, t) in equation.reactants.indexed) ...[if (i > 0) const _Plus(), _TermCard(term: t, product: false)],
      _Arrow(condition: equation.condition, reversible: equation.reversible),
      for (final (i, t) in equation.products.indexed) ...[if (i > 0) const _Plus(), _TermCard(term: t, product: true)],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (equation.label case final l?) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LabColors.muted))),
        Wrap(spacing: 4, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children),
        if (equation.note case final n?) Padding(padding: const EdgeInsets.only(top: 6), child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LabColors.secondary))),
      ],
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term, required this.product});

  final EquationTerm term;
  final bool product;

  static IconData _icon(String state) => switch (state) {
        's' => Icons.square_rounded,
        'l' => Icons.water_drop_rounded,
        'g' => Icons.bubble_chart_rounded,
        _ => Icons.science_rounded,
      };

  @override
  Widget build(BuildContext context) {
    if (term.isEnergy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFEA580C)),
          const SizedBox(width: 3),
          Text(term.formula, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEA580C))),
        ]),
      );
    }
    final color = product ? LabColors.teal : LabColors.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (term.coefficient case final n?) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Text('$n×', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(child: Text(term.formula, style: TextStyle(fontWeight: FontWeight.w800, color: color))),
            ],
          ),
          if (term.state case final st?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_icon(st), size: 11, color: LabColors.muted),
                const SizedBox(width: 2),
                Text(context.strings.stateSymbolName(st), style: const TextStyle(fontSize: 10.5, color: LabColors.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Plus extends StatelessWidget {
  const _Plus();

  @override
  Widget build(BuildContext context) => const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LabColors.muted));
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.condition, required this.reversible});

  final String? condition;
  final bool reversible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (condition case final c?)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(c, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: LabColors.amber)),
            ),
          Icon(reversible ? Icons.sync_alt_rounded : Icons.arrow_forward_rounded, color: LabColors.ink, size: 22),
        ],
      ),
    );
  }
}
