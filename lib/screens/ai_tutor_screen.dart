import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/tutor_context.dart';
import '../ai/tutor_prompt.dart';
import '../ai/tutor_service.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../state/language_controller.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';

/// AI answers are drawn in this colour so they never look like the
/// verified notes (indigo) or PYQs.
const aiColor = Color(0xFF7C3AED);

/// Chat with the AI tutor about one topic, chapter, concept or reaction.
///
/// Every answer is labelled "AI Explanation" and kept on this screen; it is
/// never mixed into the verified notes or PYQs, and nothing is saved.
class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key, required this.tutorContext});

  final TutorContext tutorContext;

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _Entry {
  _Entry.student(this.shown, this.sent) : role = TutorRole.student, truncated = false;
  _Entry.tutor(this.shown, {this.truncated = false}) : role = TutorRole.tutor, sent = shown;

  final TutorRole role;

  /// What the student sees (an action's label, or their own question).
  final String shown;

  /// What the tutor receives.
  final String sent;
  final bool truncated;
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _entries = <_Entry>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  TutorFailure? _failure;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String shown, String sent) async {
    if (_busy || sent.trim().isEmpty) return;
    setState(() {
      _entries.add(_Entry.student(shown.trim(), sent.trim()));
      _input.clear();
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    _scrollToEnd();
    final tutor = context.read<TutorService>();
    final language = context.read<LanguageController>().language;
    try {
      final reply = await tutor.reply(
        context: widget.tutorContext,
        language: language,
        conversation: [for (final e in _entries) TutorMessage(e.role, e.sent)],
      );
      if (!mounted) return;
      setState(() => _entries.add(_Entry.tutor(reply.text, truncated: reply.truncated)));
    } on TutorException catch (e) {
      if (!mounted) return;
      setState(() => _failure = e.failure);
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final configured = context.read<TutorService>().isConfigured;
    final subject = widget.tutorContext.subject;
    return Scaffold(
      appBar: AppBar(title: Text(s.aiTutorTitle), actions: const [LanguageToggle()]),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _ContextHeader(tutorContext: widget.tutorContext),
                const SizedBox(height: 12),
                if (!configured)
                  ComingSoonPanel(icon: Icons.smart_toy_outlined, title: s.aiNotConfiguredTitle, body: s.aiNotConfiguredBody)
                else ...[
                  if (_entries.isEmpty) _Hint(text: s.askAiHint),
                  for (final e in _entries)
                    e.role == TutorRole.student ? _StudentBubble(text: e.shown) : AiAnswerCard(text: e.shown, truncated: e.truncated),
                  if (_busy) const _Thinking(),
                  if (_failure case final f?) _FailureCard(failure: f, onRetry: _busy ? null : _fetch),
                ],
              ],
            ),
          ),
          if (configured)
            SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final a in TutorAction.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(s.aiActionLabel(a)),
                                  onPressed: _busy ? null : () => _ask(s.aiActionLabel(a), a.instruction(subject)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (t) => _ask(t, t),
                              decoration: InputDecoration(
                                hintText: s.aiInputHint,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: s.aiSend,
                            onPressed: _busy ? null : () => _ask(_input.text, _input.text),
                            icon: const Icon(Icons.send_rounded, color: aiColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextHeader extends StatelessWidget {
  const _ContextHeader({required this.tutorContext});

  final TutorContext tutorContext;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final crumb = tutorContext.breadcrumb(s.className);
    return HeroPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tutorContext.boardName} · ${tutorContext.academicYear}'.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          if (crumb.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(crumb, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.35)),
          ],
          const SizedBox(height: 6),
          Text(tutorContext.subject, style: const TextStyle(color: Colors.white70, height: 1.35)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(color: LabColors.muted, height: 1.4)),
      );
}

class _StudentBubble extends StatelessWidget {
  const _StudentBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: LabColors.primarySoft, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(context.strings.aiYou, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LabColors.muted)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(height: 1.4, color: LabColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// One tutor answer, always labelled as AI-written.
class AiAnswerCard extends StatelessWidget {
  const AiAnswerCard({super.key, required this.text, this.truncated = false});

  final String text;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10, right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: aiColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: aiColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: aiColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
            child: Text(s.aiExplanationLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: aiColor)),
          ),
          const SizedBox(height: 8),
          SelectableText(text, style: const TextStyle(height: 1.5, color: LabColors.ink)),
          if (truncated) ...[
            const SizedBox(height: 4),
            Text(s.aiTruncated, style: const TextStyle(fontStyle: FontStyle.italic, color: LabColors.muted)),
          ],
          const Divider(height: 18),
          Text(s.aiDisclaimer, style: const TextStyle(fontSize: 11.5, color: LabColors.muted, height: 1.4)),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: aiColor)),
            const SizedBox(width: 10),
            Expanded(child: Text(context.strings.aiThinking, style: const TextStyle(color: aiColor, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure, required this.onRetry});

  final TutorFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Card(
      color: LabColors.danger.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.aiFailure(failure), style: const TextStyle(color: LabColors.danger, height: 1.4, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(s.aiRetry)),
          ],
        ),
      ),
    );
  }
}
