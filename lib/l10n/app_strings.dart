import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../ai/tutor_prompt.dart';
import '../ai/tutor_service.dart';
import '../content/content_text.dart';
import '../content/models/chemical_entry.dart';
import '../content/models/practice_question.dart';
import '../content/models/pyq.dart';
import '../models/chemical.dart';
import '../state/language_controller.dart';
import 'app_language.dart';
import 'localized_text.dart';

/// All fixed UI text. Each language is a subclass, so a string missing from
/// any language is a compile error.
///
/// In `build` use `context.strings`; in callbacks use `context.readStrings`.
abstract class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  static AppStrings of(AppLanguage language) => switch (language) {
        AppLanguage.en => const EnStrings(),
        AppLanguage.hi => const HiStrings(),
      };

  /// Resolves curriculum content to the current language.
  String tr(LocalizedText text) => text.of(language);

  /// Resolves syllabus content loaded from files (Hindi falls back to English).
  String ct(ContentText text) => text.of(language);

  /// "Hydrochloric Acid (HCl)" – used in instructions and warnings.
  String chemical(Chemical c) => c.displayName(language);

  // App / class selection
  String get appName;
  String get homeTitle;
  String get homeTagline;
  String className(int classLevel);
  String get changeLanguage;

  // Chapters / topics / practicals
  String classChapters(int classLevel);
  String chapterOverline(int number);
  String chapterTopics(int number);
  String topicOverline(String number);
  String topicCount(int n);
  String practicalCount(int n);
  String stepCount(int n);
  String chemicalCount(int n);
  String get start;
  String get noChapters;
  String get noTopics;
  String get noPracticals;

  // Boards & syllabus
  String get chooseBoard;
  String get chooseBoardHint;
  String get available;
  String get comingSoon;
  String get moreBoards;
  String get comingSoonNote;
  String syllabusYear(String year);
  String get changeBoard;
  String chapterCount(int n);
  String subtopicCount(int n);
  String unitMarks(int marks);
  String chapterMarks(int marks);
  String get marksNotPublished;
  String get notInExam;
  String get alsoInSyllabus;
  String get formativeNote;
  String inBoardSyllabusAs(String name);
  String get boardPracticals;
  String get interactiveLab;
  String get openLab;
  String get syllabusSource;
  String get progressBasis;
  String noLabsForClass(int classLevel);
  String otherChaptersNoLab(int n);

  // Navigation, home, search, concepts, labs, exam, PYQ, bookmarks, settings
  String get navHome;
  String get navLearn;
  String get navLab;
  String get navExam;
  String get navProgress;
  String get homeGreeting;
  String get chooseYourClass;
  String get tapForChapters;
  String get continueLearning;
  String get startFirstLab;
  String get startFirstLabHint;
  String get explore;
  String get streakShort;
  String get focusShort;
  String get virtualLab;
  String get labsHint;
  String get examZone;
  String get examZoneHint;
  String get focusHint;
  String get bookmarks;
  String get bookmarksHint;
  String get search;
  String get settings;
  String get searchHint;
  String get recentSearches;
  String get clear;
  String noResults(String query);
  String get searchBothLanguages;
  String get allFilter;
  String get chaptersGroup;
  String get topicsGroup;
  String get allChapters;
  String get conceptNotes;
  String get notesComingSoon;
  String get subtopicsTitle;
  String get bookmark;
  String get bookmarked;
  String get sectionWhat;
  String get sectionHow;
  String get sectionWhy;
  String get sectionUses;
  String get sectionObservations;
  String get sectionExam;
  String get sectionFormulas;
  String get sectionPyqs;
  String get sectionRemember;
  String get sectionMistakes;
  String get allClasses;
  String get guideComingSoon;
  String get virtualSimulationNotice;
  String get guideAim;
  String get guideReaction;
  String get guideApparatus;
  String get guideChemicals;
  String get guideProcedure;
  String get guideProcedureNote;
  String get guideExpected;
  String get guideWhy;
  String get guideSafety;
  String get guideResult;
  String get guideVirtualVsReal;
  String get guideInSyllabus;
  String conceptLabAt(int classLevel, String topicNumber, String topicTitle);
  String practicalLink(int classLevel, String number, {required bool official});
  String get notAListedPractical;
  String get startVirtualLab;
  String get viewPractical;
  String relatedVirtualLab(String title);
  String get buretteTitle;
  String buretteReading(String ml);
  String addPortion(String ml);
  String get overshotTitle;
  String overshotMessage(String fromMl, String toMl);
  String get needsResetMessage;
  String get amountApproximate;
  String amountFixed(String ml);
  String get amountTitration;
  String endPointReading(String ml);
  String practicalBreadcrumb(int classLevel, String number);
  String get listedPracticalLabel;
  String officialPapers(int from, int to);
  String get pyqsBeingAdded;
  String get noPaperNote2021;
  String get termNote;
  String get secondExamNote;
  String get chapterWeightage;
  String get browsePyqs;
  String get byChapter;
  String get byYear;
  String get byMarks;
  String get startPractice;
  String get practiceMode;
  String get practiceEmpty;
  String get pyqTitle;
  String get noPyqsYet;
  String pyqCount(int n);
  String marksN(int n);
  String get examOnlyBoardClasses;
  String get showAnswer;
  String get hideAnswer;
  String get tryFirst;
  String get modelAnswer;
  String questionRef(String no, String paper);
  String get officialPaperLink;
  String get summaryNote;
  String get askedInYears;
  String get importanceHigh;
  String get importanceMedium;
  String get importanceLow;
  String get nextQuestion;
  String questionOf(int n, int total);
  String get bookmarksEmpty;
  String get bookmarksEmptyHint;
  String get labsTab;
  String get pyqsTab;
  String get boardAndClass;
  String get languageLabel;
  String get defaultFocus;
  String get yourData;
  String get dataOnDevice;
  String get resetProgress;
  String get resetConfirmTitle;
  String get resetConfirmBody;
  String get cancel;
  String get reset;
  String get progressReset;
  String get aboutContent;

  // Learning content (notes, concepts, chemicals, practice questions)
  String get notesTitle;
  String get definitionTitle;
  String get explanationTitle;
  String get keyPointsTitle;
  String get realLifeTitle;
  String get examFocusTitle;
  String get easyExplanationTitle;
  String get memoryTrickTitle;
  String get reactionFormulaTitle;
  String get commonMistakesTitle;
  String get quickRevisionTitle;
  String get mustRemember;

  // AI tutor
  String get askAi;
  String get askAiAboutThis;
  String get askAiHint;
  String get aiTutorTitle;
  String get aiExplanationLabel;
  String get aiDisclaimer;
  String get aiNotConfiguredTitle;
  String get aiNotConfiguredBody;
  String get aiThinking;
  String get aiInputHint;
  String get aiSend;
  String get aiRetry;
  String get aiTruncated;
  String get aiYou;
  String aiActionLabel(TutorAction action);
  String aiFailure(TutorFailure failure);
  String get relatedPracticals;
  String get keyConcepts;
  String get chemicalsAndReactions;
  String get practiceQuestions;
  String practiceQuestionCount(int n);
  String get practiceQuestionsNote;
  String get noPracticeQuestions;
  String questionTypeName(QuestionType type);
  String difficultyName(Difficulty d);
  String chemicalKindName(ChemicalKind kind);
  String get allTypes;
  String get explanationLabel;
  String get correctAnswer;
  String get notQuite;
  String get reviewNote;
  String sourceLine(String sources);
  String get formulaLabel;
  String get propertiesTitle;
  String get usesTitle;
  String get equationsTitle;
  String get practicalConnection;
  String get relatedTopics;
  String get relatedConcepts;
  String importanceBasis(int papers, int from, int to);
  String get notAskedYet;
  String get pyqsOnTopic;
  String get sourceCheckedLabel;
  String get teacherVerifiedLabel;
  String get sourcesTitle;
  String contentVersion(String year);

  // Lab bench
  String get aim;
  String get procedure;
  String get restart;
  String stepOf(int step, int total);
  String get completedBadge;
  String mistakes(int n);
  String get allStepsDone;
  String get shelfHint;
  String get releaseToPour;

  // Smart Warning
  String get smartWarning;
  String wrongDropMessage(String expected, String actual);
  String safety(String label, String hazard);
  String get tryAgain;

  // Completion
  String get practicalComplete;
  String get perfectRun;
  String finishedWithMistakes(int n);
  String get conclusion;
  String get backToPracticals;
  String get repeat;

  // Reaction labs
  String outOfOrderNote(String actual);
  String get whyNotTitle;
  String get effectHeating;
  String get effectSunlight;
  String get effectWarm;
  String get effectPrecipitate;
  String get effectFumes;
  String get balancedEquation;
  String get reactantsTitle;
  String get productsTitle;
  String get whatHappenedTitle;
  String get whyItHappensTitle;

  // Focus Mode – setup
  String get focusMode;
  String get focusSetupTitle;
  String get focusSetupSubtitle;
  String get sessionLength;
  String minutesShort(int n);
  String durationHint(int minutes);
  String get classLabel;
  String get chapterLabel;
  String get topicLabel;
  String get practicalLabel;
  List<String> get focusRules;
  String get startFocus;
  String get startWithoutFocus;

  // Focus Mode – in the lab
  String focusBreadcrumb(int classLevel, int? chapter, String topic);
  String get timeLeft;
  String get pause;
  String get resume;
  String get paused;
  String get pausedHint;
  String get practicalProgress;
  String stepsDone(int done, int total);
  String get exitFocus;
  String get exitFocusTitle;
  String get exitFocusBody;
  String get keepFocusing;
  String get exit;

  // Focus Mode – complete
  String get focusComplete;
  String focusedFor(int minutes);
  String get correctActions;
  String get wrongActions;
  String get accuracy;
  String get practicalsCompleted;
  String get sessionSaved;
  String get newSession;

  // Analytics
  String get myProgress;
  String get myProgressHint;
  String get noProgressTitle;
  String get noProgressBody;
  String get startPractising;
  String get overallProgress;
  String classProgress(int classLevel);
  String get chaptersCompleted;
  String get topicsCompleted;
  String get currentStreak;
  String streakDays(int n);
  String get noStreak;
  String get practicalAttempts;
  String get learningTime;
  String get totalFocusTime;
  String get focusSessions;
  String sessionsFinished(int n);
  String minuteSessions(int minutes);
  String duration(int seconds);
  String get practicalCompletion;
  String completionRuns(int runs, int attempts);
  String get noActionsYet;
  String get lastSevenDays;
  String weekdayShort(int weekday);
  String dayActions(String day, int correct, int wrong);
  String get chapterProgress;
  String practicalsOf(int done, int total);
  String attemptsCount(int n);
  String get recentActivity;
  String get activityCompleted;
  String focusBadge(int minutes, bool finished);
  String classChapterShort(int classLevel, int chapter);
  String get today;
  String get yesterday;
  List<String> get monthsShort;
  String get localDataNote;

  /// "Today, 14:05" / "Yesterday, 09:30" / "3 Oct, 18:00".
  String when(DateTime at, DateTime now) {
    final local = at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final label = day == today
        ? this.today
        : day == DateTime(today.year, today.month, today.day - 1)
            ? yesterday
            : '${local.day} ${monthsShort[local.month - 1]}';
    return '$label, $time';
  }
}

class EnStrings extends AppStrings {
  const EnStrings() : super(AppLanguage.en);

  static String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  @override
  String get appName => 'Virtual Chemistry Lab';
  @override
  String get homeTitle => 'Virtual\nChemistry Lab';
  @override
  String get homeTagline => 'Do real practicals safely. Pick your class to begin!';
  @override
  String className(int classLevel) => 'Class $classLevel';
  @override
  String get changeLanguage => 'Change language';

  @override
  String classChapters(int classLevel) => 'Class $classLevel Chapters';
  @override
  String chapterOverline(int number) => 'CHAPTER $number';
  @override
  String chapterTopics(int number) => 'Chapter $number Topics';
  @override
  String topicOverline(String number) => 'TOPIC $number';
  @override
  String topicCount(int n) => _plural(n, 'topic');
  @override
  String practicalCount(int n) => _plural(n, 'practical');
  @override
  String stepCount(int n) => _plural(n, 'step');
  @override
  String chemicalCount(int n) => _plural(n, 'chemical');
  @override
  String get start => 'Start';
  @override
  String get noChapters => 'More chapters coming soon!';
  @override
  String get noTopics => 'More topics coming soon!';
  @override
  String get noPracticals => 'More practicals coming soon!';

  @override
  String get chooseBoard => 'Choose your board';
  @override
  String get chooseBoardHint => "Chapters, topics and practicals follow your board's official syllabus.";
  @override
  String get available => 'Available';
  @override
  String get comingSoon => 'Coming soon';
  @override
  String get moreBoards => 'More boards';
  @override
  String get comingSoonNote =>
      'These boards are added only after their official syllabus is verified.';
  @override
  String syllabusYear(String year) => 'Syllabus $year';
  @override
  String get changeBoard => 'Change board';
  @override
  String chapterCount(int n) => _plural(n, 'chapter');
  @override
  String subtopicCount(int n) => _plural(n, 'sub-topic');
  @override
  String unitMarks(int marks) => 'Unit: $marks marks';
  @override
  String chapterMarks(int marks) => '$marks marks';
  @override
  String get marksNotPublished => 'Chapter marks not published';
  @override
  String get notInExam => 'Not in year-end exam';
  @override
  String get alsoInSyllabus => 'Also in the syllabus';
  @override
  String get formativeNote => 'Taught in class but not assessed in the year-end exam.';
  @override
  String inBoardSyllabusAs(String name) => 'Board syllabus name: $name';
  @override
  String get boardPracticals => 'Practicals in the syllabus';
  @override
  String get interactiveLab => 'Interactive lab';
  @override
  String get openLab => 'Open lab';
  @override
  String get syllabusSource => 'Source: official board curriculum and NCERT textbooks';
  @override
  String get progressBasis => 'Progress counts the interactive labs you have completed.';
  @override
  String noLabsForClass(int classLevel) => 'No interactive labs for Class $classLevel yet.';
  @override
  String otherChaptersNoLab(int n) => '${_plural(n, 'other chapter')} without an interactive lab yet';

  @override
  String get navHome => 'Home';
  @override
  String get navLearn => 'Learn';
  @override
  String get navLab => 'Lab';
  @override
  String get navExam => 'Exam';
  @override
  String get navProgress => 'Progress';
  @override
  String get homeGreeting => 'Namaste! What will you explore today?';
  @override
  String get chooseYourClass => 'Choose your class';
  @override
  String get tapForChapters => 'Tap to see chapters';
  @override
  String get continueLearning => 'Continue learning';
  @override
  String get startFirstLab => 'Start your first lab';
  @override
  String get startFirstLabHint => 'Pick a class, open a chapter and try an interactive lab.';
  @override
  String get explore => 'Explore';
  @override
  String get streakShort => 'Streak';
  @override
  String get focusShort => 'Focus';
  @override
  String get virtualLab => 'Virtual Lab';
  @override
  String get labsHint => 'Interactive labs';
  @override
  String get examZone => 'Exam Zone';
  @override
  String get examZoneHint => 'Board exam prep';
  @override
  String get focusHint => '10, 15 min or your own';
  @override
  String get bookmarks => 'Bookmarks';
  @override
  String get bookmarksHint => 'Saved for revision';
  @override
  String get search => 'Search';
  @override
  String get settings => 'Settings';
  @override
  String get searchHint => 'Search chapters, topics, practicals';
  @override
  String get recentSearches => 'Recent';
  @override
  String get clear => 'Clear';
  @override
  String noResults(String query) => 'No results for "$query"';
  @override
  String get searchBothLanguages => 'Search works in English and Hindi.';
  @override
  String get allFilter => 'All';
  @override
  String get chaptersGroup => 'Chapters';
  @override
  String get topicsGroup => 'Topics';
  @override
  String get allChapters => 'All chapters';
  @override
  String get conceptNotes => 'Concept notes';
  @override
  String get notesComingSoon => 'Concept notes for this topic are not in the app yet. They will appear here once written from a checked source and reviewed.';
  @override
  String get subtopicsTitle => 'Sub-topics';
  @override
  String get bookmark => 'Bookmark';
  @override
  String get bookmarked => 'Bookmarked';
  @override
  String get sectionWhat => 'What is it?';
  @override
  String get sectionHow => 'How does it work?';
  @override
  String get sectionWhy => 'Why is it important?';
  @override
  String get sectionUses => 'Real-life uses';
  @override
  String get sectionObservations => 'Key observations';
  @override
  String get sectionExam => 'Exam importance';
  @override
  String get sectionFormulas => 'Important formulas & reactions';
  @override
  String get sectionPyqs => 'Related PYQs';
  @override
  String get sectionRemember => 'Remember for the exam';
  @override
  String get sectionMistakes => 'Common mistakes';
  @override
  String get allClasses => 'All classes';
  @override
  String get guideComingSoon => 'Guide coming soon';
  @override
  String get virtualSimulationNotice =>
      "This is a virtual simulation. It helps you prepare, but it does not replace a real experiment done under your teacher's supervision.";
  @override
  String get guideAim => '🎯 Aim';
  @override
  String get guideReaction => '🧪 Reaction';
  @override
  String get guideApparatus => '🔬 Apparatus';
  @override
  String get guideChemicals => '⚗️ Chemicals and quantities';
  @override
  String get guideProcedure => '📋 Steps in a real lab';
  @override
  String get guideProcedureNote =>
      'These steps follow usual school laboratory practice. In a real lab, follow your teacher and your lab manual.';
  @override
  String get guideExpected => 'You should see';
  @override
  String get guideWhy => 'Why';
  @override
  String get guideSafety => '⚠️ Safety';
  @override
  String get guideResult => '✅ Result';
  @override
  String get guideVirtualVsReal => '💻 Virtual lab vs real lab';
  @override
  String get guideInSyllabus => '📚 Where it is in the syllabus';
  @override
  String conceptLabAt(int classLevel, String topicNumber, String topicTitle) =>
      'Concept lab · Class $classLevel · $topicNumber $topicTitle';
  @override
  String practicalLink(int classLevel, String number, {required bool official}) => official
      ? 'Class $classLevel · Practical $number'
      : 'Class $classLevel · Practical $number — related, not the same experiment';
  @override
  String get notAListedPractical => "Not an experiment in the board's list of practicals.";
  @override
  String get startVirtualLab => 'Start virtual lab';
  @override
  String get viewPractical => 'View practical';
  @override
  String relatedVirtualLab(String title) => 'Related virtual lab: $title';
  @override
  String get buretteTitle => 'Burette';
  @override
  String buretteReading(String ml) => 'Reading: $ml mL';
  @override
  String addPortion(String ml) => '+ $ml mL';
  @override
  String get overshotTitle => 'End point passed';
  @override
  String overshotMessage(String fromMl, String toMl) =>
      'The colour changed during the last portion, so the end point is between $fromMl and $toMl mL. '
      'Use this as a rough reading. Reset and titrate again: run in quickly to about 1 mL before it, '
      'then add 0.1 mL at a time.';
  @override
  String get needsResetMessage => 'The end point was passed. Reset to titrate again.';
  @override
  String get amountApproximate => 'Approximate amount — nothing is measured in this step.';
  @override
  String amountFixed(String ml) => 'Measured with a pipette: exactly $ml mL.';
  @override
  String get amountTitration => 'Burette: run in 1.0 mL portions, then 0.1 mL at a time near the end point.';
  @override
  String endPointReading(String ml) => 'Burette reading at the end point: $ml mL';
  @override
  String practicalBreadcrumb(int classLevel, String number) => 'Class $classLevel · Practical $number';
  @override
  String get listedPracticalLabel => 'Practical in the syllabus';
  @override
  String officialPapers(int from, int to) => 'Official papers, $from–$to';
  @override
  String get pyqsBeingAdded => 'Previous-year questions are being added from official papers. Each one will link to its paper and marking scheme.';
  @override
  String get noPaperNote2021 => 'No 2021 papers: board exams were cancelled because of COVID-19.';
  @override
  String get termNote => '2021-22 was held in two terms.';
  @override
  String get secondExamNote => 'From 2026, Class 10 also has an optional second board exam in May.';
  @override
  String get chapterWeightage => 'Chapter weightage';
  @override
  String get browsePyqs => 'Browse PYQs';
  @override
  String get byChapter => 'Chapter-wise';
  @override
  String get byYear => 'Year-wise';
  @override
  String get byMarks => 'By marks';
  @override
  String get startPractice => 'Start practice mode';
  @override
  String get practiceMode => 'Practice mode';
  @override
  String get practiceEmpty => 'Practice questions will appear here once PYQs are added.';
  @override
  String get pyqTitle => 'Previous-year questions';
  @override
  String get noPyqsYet => 'No questions added yet';
  @override
  String pyqCount(int n) => _plural(n, 'question');
  @override
  String marksN(int n) => _plural(n, 'mark');
  @override
  String get examOnlyBoardClasses => 'Board-exam PYQs are for the classes with a board exam.';
  @override
  String get showAnswer => 'Show answer';
  @override
  String get hideAnswer => 'Hide answer';
  @override
  String get tryFirst => 'Try answering first, then check yourself.';
  @override
  String get modelAnswer => 'Answer & explanation';
  @override
  String questionRef(String no, String paper) => 'Q$no · Paper $paper';
  @override
  String get officialPaperLink => 'Official paper';
  @override
  String get summaryNote => 'Summary in our words — read the exact wording in the official paper.';
  @override
  String get askedInYears => 'This type was asked in';
  @override
  String get importanceHigh => 'High';
  @override
  String get importanceMedium => 'Medium';
  @override
  String get importanceLow => 'Low';
  @override
  String get nextQuestion => 'Next question';
  @override
  String questionOf(int n, int total) => 'Question $n of $total';
  @override
  String get bookmarksEmpty => 'Nothing saved yet';
  @override
  String get bookmarksEmptyHint => 'Tap the bookmark on a topic or lab to keep it here.';
  @override
  String get labsTab => 'Labs';
  @override
  String get pyqsTab => 'PYQs';
  @override
  String get boardAndClass => 'Board & class';
  @override
  String get languageLabel => 'Language';
  @override
  String get defaultFocus => 'Default focus length';
  @override
  String get yourData => 'Your data';
  @override
  String get dataOnDevice => 'Stored only on this device. No account, no personal details.';
  @override
  String get resetProgress => 'Reset progress';
  @override
  String get resetConfirmTitle => 'Reset all progress?';
  @override
  String get resetConfirmBody =>
      'This deletes saved labs, focus sessions, bookmarks, topic status and question answers on this device. Your personal notes are kept. It cannot be undone.';
  @override
  String get cancel => 'Cancel';
  @override
  String get reset => 'Reset';
  @override
  String get progressReset => 'Progress reset.';
  @override
  String get aboutContent => 'About the content';
  @override
  String get notesTitle => 'Notes';
  @override
  String get definitionTitle => 'Definition';
  @override
  String get explanationTitle => 'In simple words';
  @override
  String get keyPointsTitle => '⭐ Main points';
  @override
  String get realLifeTitle => '🌍 Real-life use';
  @override
  String get examFocusTitle => '🎯 Exam importance';
  @override
  String get easyExplanationTitle => 'Easy explanation';
  @override
  String get memoryTrickTitle => '🧠 Memory trick';
  @override
  String get reactionFormulaTitle => '🧪 Reactions & formulas';
  @override
  String get commonMistakesTitle => '⚠️ Common mistakes';
  @override
  String get quickRevisionTitle => '⚡ Quick revision';
  @override
  String get mustRemember => 'Must remember';
  @override
  String get askAi => 'Ask AI';
  @override
  String get askAiAboutThis => '🤖 Ask AI about this';
  @override
  String get askAiHint => 'Have a doubt? Ask in Hindi or English.';
  @override
  String get aiTutorTitle => '🤖 AI Tutor';
  @override
  String get aiExplanationLabel => '🤖 AI Explanation';
  @override
  String get aiDisclaimer =>
      'Written by AI, not from the verified notes — it can make mistakes. Check with your NCERT textbook; verified notes and PYQs are shown separately.';
  @override
  String get aiNotConfiguredTitle => 'AI tutor is not set up';
  @override
  String get aiNotConfiguredBody =>
      'This version of the app is not connected to an AI service. Your verified notes, practice questions and PYQs work without it.';
  @override
  String get aiThinking => 'AI is writing an answer…';
  @override
  String get aiInputHint => 'Type your question (Hindi or English)';
  @override
  String get aiSend => 'Send';
  @override
  String get aiRetry => 'Try again';
  @override
  String get aiTruncated => '(The answer was cut short.)';
  @override
  String get aiYou => 'You';
  @override
  String aiActionLabel(TutorAction action) => switch (action) {
        TutorAction.explainSimply => 'Explain simply',
        TutorAction.stepByStep => 'Step by step',
        TutorAction.examAnswer => 'How to write in the exam?',
        TutorAction.example => 'Give an example',
        TutorAction.quiz => 'Quiz me',
      };
  @override
  String aiFailure(TutorFailure failure) => switch (failure) {
        TutorFailure.notConfigured => aiNotConfiguredTitle,
        TutorFailure.network => 'Could not reach the AI service. Check your internet and try again.',
        TutorFailure.auth => 'The AI service did not accept this app\'s access. Please tell your teacher or the app team.',
        TutorFailure.rateLimited => 'Too many questions right now. Wait a minute and try again.',
        TutorFailure.busy => 'The AI service is busy. Try again in a moment.',
        TutorFailure.refused => 'The AI could not answer this. Try asking in a different way.',
        TutorFailure.badResponse => 'Something went wrong with the answer. Try again.',
      };
  @override
  String get relatedPracticals => 'Related practicals';
  @override
  String get keyConcepts => 'Key concepts';
  @override
  String get chemicalsAndReactions => 'Chemicals & reactions';
  @override
  String get practiceQuestions => 'Practice questions';
  @override
  String practiceQuestionCount(int n) => _plural(n, 'practice question');
  @override
  String get practiceQuestionsNote => 'Written from the NCERT textbook for practice. These are not previous-year questions.';
  @override
  String get noPracticeQuestions => 'No practice questions for this selection.';
  @override
  String questionTypeName(QuestionType type) => switch (type) {
        QuestionType.mcq => 'MCQ',
        QuestionType.assertionReason => 'Assertion–Reason',
        QuestionType.veryShort => 'Very short answer',
        QuestionType.shortAnswer => 'Short answer',
        QuestionType.longAnswer => 'Long answer',
        QuestionType.caseBased => 'Case-based',
        QuestionType.numerical => 'Numerical',
      };
  @override
  String difficultyName(Difficulty d) => switch (d) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Difficult',
      };
  @override
  String chemicalKindName(ChemicalKind kind) => switch (kind) {
        ChemicalKind.compound => 'Compound',
        ChemicalKind.element => 'Element',
        ChemicalKind.reaction => 'Reaction',
      };
  @override
  String get allTypes => 'All types';
  @override
  String get explanationLabel => 'Explanation';
  @override
  String get correctAnswer => 'Correct!';
  @override
  String get notQuite => 'Not quite — the correct answer is marked.';
  @override
  String get reviewNote => 'Written from NCERT and checked against it. Awaiting review by a subject teacher.';
  @override
  String sourceLine(String sources) => 'Source: $sources';
  @override
  String get formulaLabel => 'Formula';
  @override
  String get propertiesTitle => 'Properties';
  @override
  String get usesTitle => 'Uses';
  @override
  String get equationsTitle => 'Balanced equations';
  @override
  String get practicalConnection => 'In the lab';
  @override
  String get relatedTopics => 'Related topics';
  @override
  String get relatedConcepts => 'Related concepts';
  @override
  String importanceBasis(int papers, int from, int to) =>
      'Based on the $papers official papers entered so far (one set per year, $from–$to).';
  @override
  String get notAskedYet => 'Not asked in the papers entered so far.';
  @override
  String get pyqsOnTopic => 'Previous-year questions on this topic';
  @override
  String get sourceCheckedLabel => 'Source-checked';
  @override
  String get teacherVerifiedLabel => 'Teacher-verified';
  @override
  String get sourcesTitle => 'Sources';
  @override
  String contentVersion(String year) => 'Syllabus $year · verified from official documents';

  @override
  String get aim => 'Aim';
  @override
  String get procedure => 'Procedure';
  @override
  String get restart => 'Reset experiment';
  @override
  String stepOf(int step, int total) => 'STEP $step OF $total';
  @override
  String get completedBadge => 'COMPLETED';
  @override
  String mistakes(int n) => _plural(n, 'mistake');
  @override
  String get allStepsDone => 'Practical complete – great work!';
  @override
  String get shelfHint => 'CHEMICAL SHELF  •  drag a bottle up to the beaker';
  @override
  String get releaseToPour => 'Release to pour';

  @override
  String get smartWarning => 'Smart Warning';
  @override
  String wrongDropMessage(String expected, String actual) =>
      'Warning: Wrong Action! You were supposed to add $expected, '
      'but you added $actual. Please try again.';
  @override
  String safety(String label, String hazard) => 'Safety: $label – $hazard';
  @override
  String get tryAgain => 'Try Again';

  @override
  String get practicalComplete => 'Practical Complete!';
  @override
  String get perfectRun => 'Perfect run – no mistakes!';
  @override
  String finishedWithMistakes(int n) => 'Finished with ${_plural(n, 'mistake')}.';
  @override
  String get conclusion => 'Conclusion';
  @override
  String get backToPracticals => 'Back to Practicals';
  @override
  String get repeat => 'Repeat';

  @override
  String outOfOrderNote(String actual) => '$actual is needed in a later step. Follow the order of the steps.';
  @override
  String get whyNotTitle => 'Why this does not work';
  @override
  String get effectHeating => 'Heating';
  @override
  String get effectSunlight => 'In sunlight';
  @override
  String get effectWarm => 'Getting hot';
  @override
  String get effectPrecipitate => 'Precipitate';
  @override
  String get effectFumes => 'Fumes';
  @override
  String get balancedEquation => 'Balanced equation';
  @override
  String get reactantsTitle => 'Reactants';
  @override
  String get productsTitle => 'Products';
  @override
  String get whatHappenedTitle => 'What happened';
  @override
  String get whyItHappensTitle => 'Why it happens';

  @override
  String get focusMode => 'Focus Mode';
  @override
  String get focusSetupTitle => 'Get ready to focus';
  @override
  String get focusSetupSubtitle =>
      'Pick a session length. The timer starts when you enter the lab.';
  @override
  String get sessionLength => 'Session length';
  @override
  String minutesShort(int n) => '$n min';
  @override
  String durationHint(int minutes) => minutes <= 10 ? 'Quick session' : 'Deep focus';
  @override
  String get classLabel => 'Class';
  @override
  String get chapterLabel => 'Chapter';
  @override
  String get topicLabel => 'Topic';
  @override
  String get practicalLabel => 'Practical';
  @override
  List<String> get focusRules => const [
        'The timer runs while you work – pause any time.',
        'Every correct and wrong action is recorded.',
        'Leaving the app pauses the timer automatically.',
      ];
  @override
  String get startFocus => 'Start Focus Session';
  @override
  String get startWithoutFocus => 'Start without Focus Mode';

  @override
  String focusBreadcrumb(int classLevel, int? chapter, String topic) =>
      'Class $classLevel · Ch ${chapter ?? '–'} · Topic $topic';
  @override
  String get timeLeft => 'TIME LEFT';
  @override
  String get pause => 'Pause';
  @override
  String get resume => 'Resume';
  @override
  String get paused => 'Session paused';
  @override
  String get pausedHint => 'Your timer is on hold. Take a breath and resume when ready.';
  @override
  String get practicalProgress => 'Practical progress';
  @override
  String stepsDone(int done, int total) => '$done of $total steps';
  @override
  String get exitFocus => 'Exit Focus';
  @override
  String get exitFocusTitle => 'Exit Focus Mode?';
  @override
  String get exitFocusBody =>
      'Your timer will stop and this session will be saved as incomplete.';
  @override
  String get keepFocusing => 'Keep Focusing';
  @override
  String get exit => 'Exit';

  @override
  String get focusComplete => 'Focus Session Complete!';
  @override
  String focusedFor(int minutes) => 'You stayed focused for $minutes minutes.';
  @override
  String get correctActions => 'Correct actions';
  @override
  String get wrongActions => 'Wrong actions';
  @override
  String get accuracy => 'Accuracy';
  @override
  String get practicalsCompleted => 'Practicals completed';
  @override
  String get sessionSaved => 'Session saved on this device.';
  @override
  String get newSession => 'Start New Session';

  @override
  String get myProgress => 'My Progress';
  @override
  String get myProgressHint => 'Chapters, accuracy and focus time';
  @override
  String get noProgressTitle => 'No progress yet';
  @override
  String get noProgressBody =>
      'Do a practical or a focus session and your progress will show up here.';
  @override
  String get startPractising => 'Start practising';
  @override
  String get overallProgress => 'Overall Chemistry Progress';
  @override
  String classProgress(int classLevel) => 'Class $classLevel';
  @override
  String get chaptersCompleted => 'Chapters completed';
  @override
  String get topicsCompleted => 'Topics completed';
  @override
  String get currentStreak => 'Current streak';
  @override
  String streakDays(int n) => _plural(n, 'day');
  @override
  String get noStreak => 'Practise today to start one';
  @override
  String get practicalAttempts => 'Practical attempts';
  @override
  String get learningTime => 'Learning time';
  @override
  String get totalFocusTime => 'Total focus time';
  @override
  String get focusSessions => 'Focus sessions';
  @override
  String sessionsFinished(int n) => '$n finished on time';
  @override
  String minuteSessions(int minutes) => '$minutes-min sessions';
  @override
  String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  @override
  String get practicalCompletion => 'Practical completion';
  @override
  String completionRuns(int runs, int attempts) =>
      'Finished ${_plural(runs, 'time')} in ${_plural(attempts, 'attempt')}';
  @override
  String get noActionsYet => 'No chemicals poured yet';
  @override
  String get lastSevenDays => 'Chemical actions · last 7 days';
  @override
  String weekdayShort(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  @override
  String dayActions(String day, int correct, int wrong) =>
      '$day: $correct correct, $wrong wrong';
  @override
  String get chapterProgress => 'Chapter & topic progress';
  @override
  String practicalsOf(int done, int total) => '$done/$total practicals';
  @override
  String attemptsCount(int n) => _plural(n, 'attempt');
  @override
  String get recentActivity => 'Recent activity';
  @override
  String get activityCompleted => 'Completed';
  @override
  String focusBadge(int minutes, bool finished) =>
      'Focus $minutes min · ${finished ? 'finished' : 'ended early'}';
  @override
  String classChapterShort(int classLevel, int chapter) => 'Class $classLevel · Ch $chapter';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
  @override
  List<String> get monthsShort => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
  @override
  String get localDataNote => 'Saved only on this device. No account needed.';
}

/// Hindi, following NCERT Hindi-medium terminology
/// (अभिक्रिया, क्षारक, सूचक, प्रेक्षण, अनुमापन …).
class HiStrings extends AppStrings {
  const HiStrings() : super(AppLanguage.hi);

  @override
  String get appName => 'वर्चुअल रसायन प्रयोगशाला';
  @override
  String get homeTitle => 'वर्चुअल\nरसायन प्रयोगशाला';
  @override
  String get homeTagline =>
      'वास्तविक प्रयोग सुरक्षित रूप से करें। शुरू करने के लिए अपनी कक्षा चुनें!';
  @override
  String className(int classLevel) => 'कक्षा $classLevel';
  @override
  String get changeLanguage => 'भाषा बदलें';

  @override
  String classChapters(int classLevel) => 'कक्षा $classLevel के अध्याय';
  @override
  String chapterOverline(int number) => 'अध्याय $number';
  @override
  String chapterTopics(int number) => 'अध्याय $number के विषय';
  @override
  String topicOverline(String number) => 'विषय $number';
  @override
  String topicCount(int n) => '$n विषय';
  @override
  String practicalCount(int n) => '$n प्रयोग';
  @override
  String stepCount(int n) => '$n चरण';
  @override
  String chemicalCount(int n) => '$n रसायन';
  @override
  String get start => 'प्रारंभ करें';
  @override
  String get noChapters => 'और अध्याय जल्द ही आ रहे हैं!';
  @override
  String get noTopics => 'और विषय जल्द ही आ रहे हैं!';
  @override
  String get noPracticals => 'और प्रयोग जल्द ही आ रहे हैं!';

  @override
  String get chooseBoard => 'अपना बोर्ड चुनें';
  @override
  String get chooseBoardHint => 'अध्याय, विषय और प्रयोग आपके बोर्ड के आधिकारिक पाठ्यक्रम के अनुसार होंगे।';
  @override
  String get available => 'उपलब्ध';
  @override
  String get comingSoon => 'जल्द आ रहा है';
  @override
  String get moreBoards => 'अन्य बोर्ड';
  @override
  String get comingSoonNote => 'इन बोर्डों को उनका आधिकारिक पाठ्यक्रम सत्यापित होने के बाद ही जोड़ा जाएगा।';
  @override
  String syllabusYear(String year) => 'पाठ्यक्रम $year';
  @override
  String get changeBoard => 'बोर्ड बदलें';
  @override
  String chapterCount(int n) => '$n अध्याय';
  @override
  String subtopicCount(int n) => '$n उप-विषय';
  @override
  String unitMarks(int marks) => 'इकाई: $marks अंक';
  @override
  String chapterMarks(int marks) => '$marks अंक';
  @override
  String get marksNotPublished => 'अध्यायवार अंक प्रकाशित नहीं';
  @override
  String get notInExam => 'वार्षिक परीक्षा में नहीं';
  @override
  String get alsoInSyllabus => 'पाठ्यक्रम में यह भी';
  @override
  String get formativeNote => 'कक्षा में पढ़ाया जाता है, पर वार्षिक परीक्षा में इसका मूल्यांकन नहीं होता।';
  @override
  String inBoardSyllabusAs(String name) => 'बोर्ड पाठ्यक्रम में नाम: $name';
  @override
  String get boardPracticals => 'पाठ्यक्रम के प्रयोग';
  @override
  String get interactiveLab => 'इंटरैक्टिव लैब';
  @override
  String get openLab => 'लैब खोलें';
  @override
  String get syllabusSource => 'स्रोत: बोर्ड का आधिकारिक पाठ्यक्रम और NCERT पाठ्यपुस्तकें';
  @override
  String get progressBasis => 'प्रगति आपके द्वारा पूरे किए गए इंटरैक्टिव लैब के आधार पर है।';
  @override
  String noLabsForClass(int classLevel) => 'कक्षा $classLevel के लिए अभी कोई इंटरैक्टिव लैब नहीं है।';
  @override
  String otherChaptersNoLab(int n) => '$n अन्य अध्यायों में अभी इंटरैक्टिव लैब नहीं है';

  @override
  String get navHome => 'होम';
  @override
  String get navLearn => 'पढ़ाई';
  @override
  String get navLab => 'लैब';
  @override
  String get navExam => 'परीक्षा';
  @override
  String get navProgress => 'प्रगति';
  @override
  String get homeGreeting => 'नमस्ते! आज क्या सीखेंगे?';
  @override
  String get chooseYourClass => 'अपनी कक्षा चुनें';
  @override
  String get tapForChapters => 'अध्याय देखने के लिए टैप करें';
  @override
  String get continueLearning => 'पढ़ाई जारी रखें';
  @override
  String get startFirstLab => 'अपना पहला लैब शुरू करें';
  @override
  String get startFirstLabHint => 'कक्षा चुनें, अध्याय खोलें और इंटरैक्टिव लैब आज़माएँ।';
  @override
  String get explore => 'और देखें';
  @override
  String get streakShort => 'लगातार';
  @override
  String get focusShort => 'फ़ोकस';
  @override
  String get virtualLab => 'वर्चुअल लैब';
  @override
  String get labsHint => 'इंटरैक्टिव लैब';
  @override
  String get examZone => 'परीक्षा क्षेत्र';
  @override
  String get examZoneHint => 'बोर्ड परीक्षा की तैयारी';
  @override
  String get focusHint => '10, 15 मिनट या अपनी अवधि';
  @override
  String get bookmarks => 'बुकमार्क';
  @override
  String get bookmarksHint => 'दोहराने के लिए सहेजे गए';
  @override
  String get search => 'खोज';
  @override
  String get settings => 'सेटिंग्स';
  @override
  String get searchHint => 'अध्याय, विषय, प्रयोग खोजें';
  @override
  String get recentSearches => 'हाल की खोजें';
  @override
  String get clear => 'साफ़ करें';
  @override
  String noResults(String query) => '"$query" के लिए कोई परिणाम नहीं';
  @override
  String get searchBothLanguages => 'खोज अंग्रेज़ी और हिंदी दोनों में काम करती है।';
  @override
  String get allFilter => 'सभी';
  @override
  String get chaptersGroup => 'अध्याय';
  @override
  String get topicsGroup => 'विषय';
  @override
  String get allChapters => 'सभी अध्याय';
  @override
  String get conceptNotes => 'अवधारणा नोट्स';
  @override
  String get notesComingSoon => 'इस विषय के अवधारणा नोट्स अभी ऐप में नहीं हैं। जाँचे गए स्रोत से लिखे जाने और समीक्षा के बाद ये यहाँ दिखेंगे।';
  @override
  String get subtopicsTitle => 'उप-विषय';
  @override
  String get bookmark => 'बुकमार्क करें';
  @override
  String get bookmarked => 'बुकमार्क किया गया';
  @override
  String get sectionWhat => 'यह क्या है?';
  @override
  String get sectionHow => 'यह कैसे होता है?';
  @override
  String get sectionWhy => 'यह क्यों ज़रूरी है?';
  @override
  String get sectionUses => 'रोज़मर्रा की ज़िंदगी में उपयोग';
  @override
  String get sectionObservations => 'मुख्य प्रेक्षण';
  @override
  String get sectionExam => 'परीक्षा में महत्व';
  @override
  String get sectionFormulas => 'महत्वपूर्ण सूत्र और अभिक्रियाएँ';
  @override
  String get sectionPyqs => 'संबंधित पिछले वर्षों के प्रश्न';
  @override
  String get sectionRemember => 'परीक्षा के लिए याद रखें';
  @override
  String get sectionMistakes => 'आम गलतियाँ';
  @override
  String get allClasses => 'सभी कक्षाएँ';
  @override
  String get guideComingSoon => 'गाइड जल्द आएगी';
  @override
  String get virtualSimulationNotice =>
      'यह एक वर्चुअल सिमुलेशन है। यह तैयारी में मदद करता है, पर शिक्षक की देखरेख में किए जाने वाले वास्तविक प्रयोग का स्थान नहीं लेता।';
  @override
  String get guideAim => '🎯 उद्देश्य';
  @override
  String get guideReaction => '🧪 अभिक्रिया';
  @override
  String get guideApparatus => '🔬 उपकरण';
  @override
  String get guideChemicals => '⚗️ रसायन और मात्राएँ';
  @override
  String get guideProcedure => '📋 वास्तविक लैब में चरण';
  @override
  String get guideProcedureNote =>
      'ये चरण विद्यालय प्रयोगशाला की सामान्य विधि के अनुसार हैं। वास्तविक लैब में अपने शिक्षक और प्रयोगशाला पुस्तिका का पालन करें।';
  @override
  String get guideExpected => 'आपको दिखेगा';
  @override
  String get guideWhy => 'क्यों';
  @override
  String get guideSafety => '⚠️ सुरक्षा';
  @override
  String get guideResult => '✅ परिणाम';
  @override
  String get guideVirtualVsReal => '💻 वर्चुअल लैब बनाम वास्तविक लैब';
  @override
  String get guideInSyllabus => '📚 पाठ्यक्रम में कहाँ है';
  @override
  String conceptLabAt(int classLevel, String topicNumber, String topicTitle) =>
      'अवधारणा लैब · कक्षा $classLevel · $topicNumber $topicTitle';
  @override
  String practicalLink(int classLevel, String number, {required bool official}) => official
      ? 'कक्षा $classLevel · प्रयोग $number'
      : 'कक्षा $classLevel · प्रयोग $number — संबंधित, पर वही प्रयोग नहीं';
  @override
  String get notAListedPractical => 'बोर्ड की प्रयोग सूची का प्रयोग नहीं है।';
  @override
  String get startVirtualLab => 'वर्चुअल लैब शुरू करें';
  @override
  String get viewPractical => 'प्रयोग देखें';
  @override
  String relatedVirtualLab(String title) => 'संबंधित वर्चुअल लैब: $title';
  @override
  String get buretteTitle => 'ब्यूरेट';
  @override
  String buretteReading(String ml) => 'पाठ्यांक: $ml mL';
  @override
  String addPortion(String ml) => '+ $ml mL';
  @override
  String get overshotTitle => 'अंत्य बिंदु पार हो गया';
  @override
  String overshotMessage(String fromMl, String toMl) =>
      'अंतिम भाग डालते समय रंग बदल गया, इसलिए अंत्य बिंदु $fromMl और $toMl mL के बीच है। '
      'इसे मोटा (रफ़) पाठ्यांक मानें। रीसेट करके फिर से अनुमापन करें: उससे लगभग 1 mL पहले तक जल्दी डालें, '
      'फिर एक बार में 0.1 mL डालें।';
  @override
  String get needsResetMessage => 'अंत्य बिंदु पार हो चुका है। फिर से अनुमापन करने के लिए रीसेट करें।';
  @override
  String get amountApproximate => 'अनुमानित मात्रा — इस चरण में कुछ भी मापा नहीं जाता।';
  @override
  String amountFixed(String ml) => 'पिपेट से मापा गया: ठीक $ml mL।';
  @override
  String get amountTitration => 'ब्यूरेट: 1.0 mL के भाग डालें, फिर अंत्य बिंदु के निकट एक बार में 0.1 mL।';
  @override
  String endPointReading(String ml) => 'अंत्य बिंदु पर ब्यूरेट पाठ्यांक: $ml mL';
  @override
  String practicalBreadcrumb(int classLevel, String number) => 'कक्षा $classLevel · प्रयोग $number';
  @override
  String get listedPracticalLabel => 'पाठ्यक्रम का प्रयोग';
  @override
  String officialPapers(int from, int to) => 'आधिकारिक प्रश्नपत्र, $from–$to';
  @override
  String get pyqsBeingAdded => 'पिछले वर्षों के प्रश्न आधिकारिक प्रश्नपत्रों से जोड़े जा रहे हैं। हर प्रश्न अपने प्रश्नपत्र और अंकन योजना से जुड़ा होगा।';
  @override
  String get noPaperNote2021 => '2021 के प्रश्नपत्र नहीं हैं: कोविड-19 के कारण बोर्ड परीक्षाएँ रद्द हुई थीं।';
  @override
  String get termNote => '2021-22 की परीक्षा दो सत्रों में हुई थी।';
  @override
  String get secondExamNote => '2026 से कक्षा 10 के लिए मई में एक वैकल्पिक दूसरी बोर्ड परीक्षा भी है।';
  @override
  String get chapterWeightage => 'अध्याय भार';
  @override
  String get browsePyqs => 'PYQ देखें';
  @override
  String get byChapter => 'अध्याय-वार';
  @override
  String get byYear => 'वर्ष-वार';
  @override
  String get byMarks => 'अंकों के अनुसार';
  @override
  String get startPractice => 'अभ्यास मोड शुरू करें';
  @override
  String get practiceMode => 'अभ्यास मोड';
  @override
  String get practiceEmpty => 'PYQ जुड़ने के बाद अभ्यास प्रश्न यहाँ दिखेंगे।';
  @override
  String get pyqTitle => 'पिछले वर्षों के प्रश्न';
  @override
  String get noPyqsYet => 'अभी कोई प्रश्न नहीं जोड़ा गया';
  @override
  String pyqCount(int n) => '$n प्रश्न';
  @override
  String marksN(int n) => '$n अंक';
  @override
  String get examOnlyBoardClasses => 'बोर्ड परीक्षा के PYQ केवल बोर्ड परीक्षा वाली कक्षाओं के लिए हैं।';
  @override
  String get showAnswer => 'उत्तर देखें';
  @override
  String get hideAnswer => 'उत्तर छिपाएँ';
  @override
  String get tryFirst => 'पहले स्वयं उत्तर दें, फिर जाँचें।';
  @override
  String get modelAnswer => 'उत्तर और व्याख्या';
  @override
  String questionRef(String no, String paper) => 'प्रश्न $no · प्रश्नपत्र $paper';
  @override
  String get officialPaperLink => 'आधिकारिक प्रश्नपत्र';
  @override
  String get summaryNote => 'हमारे शब्दों में सारांश — सटीक शब्दों के लिए आधिकारिक प्रश्नपत्र देखें।';
  @override
  String get askedInYears => 'इस तरह का प्रश्न इन वर्षों में आया';
  @override
  String get importanceHigh => 'अधिक';
  @override
  String get importanceMedium => 'मध्यम';
  @override
  String get importanceLow => 'कम';
  @override
  String get nextQuestion => 'अगला प्रश्न';
  @override
  String questionOf(int n, int total) => 'प्रश्न $n / $total';
  @override
  String get bookmarksEmpty => 'अभी कुछ सहेजा नहीं गया';
  @override
  String get bookmarksEmptyHint => 'किसी विषय या लैब पर बुकमार्क दबाएँ, वह यहाँ दिखेगा।';
  @override
  String get labsTab => 'लैब';
  @override
  String get pyqsTab => 'PYQ';
  @override
  String get boardAndClass => 'बोर्ड और कक्षा';
  @override
  String get languageLabel => 'भाषा';
  @override
  String get defaultFocus => 'डिफ़ॉल्ट फ़ोकस अवधि';
  @override
  String get yourData => 'आपका डेटा';
  @override
  String get dataOnDevice => 'केवल इस डिवाइस पर सहेजा गया। कोई खाता नहीं, कोई निजी जानकारी नहीं।';
  @override
  String get resetProgress => 'प्रगति रीसेट करें';
  @override
  String get resetConfirmTitle => 'सारी प्रगति रीसेट करें?';
  @override
  String get resetConfirmBody =>
      'इससे इस डिवाइस पर सहेजे गए लैब, फ़ोकस सत्र, बुकमार्क, विषयों की स्थिति और प्रश्नों के उत्तर हट जाएँगे। आपके अपने नोट्स बने रहेंगे। इसे वापस नहीं लाया जा सकता।';
  @override
  String get cancel => 'रद्द करें';
  @override
  String get reset => 'रीसेट करें';
  @override
  String get progressReset => 'प्रगति रीसेट हो गई।';
  @override
  String get aboutContent => 'सामग्री के बारे में';
  @override
  String get notesTitle => 'नोट्स';
  @override
  String get definitionTitle => 'परिभाषा';
  @override
  String get explanationTitle => 'सरल शब्दों में';
  @override
  String get keyPointsTitle => '⭐ मुख्य बिंदु';
  @override
  String get realLifeTitle => '🌍 दैनिक जीवन में उपयोग';
  @override
  String get examFocusTitle => '🎯 परीक्षा में महत्व';
  @override
  String get easyExplanationTitle => 'आसान व्याख्या';
  @override
  String get memoryTrickTitle => '🧠 याद करने की ट्रिक';
  @override
  String get reactionFormulaTitle => '🧪 अभिक्रिया / सूत्र';
  @override
  String get commonMistakesTitle => '⚠️ आम गलतियाँ';
  @override
  String get quickRevisionTitle => '⚡ त्वरित पुनरावृत्ति';
  @override
  String get mustRemember => 'ज़रूर याद रखें';
  @override
  String get askAi => 'AI से पूछें';
  @override
  String get askAiAboutThis => '🤖 इसके बारे में AI से पूछें';
  @override
  String get askAiHint => 'कोई शंका है? हिंदी या अंग्रेज़ी में पूछें।';
  @override
  String get aiTutorTitle => '🤖 AI ट्यूटर';
  @override
  String get aiExplanationLabel => '🤖 AI व्याख्या';
  @override
  String get aiDisclaimer =>
      'यह AI ने लिखा है, जाँचे गए नोट्स से नहीं — इसमें गलती हो सकती है। अपनी NCERT पुस्तक से मिलान करें; जाँचे गए नोट्स और PYQ अलग दिखाए जाते हैं।';
  @override
  String get aiNotConfiguredTitle => 'AI ट्यूटर अभी चालू नहीं है';
  @override
  String get aiNotConfiguredBody =>
      'ऐप का यह संस्करण किसी AI सेवा से जुड़ा नहीं है। आपके जाँचे गए नोट्स, अभ्यास प्रश्न और PYQ इसके बिना भी चलते हैं।';
  @override
  String get aiThinking => 'AI उत्तर लिख रहा है…';
  @override
  String get aiInputHint => 'अपना प्रश्न लिखें (हिंदी या अंग्रेज़ी)';
  @override
  String get aiSend => 'भेजें';
  @override
  String get aiRetry => 'फिर कोशिश करें';
  @override
  String get aiTruncated => '(उत्तर बीच में कट गया।)';
  @override
  String get aiYou => 'आप';
  @override
  String aiActionLabel(TutorAction action) => switch (action) {
        TutorAction.explainSimply => 'सरल भाषा में समझाओ',
        TutorAction.stepByStep => 'चरण-दर-चरण',
        TutorAction.examAnswer => 'परीक्षा में कैसे लिखूँ?',
        TutorAction.example => 'उदाहरण दो',
        TutorAction.quiz => 'मेरा क्विज़ लो',
      };
  @override
  String aiFailure(TutorFailure failure) => switch (failure) {
        TutorFailure.notConfigured => aiNotConfiguredTitle,
        TutorFailure.network => 'AI सेवा से संपर्क नहीं हो पाया। इंटरनेट जाँचकर फिर कोशिश करें।',
        TutorFailure.auth => 'AI सेवा ने इस ऐप की पहुँच स्वीकार नहीं की। कृपया शिक्षक या ऐप टीम को बताएँ।',
        TutorFailure.rateLimited => 'अभी बहुत अधिक प्रश्न आ रहे हैं। एक मिनट रुककर फिर कोशिश करें।',
        TutorFailure.busy => 'AI सेवा अभी व्यस्त है। थोड़ी देर में फिर कोशिश करें।',
        TutorFailure.refused => 'AI इसका उत्तर नहीं दे सका। प्रश्न दूसरे तरीके से पूछें।',
        TutorFailure.badResponse => 'उत्तर में कुछ गड़बड़ हुई। फिर कोशिश करें।',
      };
  @override
  String get relatedPracticals => 'संबंधित प्रयोग';
  @override
  String get keyConcepts => 'मुख्य अवधारणाएँ';
  @override
  String get chemicalsAndReactions => 'रसायन एवं अभिक्रियाएँ';
  @override
  String get practiceQuestions => 'अभ्यास प्रश्न';
  @override
  String practiceQuestionCount(int n) => '$n अभ्यास प्रश्न';
  @override
  String get practiceQuestionsNote => 'NCERT पाठ्यपुस्तक से अभ्यास के लिए लिखे गए। ये पिछले वर्षों के प्रश्न नहीं हैं।';
  @override
  String get noPracticeQuestions => 'इस चयन के लिए कोई अभ्यास प्रश्न नहीं।';
  @override
  String questionTypeName(QuestionType type) => switch (type) {
        QuestionType.mcq => 'बहुविकल्पीय',
        QuestionType.assertionReason => 'अभिकथन–कारण',
        QuestionType.veryShort => 'अति लघु उत्तरीय',
        QuestionType.shortAnswer => 'लघु उत्तरीय',
        QuestionType.longAnswer => 'दीर्घ उत्तरीय',
        QuestionType.caseBased => 'प्रकरण आधारित',
        QuestionType.numerical => 'आंकिक',
      };
  @override
  String difficultyName(Difficulty d) => switch (d) {
        Difficulty.easy => 'सरल',
        Difficulty.medium => 'मध्यम',
        Difficulty.hard => 'कठिन',
      };
  @override
  String chemicalKindName(ChemicalKind kind) => switch (kind) {
        ChemicalKind.compound => 'यौगिक',
        ChemicalKind.element => 'तत्व',
        ChemicalKind.reaction => 'अभिक्रिया',
      };
  @override
  String get allTypes => 'सभी प्रकार';
  @override
  String get explanationLabel => 'व्याख्या';
  @override
  String get correctAnswer => 'सही!';
  @override
  String get notQuite => 'सही नहीं — सही उत्तर चिह्नित है।';
  @override
  String get reviewNote => 'NCERT से लिखा गया और उससे मिलाया गया। विषय-शिक्षक की समीक्षा शेष है।';
  @override
  String sourceLine(String sources) => 'स्रोत: $sources';
  @override
  String get formulaLabel => 'सूत्र';
  @override
  String get propertiesTitle => 'गुणधर्म';
  @override
  String get usesTitle => 'उपयोग';
  @override
  String get equationsTitle => 'संतुलित समीकरण';
  @override
  String get practicalConnection => 'प्रयोगशाला में';
  @override
  String get relatedTopics => 'संबंधित विषय';
  @override
  String get relatedConcepts => 'संबंधित अवधारणाएँ';
  @override
  String importanceBasis(int papers, int from, int to) =>
      'अब तक दर्ज $papers आधिकारिक प्रश्नपत्रों पर आधारित (प्रति वर्ष एक सेट, $from–$to)।';
  @override
  String get notAskedYet => 'अब तक दर्ज प्रश्नपत्रों में नहीं पूछा गया।';
  @override
  String get pyqsOnTopic => 'इस विषय पर पिछले वर्षों के प्रश्न';
  @override
  String get sourceCheckedLabel => 'स्रोत से जाँचा गया';
  @override
  String get teacherVerifiedLabel => 'शिक्षक द्वारा सत्यापित';
  @override
  String get sourcesTitle => 'स्रोत';
  @override
  String contentVersion(String year) => 'पाठ्यक्रम $year · आधिकारिक दस्तावेज़ों से सत्यापित';

  @override
  String get aim => 'उद्देश्य';
  @override
  String get procedure => 'विधि';
  @override
  String get restart => 'प्रयोग रीसेट करें';
  @override
  String stepOf(int step, int total) => 'चरण $step / $total';
  @override
  String get completedBadge => 'पूर्ण';
  @override
  String mistakes(int n) => '$n ${n == 1 ? 'त्रुटि' : 'त्रुटियाँ'}';
  @override
  String get allStepsDone => 'प्रयोग पूर्ण – बहुत बढ़िया!';
  @override
  String get shelfHint => 'रसायन शेल्फ़  •  बोतल को ऊपर बीकर तक खींचें';
  @override
  String get releaseToPour => 'डालने के लिए छोड़ें';

  @override
  String get smartWarning => 'स्मार्ट चेतावनी';
  @override
  String wrongDropMessage(String expected, String actual) =>
      'चेतावनी: गलत क्रिया! आपको $expected डालना था, '
      'लेकिन आपने $actual डाल दिया। कृपया पुनः प्रयास करें।';
  @override
  String safety(String label, String hazard) => 'सुरक्षा: $label – $hazard';
  @override
  String get tryAgain => 'पुनः प्रयास करें';

  @override
  String get practicalComplete => 'प्रयोग पूर्ण हुआ!';
  @override
  String get perfectRun => 'उत्कृष्ट – एक भी त्रुटि नहीं!';
  @override
  String finishedWithMistakes(int n) =>
      '$n ${n == 1 ? 'त्रुटि' : 'त्रुटियों'} के साथ पूर्ण किया।';
  @override
  String get conclusion => 'निष्कर्ष';
  @override
  String get backToPracticals => 'प्रयोगों पर वापस जाएँ';
  @override
  String get repeat => 'दोबारा करें';

  @override
  String outOfOrderNote(String actual) => '$actual बाद के चरण में डाला जाएगा। चरणों का क्रम अपनाएँ।';
  @override
  String get whyNotTitle => 'यह क्यों काम नहीं करेगा';
  @override
  String get effectHeating => 'गरम हो रहा है';
  @override
  String get effectSunlight => 'सूर्य के प्रकाश में';
  @override
  String get effectWarm => 'गरम हो गया';
  @override
  String get effectPrecipitate => 'अवक्षेप';
  @override
  String get effectFumes => 'धुआँ / वाष्प';
  @override
  String get balancedEquation => 'संतुलित समीकरण';
  @override
  String get reactantsTitle => 'अभिकारक';
  @override
  String get productsTitle => 'उत्पाद';
  @override
  String get whatHappenedTitle => 'क्या हुआ';
  @override
  String get whyItHappensTitle => 'ऐसा क्यों होता है';

  @override
  String get focusMode => 'फ़ोकस मोड';
  @override
  String get focusSetupTitle => 'एकाग्र होने के लिए तैयार हो जाइए';
  @override
  String get focusSetupSubtitle =>
      'सत्र की अवधि चुनें। प्रयोगशाला में प्रवेश करते ही टाइमर शुरू हो जाएगा।';
  @override
  String get sessionLength => 'सत्र की अवधि';
  @override
  String minutesShort(int n) => '$n मिनट';
  @override
  String durationHint(int minutes) => minutes <= 10 ? 'छोटा सत्र' : 'गहन एकाग्रता';
  @override
  String get classLabel => 'कक्षा';
  @override
  String get chapterLabel => 'अध्याय';
  @override
  String get topicLabel => 'विषय';
  @override
  String get practicalLabel => 'प्रयोग';
  @override
  List<String> get focusRules => const [
        'आपके कार्य करते समय टाइमर चलता रहेगा – आप कभी भी रोक सकते हैं।',
        'हर सही और गलत क्रिया दर्ज की जाएगी।',
        'ऐप से बाहर जाने पर टाइमर अपने-आप रुक जाएगा।',
      ];
  @override
  String get startFocus => 'फ़ोकस सत्र प्रारंभ करें';
  @override
  String get startWithoutFocus => 'फ़ोकस मोड के बिना प्रारंभ करें';

  @override
  String focusBreadcrumb(int classLevel, int? chapter, String topic) =>
      'कक्षा $classLevel · अध्याय ${chapter ?? '–'} · विषय $topic';
  @override
  String get timeLeft => 'शेष समय';
  @override
  String get pause => 'रोकें';
  @override
  String get resume => 'जारी रखें';
  @override
  String get paused => 'सत्र रुका हुआ है';
  @override
  String get pausedHint => 'आपका टाइमर रुका हुआ है। तैयार होने पर जारी रखें।';
  @override
  String get practicalProgress => 'प्रयोग की प्रगति';
  @override
  String stepsDone(int done, int total) => '$total में से $done चरण पूर्ण';
  @override
  String get exitFocus => 'फ़ोकस से बाहर निकलें';
  @override
  String get exitFocusTitle => 'फ़ोकस मोड से बाहर निकलें?';
  @override
  String get exitFocusBody =>
      'आपका टाइमर रुक जाएगा और यह सत्र अपूर्ण के रूप में सहेजा जाएगा।';
  @override
  String get keepFocusing => 'फ़ोकस जारी रखें';
  @override
  String get exit => 'बाहर निकलें';

  @override
  String get focusComplete => 'फ़ोकस सत्र पूर्ण हुआ!';
  @override
  String focusedFor(int minutes) => 'आपने $minutes मिनट तक एकाग्र होकर अभ्यास किया।';
  @override
  String get correctActions => 'सही क्रियाएँ';
  @override
  String get wrongActions => 'गलत क्रियाएँ';
  @override
  String get accuracy => 'सटीकता';
  @override
  String get practicalsCompleted => 'पूर्ण किए गए प्रयोग';
  @override
  String get sessionSaved => 'सत्र इस डिवाइस पर सहेज लिया गया है।';
  @override
  String get newSession => 'नया सत्र प्रारंभ करें';

  @override
  String get myProgress => 'मेरी प्रगति';
  @override
  String get myProgressHint => 'अध्याय, सटीकता और फ़ोकस समय';
  @override
  String get noProgressTitle => 'अभी कोई प्रगति नहीं';
  @override
  String get noProgressBody =>
      'कोई प्रयोग या फ़ोकस सत्र करें, आपकी प्रगति यहाँ दिखाई देगी।';
  @override
  String get startPractising => 'अभ्यास शुरू करें';
  @override
  String get overallProgress => 'समग्र रसायन प्रगति';
  @override
  String classProgress(int classLevel) => 'कक्षा $classLevel';
  @override
  String get chaptersCompleted => 'पूर्ण अध्याय';
  @override
  String get topicsCompleted => 'पूर्ण विषय';
  @override
  String get currentStreak => 'लगातार अभ्यास';
  @override
  String streakDays(int n) => '$n दिन';
  @override
  String get noStreak => 'शुरुआत के लिए आज अभ्यास करें';
  @override
  String get practicalAttempts => 'प्रयोग के प्रयास';
  @override
  String get learningTime => 'अध्ययन समय';
  @override
  String get totalFocusTime => 'कुल फ़ोकस समय';
  @override
  String get focusSessions => 'फ़ोकस सत्र';
  @override
  String sessionsFinished(int n) => '$n सत्र समय पर पूरे';
  @override
  String minuteSessions(int minutes) => '$minutes मिनट के सत्र';
  @override
  String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '$h घंटे $m मिनट' : '$m मिनट';
  }

  @override
  String get practicalCompletion => 'प्रयोग पूर्णता';
  @override
  String completionRuns(int runs, int attempts) =>
      '$attempts ${attempts == 1 ? 'प्रयास' : 'प्रयासों'} में $runs बार पूर्ण';
  @override
  String get noActionsYet => 'अभी तक कोई रसायन नहीं डाला गया';
  @override
  String get lastSevenDays => 'रासायनिक क्रियाएँ · पिछले 7 दिन';
  @override
  String weekdayShort(int weekday) =>
      const ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'][weekday - 1];
  @override
  String dayActions(String day, int correct, int wrong) =>
      '$day: $correct सही, $wrong गलत';
  @override
  String get chapterProgress => 'अध्याय एवं विषय की प्रगति';
  @override
  String practicalsOf(int done, int total) => '$done/$total प्रयोग';
  @override
  String attemptsCount(int n) => '$n प्रयास';
  @override
  String get recentActivity => 'हाल की गतिविधि';
  @override
  String get activityCompleted => 'पूर्ण';
  @override
  String focusBadge(int minutes, bool finished) =>
      'फ़ोकस $minutes मिनट · ${finished ? 'पूरा' : 'बीच में छोड़ा'}';
  @override
  String classChapterShort(int classLevel, int chapter) =>
      'कक्षा $classLevel · अध्याय $chapter';
  @override
  String get today => 'आज';
  @override
  String get yesterday => 'कल';
  @override
  List<String> get monthsShort => const [
        'जन॰', 'फ़र॰', 'मार्च', 'अप्रैल', 'मई', 'जून',
        'जुलाई', 'अग॰', 'सित॰', 'अक्टू॰', 'नव॰', 'दिस॰',
      ];
  @override
  String get localDataNote => 'केवल इस डिवाइस पर सहेजा गया। किसी खाते की आवश्यकता नहीं।';
}

extension AppStringsContext on BuildContext {
  /// Current strings; rebuilds the caller when the language changes.
  AppStrings get strings => AppStrings.of(watch<LanguageController>().language);

  /// Current strings without subscribing – for event handlers.
  AppStrings get readStrings => AppStrings.of(read<LanguageController>().language);
}
