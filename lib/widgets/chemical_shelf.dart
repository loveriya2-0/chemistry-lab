import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/chemical.dart';
import 'chemical_bottle.dart';

/// Wooden shelf at the bottom of the lab screen. Bottles are laid out in
/// rows of [perRow] so every bottle is visible without scrolling (which would
/// otherwise compete with the drag gesture). By default a row holds as many
/// bottles as fit the width, so the shelf uses as few rows as possible and
/// leaves room for the beaker on small phones.
class ChemicalShelf extends StatelessWidget {
  const ChemicalShelf({
    super.key,
    required this.chemicals,
    this.onChemicalTap,
    this.perRow,
  });

  final List<Chemical> chemicals;
  final ValueChanged<Chemical>? onChemicalTap;
  /// Bottles per row; null fits as many as the width allows (3–6).
  final int? perRow;

  @override
  Widget build(BuildContext context) {
    // 12 px padding on each side of the shelf.
    final fit = ((MediaQuery.sizeOf(context).width - 24) / ChemicalBottle.width).floor().clamp(3, 6);
    final n = perRow ?? fit;
    final rows = <List<Chemical>>[
      for (var i = 0; i < chemicals.length; i += n)
        chemicals.sublist(i, (i + n).clamp(0, chemicals.length)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.strings.shelfHint,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: LabColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            for (final row in rows) _ShelfRow(row: row, onTap: onChemicalTap),
          ],
        ),
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.row, this.onTap});

  final List<Chemical> row;
  final ValueChanged<Chemical>? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final chemical in row)
              ChemicalBottle(
                chemical: chemical,
                onTap: onTap == null ? null : () => onTap!(chemical),
              ),
          ],
        ),
        // Wooden plank.
        Container(
          height: 10,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [LabColors.bench, LabColors.benchDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
