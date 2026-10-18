import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/tutor_context.dart';
import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../screens/ai_tutor_screen.dart';
import '../state/app_state.dart';

/// The selected board's display name ("CBSE"), for the tutor's context.
String currentBoardName(BuildContext context) {
  final id = context.read<AppState>().boardId!;
  return context.read<ContentCatalog>().registry.byId(id)?.name.en ?? id;
}

void openAiTutor(BuildContext context, TutorContext Function() build) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiTutorScreen(tutorContext: build())));

/// App-bar "Ask AI" button.
class AskAiAction extends StatelessWidget {
  const AskAiAction({super.key, required this.tutorContext});

  final TutorContext Function() tutorContext;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: context.strings.askAi,
        onPressed: () => openAiTutor(context, tutorContext),
        icon: const Icon(Icons.smart_toy_outlined),
      );
}

/// "🤖 Ask AI about this" card placed after the verified content.
class AskAiCard extends StatelessWidget {
  const AskAiCard({super.key, required this.tutorContext});

  final TutorContext Function() tutorContext;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: aiColor.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(s.askAiAboutThis, style: const TextStyle(fontWeight: FontWeight.w800, color: aiColor)),
        subtitle: Text(s.askAiHint, style: const TextStyle(color: LabColors.muted)),
        trailing: const Icon(Icons.chevron_right_rounded, color: aiColor),
        onTap: () => openAiTutor(context, tutorContext),
      ),
    );
  }
}
