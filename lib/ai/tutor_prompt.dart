import '../l10n/app_language.dart';
import 'tutor_context.dart';

/// The one-tap requests offered under the tutor's input box.
enum TutorAction {
  explainSimply,
  stepByStep,
  examAnswer,
  example,
  quiz;

  /// The instruction sent to the tutor for this action about [subject].
  String instruction(String subject) => switch (this) {
        explainSimply => 'Explain "$subject" in simple language, as you would to a student meeting it for the first time.',
        stepByStep => 'Explain "$subject" step by step, one idea per numbered step.',
        examAnswer =>
          'How should I write an answer about "$subject" in the board exam? Show the key points, the equation or formula to include, '
              'and a model answer for a 3-mark question.',
        example => 'Give me one or two everyday examples of "$subject" and explain the chemistry behind each.',
        quiz => 'Quiz me on "$subject". Ask one question at a time and wait for my answer.',
      };
}

/// Builds the tutor's system prompt from what the student is studying.
abstract final class TutorPrompt {
  static String system(TutorContext c, AppLanguage language) {
    final level = c.classLevel == null ? 'school' : 'Class ${c.classLevel}';
    final facts = c.verifiedFacts.where((f) => f.trim().isNotEmpty).take(24).toList();
    return [
      'You are the AI Chemistry Tutor inside a chemistry learning app for Indian school students.',
      '',
      'The student is studying:',
      '- Board: ${c.boardName}, syllabus ${c.academicYear}, $level',
      if (c.chapter != null) '- ${c.chapter}',
      if (c.topic != null) '- Topic ${c.topic}',
      '- They opened the tutor from: ${c.subject}',
      if (facts.isNotEmpty) ...[
        '',
        "The app's notes for this, checked against the NCERT textbook, say:",
        for (final f in facts) '- $f',
      ],
      '',
      'How to answer:',
      '- Teach at the $level ${c.boardName} level and use NCERT terms and conventions.',
      "- Agree with the notes above. If your own knowledge seems to differ, follow the notes and tell the student the NCERT textbook is the final reference.",
      '- Write every chemical equation balanced, with physical states where NCERT shows them.',
      '- Never say that a question came in a past board paper and never state marks weightage; the app shows verified previous-year questions separately.',
      '- If you are not sure of something, say so instead of guessing.',
      '- Do not describe experiments to try at home with dangerous chemicals; practicals belong in the school lab under a teacher.',
      '- If the question is not about this subject, answer briefly if it is about science study, otherwise gently bring the student back to the topic.',
      '- ${_language(language)}',
      '- Format: plain text for a phone screen. Short paragraphs, numbered steps or "•" bullets. No Markdown symbols (#, **), no tables, no LaTeX; write formulas with Unicode subscripts such as H₂SO₄.',
      '- Keep answers focused: about 150–250 words unless the student asks for more.',
      '- In a quiz, ask one question at a time (an MCQ with four options or a short-answer question), wait for the answer, then say whether it is right and explain briefly before the next question.',
    ].join('\n');
  }

  static String _language(AppLanguage language) => switch (language) {
        AppLanguage.hi =>
          'Reply in Hindi (Devanagari script) using NCERT Hindi-medium terms; keep chemical formulas and equations in standard notation. '
              'If the student writes in English or Hinglish, reply in the same style.',
        AppLanguage.en => 'Reply in English. If the student writes in Hindi or Hinglish, reply in the same style.',
      };
}
