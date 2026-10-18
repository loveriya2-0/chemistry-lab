import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/board.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../state/app_state.dart';
import '../widgets/language_toggle.dart';

/// Pick an exam board. Boards without verified data are listed as
/// "Coming soon" and cannot be opened, so no content is ever shown for them.
class BoardSelectionScreen extends StatelessWidget {
  const BoardSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final registry = context.read<ContentCatalog>().registry;
    final current = context.watch<AppState>().boardId;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: canPop,
        title: canPop ? Text(s.changeBoard) : null,
        actions: const [LanguageToggle()],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              s.chooseBoard,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: LabColors.ink, height: 1.15),
            ),
            const SizedBox(height: 6),
            Text(s.chooseBoardHint, style: const TextStyle(fontSize: 15, color: LabColors.muted, height: 1.4)),
            const SizedBox(height: 20),
            for (final board in registry.available) ...[
              _AvailableBoardCard(
                board: board,
                selected: board.id == current,
                onTap: () {
                  context.read<AppState>().selectBoard(board.id);
                  if (canPop) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            Text(
              s.moreBoards,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LabColors.ink),
            ),
            const SizedBox(height: 4),
            Text(s.comingSoonNote, style: const TextStyle(color: LabColors.muted, height: 1.4)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 3 : 2;
                final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final board in registry.comingSoon)
                      SizedBox(width: width, child: _ComingSoonTile(board: board)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableBoardCard extends StatelessWidget {
  const _AvailableBoardCard({required this.board, required this.selected, required this.onTap});

  final Board board;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final year = board.latestCurriculum?.academicYear;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? LabColors.primary : LabColors.primary.withValues(alpha: 0.25), width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LabColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: LabColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.ct(board.name),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LabColors.ink),
                      ),
                      if (board.officialName != null)
                        Text(s.ct(board.officialName!), style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Chip(label: s.available, color: LabColors.success),
                          if (year != null) _Chip(label: s.syllabusYear(year), color: LabColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: LabColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Semantics(
      enabled: false,
      label: '${s.ct(board.name)}, ${s.comingSoon}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LabColors.muted.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.ct(board.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF363E5E)),
            ),
            const SizedBox(height: 6),
            _Chip(label: s.comingSoon, color: LabColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
