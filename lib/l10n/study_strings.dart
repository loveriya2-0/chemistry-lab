import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../content/models/practical_coverage.dart';
import '../state/language_controller.dart';
import '../study/study_focus.dart';
import '../study/study_progress_store.dart';
import 'app_language.dart';

/// UI text for the study features: topic explorer, personal notes,
/// practice and revision, the study timer, the lab tutorial and the
/// practical status list. Same rule as [AppStrings]: each language is a
/// subclass, so a missing translation is a compile error.
///
/// In `build` use `context.study`; in callbacks `context.readStudy`.
abstract class StudyStrings {
  const StudyStrings();

  static StudyStrings of(AppLanguage language) => switch (language) {
        AppLanguage.en => const EnStudyStrings(),
        AppLanguage.hi => const HiStudyStrings(),
      };

  // Topic status and progress
  String statusName(TopicStatus s);
  String get statusTitle;
  String get markCompleted;
  String get markReviseAgain;
  String get markInProgress;
  String get completionRule;
  String topicsStudied(int done, int total);
  String get chapterProgressTitle;
  String get noTopicsToTrack;
  String get previousTopic;
  String get nextTopic;
  String partOfTopic(String number);
  String get openTopic;

  // Content availability
  String get whatsHere;
  String get contentExplanation;
  String get contentKeyPoints;
  String get contentQuickRevision;
  String get contentMemoryTricks;
  String get contentFormulas;
  String get contentExamples;
  String contentPractice(int n);
  String contentPyqs(int n);
  String get contentPracticals;
  String get notAvailableYet;
  String get availabilityNote;

  // Personal notes
  String get myNotes;
  String get myNotesHint;
  String get addNote;
  String get newNote;
  String get editNote;
  String get noteFieldHint;
  String get noteSaved;
  String get noteSaving;
  String get deleteNote;
  String get deleteNoteTitle;
  String get deleteNoteBody;
  String get delete;
  String get pin;
  String get unpin;
  String get favourite;
  String get unfavourite;
  String get noNotesYet;
  String get noNotesHint;
  String get allNotes;
  String get pinned;
  String get favourites;
  String get searchNotes;
  String noNotesMatch(String q);
  String get personalNoteLabel;
  String notesCount(int n);
  String get backupNotes;
  String get backupNotesBody;
  String get copyBackup;
  String get backupCopied;
  String get restoreNotes;
  String get restoreNotesBody;
  String get restore;
  String notesRestored(int n);
  String get notABackup;
  String get wholeChapter;
  String unreadableNotesKept(int n);
  String editedOn(String date);

  // Practice
  String get practiseTopic;
  String get practiseOneByOne;
  String get chapterTest;
  String chapterTestHint(int n);
  String get allDifficulties;
  String get difficultyLabel;
  String get typeLabel;
  String questionsAvailable(int n);
  String practiceStats(int attempted, int total, String accuracy);
  String get notAttemptedYet;
  String get checkAnswer;
  String get showModelAnswer;
  String get selfCheckHint;
  String get iGotItRight;
  String get iGotItWrong;
  String get next;
  String get finish;
  String questionXofY(int x, int y);
  String get sessionComplete;
  String scoreLine(int correct, int total);
  String get retryWrong;
  String get reviewAnswers;
  String get done;
  String get yourAnswer;
  String get correctOptionLabel;
  String get markedRight;
  String get markedWrong;
  String get saveQuestion;
  String get questionSaved;
  String retryMistakes(int n);
  String get noQuestionsForFilter;
  String get onlyUnanswered;
  String get solutionSteps;
  String get attemptedLabel;
  String get correctLabel;
  String get accuracyLabel;
  String get remainingLabel;
  String get selfMarkedNote;

  // Revision
  String get revision;
  String get revisionHint;
  String get topicsToRevise;
  String get mistakesToFix;
  String get savedQuestions;
  String get savedFormulas;
  String get needsPractice;
  String get needsPracticeHint;
  String get markRevised;
  String get revised;
  String get practiseMistakes;
  String get practiseSaved;
  String revisionDone(int done, int total);
  String get nothingToRevise;
  String get nothingToReviseHint;
  String get noMistakes;
  String get noSavedQuestions;
  String get noSavedFormulas;
  String get noTopicsToRevise;
  String accuracyShort(int percent, int answers);
  String get saveFormula;
  String get formulaSaved;
  String get fixedMistakes;

  // Study timer
  String get studyTimer;
  String get studyTimerHint;
  String get whatAreYouStudying;
  String get wholeClass;
  String get chooseChapter;
  String get chooseTopic;
  String get choosePractical;
  String get anyChapter;
  String get anyTopic;
  String get noPractical;
  String get lengthLabel;
  String get custom;
  String minutes(int n);
  String get breakLabel;
  String get dailyGoal;
  String get startSession;
  String get pause;
  String get resume;
  String get endSession;
  String get endSessionTitle;
  String get endSessionBody;
  String get keepGoing;
  String get sessionDone;
  String focusedFor(String time);
  String takeBreak(int minutes);
  String get skipBreak;
  String get onBreak;
  String get breakOver;
  String get backToStudy;
  String get today;
  String get thisWeek;
  String goalProgress(int done, int goal);
  String get goalReached;
  String get history;
  String get noSessionsYet;
  String studyStatus(StudySessionStatus s);
  String get backgroundNote;
  String get studyTimeOnTopic;
  String interruptedSaved(String time);
  String get focusSettings;
  String get customLength;
  String get lengthRange;
  String get labFocus;
  String get studyFocus;
  String totalFocus(String time);

  // Home
  String get studyPath;
  String get pathLearn;
  String get pathNotes;
  String get pathPractice;
  String get pathLab;
  String get pathRevise;
  String get recentlyStudied;
  String get unfinishedChapters;
  String revisionItems(int n);
  String focusToday(int done, int goal);
  String get savedForLater;
  String get continueTopic;

  // Search
  String get questionsGroup;
  String get formulasGroup;
  String get notesGroup;

  // Lab tutorial
  String get tutorialTitle;
  String get tutorialWelcome;
  String get tutorialWelcomeBody;
  String get tutorialShelf;
  String get tutorialShelfBody;
  String get tutorialBeaker;
  String get tutorialBeakerBody;
  String get tutorialProgress;
  String get tutorialProgressBody;
  String get tutorialDemo;
  String get tutorialDemoBody;
  String get tutorialWrong;
  String get tutorialWrongBody;
  String get tutorialReset;
  String get tutorialResetBody;
  String get tutorialComplete;
  String get tutorialCompleteBody;
  String get tutorialTry;
  String tutorialTryBody(String chemical);
  String get tutorialTryWrong;
  String tutorialTryWrongBody(String picked, String expected);
  String get tutorialWellDone;
  String get tutorialWellDoneBody;
  String get tutorialPracticeOnly;
  String get skip;
  String get continueLabel;
  String get replay;
  String get replayTutorial;
  String get startLab;
  String get vivaTitle;
  String get vivaHint;
  String get vivaShowAnswer;
  String vivaCount(int n);
  String stepNofM(int n, int m);

  // Practical status
  String get practicalStatusTitle;
  String get practicalStatusHint;
  String practicalLevel(PracticalLevel level);
  String practicalLevelHint(PracticalLevel level);
  String get coveredBy;
  String get notCovered;
  String practicalCountLine(int full, int partial, int guide, int none);
}

String _plural(int n, String one, String many) => n == 1 ? one : many;

class EnStudyStrings extends StudyStrings {
  const EnStudyStrings();

  @override
  String statusName(TopicStatus s) => switch (s) {
        TopicStatus.notStarted => 'Not started',
        TopicStatus.inProgress => 'In progress',
        TopicStatus.completed => 'Completed',
        TopicStatus.reviseAgain => 'Revise again',
      };
  @override
  String get statusTitle => 'Your status';
  @override
  String get markCompleted => 'Mark completed';
  @override
  String get markReviseAgain => 'Revise again';
  @override
  String get markInProgress => 'In progress';
  @override
  String get completionRule =>
      'A topic counts as studied when you mark it Completed or Revise again. A topic with sub-topics also counts once all its sub-topics are marked. Question accuracy is shown separately.';
  @override
  String topicsStudied(int done, int total) => '$done of $total ${_plural(total, 'topic', 'topics')} studied';
  @override
  String get chapterProgressTitle => 'Chapter progress';
  @override
  String get noTopicsToTrack => 'This chapter is studied as one unit.';
  @override
  String get previousTopic => 'Previous';
  @override
  String get nextTopic => 'Next';
  @override
  String partOfTopic(String number) => 'Part of topic $number';
  @override
  String get openTopic => 'Open topic';

  @override
  String get whatsHere => 'In this topic';
  @override
  String get contentExplanation => 'Explanation';
  @override
  String get contentKeyPoints => 'Key points';
  @override
  String get contentQuickRevision => 'Quick revision';
  @override
  String get contentMemoryTricks => 'Memory tricks';
  @override
  String get contentFormulas => 'Formulas';
  @override
  String get contentExamples => 'Real-life examples';
  @override
  String contentPractice(int n) => '$n practice ${_plural(n, 'question', 'questions')}';
  @override
  String contentPyqs(int n) => '$n ${_plural(n, 'PYQ', 'PYQs')}';
  @override
  String get contentPracticals => 'Related practicals';
  @override
  String get notAvailableYet => 'not added yet';
  @override
  String get availabilityNote => 'Greyed items are not in the app for this topic yet.';

  @override
  String get myNotes => 'My notes';
  @override
  String get myNotesHint => 'Your own notes, in Hindi, English or Hinglish. Saved only on this phone.';
  @override
  String get addNote => 'Add a note';
  @override
  String get newNote => 'New note';
  @override
  String get editNote => 'Edit note';
  @override
  String get noteFieldHint => 'Write in your own words — Hindi, English or Hinglish…';
  @override
  String get noteSaved => 'Saved';
  @override
  String get noteSaving => 'Saving…';
  @override
  String get deleteNote => 'Delete note';
  @override
  String get deleteNoteTitle => 'Delete this note?';
  @override
  String get deleteNoteBody => 'It will be removed from this phone. This cannot be undone.';
  @override
  String get delete => 'Delete';
  @override
  String get pin => 'Pin';
  @override
  String get unpin => 'Unpin';
  @override
  String get favourite => 'Favourite';
  @override
  String get unfavourite => 'Remove from favourites';
  @override
  String get noNotesYet => 'No notes yet';
  @override
  String get noNotesHint => 'Write what you understood, in your own words. Only you can see your notes.';
  @override
  String get allNotes => 'All';
  @override
  String get pinned => 'Pinned';
  @override
  String get favourites => 'Favourites';
  @override
  String get searchNotes => 'Search your notes';
  @override
  String noNotesMatch(String q) => 'No notes contain “$q”';
  @override
  String get personalNoteLabel => 'Your note — not checked content';
  @override
  String notesCount(int n) => '$n ${_plural(n, 'note', 'notes')}';
  @override
  String get backupNotes => 'Back up notes';
  @override
  String get backupNotesBody =>
      'Copy this backup text and keep it somewhere safe (for example, send it to yourself). You can paste it back with Restore.';
  @override
  String get copyBackup => 'Copy backup';
  @override
  String get backupCopied => 'Backup copied';
  @override
  String get restoreNotes => 'Restore notes';
  @override
  String get restoreNotesBody => 'Paste a backup made with “Back up notes”. Notes on this phone are kept; only newer copies replace them.';
  @override
  String get restore => 'Restore';
  @override
  String notesRestored(int n) => '$n ${_plural(n, 'note', 'notes')} restored';
  @override
  String get notABackup => 'That text is not a notes backup.';
  @override
  String get wholeChapter => 'Whole chapter';
  @override
  String unreadableNotesKept(int n) => '$n saved ${_plural(n, 'note', 'notes')} could not be read by this version and ${_plural(n, 'is', 'are')} kept safely.';
  @override
  String editedOn(String date) => 'Edited $date';

  @override
  String get practiseTopic => 'Practise this topic';
  @override
  String get practiseOneByOne => 'Practise one by one';
  @override
  String get chapterTest => 'Chapter test';
  @override
  String chapterTestHint(int n) => 'Up to $n mixed questions from the whole chapter';
  @override
  String get allDifficulties => 'All levels';
  @override
  String get difficultyLabel => 'Difficulty';
  @override
  String get typeLabel => 'Type';
  @override
  String questionsAvailable(int n) => '$n ${_plural(n, 'question', 'questions')}';
  @override
  String practiceStats(int attempted, int total, String accuracy) => '$attempted/$total attempted · $accuracy accuracy';
  @override
  String get notAttemptedYet => 'Not attempted yet';
  @override
  String get checkAnswer => 'Check answer';
  @override
  String get showModelAnswer => 'Show model answer';
  @override
  String get selfCheckHint => 'Answer in your notebook first, then compare with the model answer and mark yourself honestly.';
  @override
  String get iGotItRight => 'I got it right';
  @override
  String get iGotItWrong => 'I got it wrong';
  @override
  String get next => 'Next';
  @override
  String get finish => 'Finish';
  @override
  String questionXofY(int x, int y) => 'Question $x of $y';
  @override
  String get sessionComplete => 'Practice complete';
  @override
  String scoreLine(int correct, int total) => '$correct of $total correct';
  @override
  String get retryWrong => 'Retry wrong answers';
  @override
  String get reviewAnswers => 'Review answers';
  @override
  String get done => 'Done';
  @override
  String get yourAnswer => 'Your answer';
  @override
  String get correctOptionLabel => 'Correct answer';
  @override
  String get markedRight => 'Marked right';
  @override
  String get markedWrong => 'Marked wrong';
  @override
  String get saveQuestion => 'Save question';
  @override
  String get questionSaved => 'Saved for revision';
  @override
  String retryMistakes(int n) => 'Retry mistakes · $n';
  @override
  String get noQuestionsForFilter => 'No questions match these filters.';
  @override
  String get onlyUnanswered => 'Not yet answered';
  @override
  String get solutionSteps => 'Solution';
  @override
  String get attemptedLabel => 'Attempted';
  @override
  String get correctLabel => 'Correct now';
  @override
  String get accuracyLabel => 'Accuracy';
  @override
  String get remainingLabel => 'Remaining';
  @override
  String get selfMarkedNote => 'Written answers are marked by you.';

  @override
  String get revision => 'Revision';
  @override
  String get revisionHint => 'Topics, mistakes and saved items to go over again';
  @override
  String get topicsToRevise => 'Topics to revise';
  @override
  String get mistakesToFix => 'Mistakes to fix';
  @override
  String get savedQuestions => 'Saved questions';
  @override
  String get savedFormulas => 'Saved formulas';
  @override
  String get needsPractice => 'Needs more practice';
  @override
  String get needsPracticeHint => 'Topics where under 60% of your answers were correct (at least 3 answers).';
  @override
  String get markRevised => 'Mark revised';
  @override
  String get revised => 'Revised';
  @override
  String get practiseMistakes => 'Practise mistakes';
  @override
  String get practiseSaved => 'Practise saved questions';
  @override
  String revisionDone(int done, int total) => '$done of $total revision items done';
  @override
  String get nothingToRevise => 'Nothing to revise yet';
  @override
  String get nothingToReviseHint =>
      'Mark a topic “Revise again”, save questions or formulas, or practise questions — anything you get wrong appears here.';
  @override
  String get noMistakes => 'No mistakes to fix.';
  @override
  String get noSavedQuestions => 'No saved questions. Tap the bookmark on a question to save it.';
  @override
  String get noSavedFormulas => 'No saved formulas. Tap the bookmark beside a formula to save it.';
  @override
  String get noTopicsToRevise => 'No topics marked “Revise again”.';
  @override
  String accuracyShort(int percent, int answers) => '$percent% of $answers ${_plural(answers, 'answer', 'answers')}';
  @override
  String get saveFormula => 'Save formula';
  @override
  String get formulaSaved => 'Formula saved';
  @override
  String get fixedMistakes => 'Fixed since';

  @override
  String get studyTimer => 'Study timer';
  @override
  String get studyTimerHint => 'Focus on a class, chapter, topic or practical';
  @override
  String get whatAreYouStudying => 'What are you studying?';
  @override
  String get wholeClass => 'Whole class';
  @override
  String get chooseChapter => 'Chapter';
  @override
  String get chooseTopic => 'Topic';
  @override
  String get choosePractical => 'Practical';
  @override
  String get anyChapter => 'Any chapter';
  @override
  String get anyTopic => 'Whole chapter';
  @override
  String get noPractical => 'None';
  @override
  String get lengthLabel => 'Session length';
  @override
  String get custom => 'Custom';
  @override
  String minutes(int n) => '$n min';
  @override
  String get breakLabel => 'Break after session';
  @override
  String get dailyGoal => 'Daily focus goal';
  @override
  String get startSession => 'Start session';
  @override
  String get pause => 'Pause';
  @override
  String get resume => 'Resume';
  @override
  String get endSession => 'End session';
  @override
  String get endSessionTitle => 'End this session now?';
  @override
  String get endSessionBody => 'The time you have focused so far is saved as an early-ended session.';
  @override
  String get keepGoing => 'Keep going';
  @override
  String get sessionDone => 'Session complete!';
  @override
  String focusedFor(String time) => 'You focused for $time.';
  @override
  String takeBreak(int minutes) => 'Take a $minutes-min break';
  @override
  String get skipBreak => 'Skip break';
  @override
  String get onBreak => 'Break time';
  @override
  String get breakOver => 'Break over — ready for another session?';
  @override
  String get backToStudy => 'Back to studying';
  @override
  String get today => 'Today';
  @override
  String get thisWeek => 'Last 7 days';
  @override
  String goalProgress(int done, int goal) => '$done / $goal min';
  @override
  String get goalReached => 'Goal reached';
  @override
  String get history => 'Session history';
  @override
  String get noSessionsYet => 'No focus sessions yet.';
  @override
  String studyStatus(StudySessionStatus s) => switch (s) {
        StudySessionStatus.completed => 'Completed',
        StudySessionStatus.ended => 'Ended early',
        StudySessionStatus.interrupted => 'Interrupted',
      };
  @override
  String get backgroundNote =>
      'The timer pauses if you leave the app. If the app is closed, the time up to that moment is saved as an interrupted session.';
  @override
  String get studyTimeOnTopic => 'Focus time on this topic';
  @override
  String interruptedSaved(String time) => 'A session that was cut off has been saved ($time).';
  @override
  String get focusSettings => 'Focus settings';
  @override
  String get customLength => 'Custom length';
  @override
  String get lengthRange => '5 to 180 minutes';
  @override
  String get labFocus => 'Lab focus';
  @override
  String get studyFocus => 'Study focus';
  @override
  String totalFocus(String time) => 'Total focus: $time';

  @override
  String get studyPath => 'Your study path';
  @override
  String get pathLearn => 'Learn';
  @override
  String get pathNotes => 'My notes';
  @override
  String get pathPractice => 'Practice';
  @override
  String get pathLab => 'Lab';
  @override
  String get pathRevise => 'Revise';
  @override
  String get recentlyStudied => 'Recently studied';
  @override
  String get unfinishedChapters => 'Unfinished chapters';
  @override
  String revisionItems(int n) => '$n to revise';
  @override
  String focusToday(int done, int goal) => '$done/$goal min today';
  @override
  String get savedForLater => 'Saved questions & formulas';
  @override
  String get continueTopic => 'Continue';

  @override
  String get questionsGroup => 'Questions';
  @override
  String get formulasGroup => 'Formulas';
  @override
  String get notesGroup => 'My notes';

  @override
  String get tutorialTitle => 'How the lab works';
  @override
  String get tutorialWelcome => 'Welcome to the virtual lab!';
  @override
  String get tutorialWelcomeBody => 'In one minute you will learn how to do an experiment here. This is only practice — nothing is saved.';
  @override
  String get tutorialShelf => 'The chemical shelf';
  @override
  String get tutorialShelfBody => 'Bottles sit on the shelf at the bottom. Tap a bottle to see its name and safety note.';
  @override
  String get tutorialBeaker => 'The workstation';
  @override
  String get tutorialBeakerBody => 'The beaker in the middle is your workstation. Everything you add goes in here.';
  @override
  String get tutorialProgress => 'Your goal and progress';
  @override
  String get tutorialProgressBody => 'The bar at the top tells you what to add next and how many steps are done.';
  @override
  String get tutorialDemo => 'Watch: drag a bottle';
  @override
  String get tutorialDemoBody => 'Press and hold a bottle, pull it up and drop it on the beaker.';
  @override
  String get tutorialWrong => 'Right and wrong chemicals';
  @override
  String get tutorialWrongBody => 'The right chemical is poured in. A wrong one is refused: the beaker shakes and you are told why. Nothing changes, so you can try again.';
  @override
  String get tutorialReset => 'Reset';
  @override
  String get tutorialResetBody => 'The ↺ button in the top bar empties the beaker and starts the experiment again.';
  @override
  String get tutorialComplete => 'Finishing';
  @override
  String get tutorialCompleteBody => 'When every step is done you see the result, the equation and what you learned, and you can repeat it.';
  @override
  String get tutorialTry => 'Your turn';
  @override
  String tutorialTryBody(String chemical) => 'Drag $chemical into the beaker.';
  @override
  String get tutorialTryWrong => 'Not that one';
  @override
  String tutorialTryWrongBody(String picked, String expected) => '$picked is not needed for this step. Look for $expected.';
  @override
  String get tutorialWellDone => 'Well done!';
  @override
  String get tutorialWellDoneBody => 'That is all you need. Open Help (?) in any lab to see this again.';
  @override
  String get tutorialPracticeOnly => 'Practice only — not saved';
  @override
  String get skip => 'Skip';
  @override
  String get continueLabel => 'Continue';
  @override
  String get replay => 'Replay';
  @override
  String get replayTutorial => 'How to use the lab';
  @override
  String get startLab => 'Start the lab';
  @override
  String get vivaTitle => '🎤 Viva questions';
  @override
  String get vivaHint => 'Questions an examiner may ask. Say your answer first, then tap to check.';
  @override
  String get vivaShowAnswer => 'Answer';
  @override
  String vivaCount(int n) => n == 1 ? '1 viva question' : '$n viva questions';
  @override
  String stepNofM(int n, int m) => '$n / $m';

  @override
  String get practicalStatusTitle => 'Practical status';
  @override
  String get practicalStatusHint => 'Every practical in the board list for this class, and how much of it the app can do.';
  @override
  String practicalLevel(PracticalLevel level) => switch (level) {
        PracticalLevel.fullyInteractive => 'Fully interactive',
        PracticalLevel.partiallyInteractive => 'Partially interactive',
        PracticalLevel.guideOnly => 'Guide only',
        PracticalLevel.notImplemented => 'Not in the app yet',
      };
  @override
  String practicalLevelHint(PracticalLevel level) => switch (level) {
        PracticalLevel.fullyInteractive => 'Every part can be done in a virtual lab.',
        PracticalLevel.partiallyInteractive => 'Some parts can be done in a virtual lab; the rest is not simulated.',
        PracticalLevel.guideOnly => 'A written guide only.',
        PracticalLevel.notImplemented => 'No guide or lab yet.',
      };
  @override
  String get coveredBy => 'Virtual labs';
  @override
  String get notCovered => 'Not simulated';
  @override
  String practicalCountLine(int full, int partial, int guide, int none) =>
      '$full fully interactive · $partial partly · $guide guide only · $none not yet';
}

class HiStudyStrings extends StudyStrings {
  const HiStudyStrings();

  @override
  String statusName(TopicStatus s) => switch (s) {
        TopicStatus.notStarted => 'शुरू नहीं किया',
        TopicStatus.inProgress => 'पढ़ रहे हैं',
        TopicStatus.completed => 'पूरा',
        TopicStatus.reviseAgain => 'फिर दोहराना है',
      };
  @override
  String get statusTitle => 'आपकी स्थिति';
  @override
  String get markCompleted => 'पूरा करें';
  @override
  String get markReviseAgain => 'फिर दोहराना है';
  @override
  String get markInProgress => 'पढ़ रहे हैं';
  @override
  String get completionRule =>
      'कोई विषय तब पढ़ा हुआ गिना जाता है जब आप उसे "पूरा" या "फिर दोहराना है" चिह्नित करें। उप-विषयों वाला विषय तब भी गिना जाता है जब उसके सभी उप-विषय चिह्नित हों। प्रश्नों की सटीकता अलग दिखाई जाती है।';
  @override
  String topicsStudied(int done, int total) => '$total में से $done विषय पढ़े';
  @override
  String get chapterProgressTitle => 'अध्याय की प्रगति';
  @override
  String get noTopicsToTrack => 'यह अध्याय एक इकाई के रूप में पढ़ा जाता है।';
  @override
  String get previousTopic => 'पिछला';
  @override
  String get nextTopic => 'अगला';
  @override
  String partOfTopic(String number) => 'विषय $number का भाग';
  @override
  String get openTopic => 'विषय खोलें';

  @override
  String get whatsHere => 'इस विषय में';
  @override
  String get contentExplanation => 'व्याख्या';
  @override
  String get contentKeyPoints => 'मुख्य बिंदु';
  @override
  String get contentQuickRevision => 'त्वरित दोहराव';
  @override
  String get contentMemoryTricks => 'याद रखने की ट्रिक';
  @override
  String get contentFormulas => 'सूत्र';
  @override
  String get contentExamples => 'दैनिक जीवन के उदाहरण';
  @override
  String contentPractice(int n) => '$n अभ्यास प्रश्न';
  @override
  String contentPyqs(int n) => '$n पिछले वर्षों के प्रश्न';
  @override
  String get contentPracticals => 'संबंधित प्रयोग';
  @override
  String get notAvailableYet => 'अभी नहीं जोड़ा गया';
  @override
  String get availabilityNote => 'धूसर चीज़ें इस विषय के लिए अभी ऐप में नहीं हैं।';

  @override
  String get myNotes => 'मेरे नोट्स';
  @override
  String get myNotesHint => 'आपके अपने नोट्स — हिंदी, अंग्रेज़ी या हिंग्लिश में। केवल इस फ़ोन पर सहेजे जाते हैं।';
  @override
  String get addNote => 'नोट जोड़ें';
  @override
  String get newNote => 'नया नोट';
  @override
  String get editNote => 'नोट बदलें';
  @override
  String get noteFieldHint => 'अपने शब्दों में लिखें — हिंदी, अंग्रेज़ी या हिंग्लिश…';
  @override
  String get noteSaved => 'सहेजा गया';
  @override
  String get noteSaving => 'सहेजा जा रहा है…';
  @override
  String get deleteNote => 'नोट हटाएँ';
  @override
  String get deleteNoteTitle => 'यह नोट हटाएँ?';
  @override
  String get deleteNoteBody => 'यह इस फ़ोन से हट जाएगा। इसे वापस नहीं लाया जा सकता।';
  @override
  String get delete => 'हटाएँ';
  @override
  String get pin => 'पिन करें';
  @override
  String get unpin => 'पिन हटाएँ';
  @override
  String get favourite => 'पसंदीदा';
  @override
  String get unfavourite => 'पसंदीदा से हटाएँ';
  @override
  String get noNotesYet => 'अभी कोई नोट नहीं';
  @override
  String get noNotesHint => 'जो समझा, उसे अपने शब्दों में लिखें। आपके नोट्स केवल आप देख सकते हैं।';
  @override
  String get allNotes => 'सभी';
  @override
  String get pinned => 'पिन किए';
  @override
  String get favourites => 'पसंदीदा';
  @override
  String get searchNotes => 'अपने नोट्स में खोजें';
  @override
  String noNotesMatch(String q) => 'किसी नोट में “$q” नहीं है';
  @override
  String get personalNoteLabel => 'आपका नोट — जाँची गई सामग्री नहीं';
  @override
  String notesCount(int n) => '$n नोट';
  @override
  String get backupNotes => 'नोट्स का बैकअप';
  @override
  String get backupNotesBody =>
      'यह बैकअप टेक्स्ट कॉपी करके किसी सुरक्षित जगह रखें (जैसे खुद को भेज दें)। "पुनः प्राप्त करें" से इसे वापस चिपका सकते हैं।';
  @override
  String get copyBackup => 'बैकअप कॉपी करें';
  @override
  String get backupCopied => 'बैकअप कॉपी हो गया';
  @override
  String get restoreNotes => 'नोट्स पुनः प्राप्त करें';
  @override
  String get restoreNotesBody => '"नोट्स का बैकअप" से बना बैकअप चिपकाएँ। इस फ़ोन के नोट्स बने रहते हैं; केवल नई प्रतियाँ उन्हें बदलती हैं।';
  @override
  String get restore => 'पुनः प्राप्त करें';
  @override
  String notesRestored(int n) => '$n नोट पुनः प्राप्त हुए';
  @override
  String get notABackup => 'यह टेक्स्ट नोट्स का बैकअप नहीं है।';
  @override
  String get wholeChapter => 'पूरा अध्याय';
  @override
  String unreadableNotesKept(int n) => '$n सहेजे गए नोट इस संस्करण में पढ़े नहीं जा सके; वे सुरक्षित रखे गए हैं।';
  @override
  String editedOn(String date) => '$date को बदला';

  @override
  String get practiseTopic => 'इस विषय का अभ्यास करें';
  @override
  String get practiseOneByOne => 'एक-एक करके अभ्यास';
  @override
  String get chapterTest => 'अध्याय परीक्षण';
  @override
  String chapterTestHint(int n) => 'पूरे अध्याय से अधिकतम $n मिले-जुले प्रश्न';
  @override
  String get allDifficulties => 'सभी स्तर';
  @override
  String get difficultyLabel => 'कठिनाई';
  @override
  String get typeLabel => 'प्रकार';
  @override
  String questionsAvailable(int n) => '$n प्रश्न';
  @override
  String practiceStats(int attempted, int total, String accuracy) => '$total में से $attempted हल किए · $accuracy सटीकता';
  @override
  String get notAttemptedYet => 'अभी हल नहीं किया';
  @override
  String get checkAnswer => 'उत्तर जाँचें';
  @override
  String get showModelAnswer => 'आदर्श उत्तर देखें';
  @override
  String get selfCheckHint => 'पहले अपनी कॉपी में उत्तर लिखें, फिर आदर्श उत्तर से मिलाएँ और ईमानदारी से खुद को अंक दें।';
  @override
  String get iGotItRight => 'मेरा सही था';
  @override
  String get iGotItWrong => 'मेरा गलत था';
  @override
  String get next => 'अगला';
  @override
  String get finish => 'समाप्त';
  @override
  String questionXofY(int x, int y) => 'प्रश्न $x / $y';
  @override
  String get sessionComplete => 'अभ्यास पूरा';
  @override
  String scoreLine(int correct, int total) => '$total में से $correct सही';
  @override
  String get retryWrong => 'गलत उत्तर दोबारा करें';
  @override
  String get reviewAnswers => 'उत्तर देखें';
  @override
  String get done => 'हो गया';
  @override
  String get yourAnswer => 'आपका उत्तर';
  @override
  String get correctOptionLabel => 'सही उत्तर';
  @override
  String get markedRight => 'सही चिह्नित';
  @override
  String get markedWrong => 'गलत चिह्नित';
  @override
  String get saveQuestion => 'प्रश्न सहेजें';
  @override
  String get questionSaved => 'दोहराने के लिए सहेजा';
  @override
  String retryMistakes(int n) => 'गलतियाँ दोबारा · $n';
  @override
  String get noQuestionsForFilter => 'इन फ़िल्टरों से कोई प्रश्न नहीं मिला।';
  @override
  String get onlyUnanswered => 'अभी हल नहीं किए';
  @override
  String get solutionSteps => 'हल';
  @override
  String get attemptedLabel => 'हल किए';
  @override
  String get correctLabel => 'अभी सही';
  @override
  String get accuracyLabel => 'सटीकता';
  @override
  String get remainingLabel => 'बाकी';
  @override
  String get selfMarkedNote => 'लिखित उत्तरों को आप स्वयं जाँचते हैं।';

  @override
  String get revision => 'दोहराव';
  @override
  String get revisionHint => 'फिर से दोहराने के लिए विषय, गलतियाँ और सहेजी चीज़ें';
  @override
  String get topicsToRevise => 'दोहराने वाले विषय';
  @override
  String get mistakesToFix => 'सुधारने वाली गलतियाँ';
  @override
  String get savedQuestions => 'सहेजे गए प्रश्न';
  @override
  String get savedFormulas => 'सहेजे गए सूत्र';
  @override
  String get needsPractice => 'और अभ्यास चाहिए';
  @override
  String get needsPracticeHint => 'वे विषय जिनमें आपके 60% से कम उत्तर सही थे (कम से कम 3 उत्तर)।';
  @override
  String get markRevised => 'दोहरा लिया';
  @override
  String get revised => 'दोहराया';
  @override
  String get practiseMistakes => 'गलतियों का अभ्यास';
  @override
  String get practiseSaved => 'सहेजे प्रश्नों का अभ्यास';
  @override
  String revisionDone(int done, int total) => '$total में से $done दोहराव पूरे';
  @override
  String get nothingToRevise => 'अभी दोहराने को कुछ नहीं';
  @override
  String get nothingToReviseHint =>
      'किसी विषय को "फिर दोहराना है" चिह्नित करें, प्रश्न या सूत्र सहेजें, या प्रश्नों का अभ्यास करें — जो गलत होगा वह यहाँ दिखेगा।';
  @override
  String get noMistakes => 'सुधारने को कोई गलती नहीं।';
  @override
  String get noSavedQuestions => 'कोई प्रश्न सहेजा नहीं गया। प्रश्न पर बुकमार्क दबाकर सहेजें।';
  @override
  String get noSavedFormulas => 'कोई सूत्र सहेजा नहीं गया। सूत्र के पास बुकमार्क दबाकर सहेजें।';
  @override
  String get noTopicsToRevise => 'कोई विषय "फिर दोहराना है" चिह्नित नहीं।';
  @override
  String accuracyShort(int percent, int answers) => '$answers उत्तरों में $percent%';
  @override
  String get saveFormula => 'सूत्र सहेजें';
  @override
  String get formulaSaved => 'सूत्र सहेजा गया';
  @override
  String get fixedMistakes => 'बाद में सुधारी गईं';

  @override
  String get studyTimer => 'अध्ययन टाइमर';
  @override
  String get studyTimerHint => 'किसी कक्षा, अध्याय, विषय या प्रयोग पर ध्यान लगाएँ';
  @override
  String get whatAreYouStudying => 'आप क्या पढ़ रहे हैं?';
  @override
  String get wholeClass => 'पूरी कक्षा';
  @override
  String get chooseChapter => 'अध्याय';
  @override
  String get chooseTopic => 'विषय';
  @override
  String get choosePractical => 'प्रयोग';
  @override
  String get anyChapter => 'कोई भी अध्याय';
  @override
  String get anyTopic => 'पूरा अध्याय';
  @override
  String get noPractical => 'कोई नहीं';
  @override
  String get lengthLabel => 'सत्र की अवधि';
  @override
  String get custom => 'अपनी अवधि';
  @override
  String minutes(int n) => '$n मिनट';
  @override
  String get breakLabel => 'सत्र के बाद विराम';
  @override
  String get dailyGoal => 'रोज़ का फ़ोकस लक्ष्य';
  @override
  String get startSession => 'सत्र शुरू करें';
  @override
  String get pause => 'रोकें';
  @override
  String get resume => 'जारी रखें';
  @override
  String get endSession => 'सत्र समाप्त करें';
  @override
  String get endSessionTitle => 'यह सत्र अभी समाप्त करें?';
  @override
  String get endSessionBody => 'अब तक का फ़ोकस समय "बीच में समाप्त" सत्र के रूप में सहेजा जाएगा।';
  @override
  String get keepGoing => 'जारी रखें';
  @override
  String get sessionDone => 'सत्र पूरा!';
  @override
  String focusedFor(String time) => 'आपने $time ध्यान लगाया।';
  @override
  String takeBreak(int minutes) => '$minutes मिनट का विराम लें';
  @override
  String get skipBreak => 'विराम छोड़ें';
  @override
  String get onBreak => 'विराम का समय';
  @override
  String get breakOver => 'विराम पूरा — एक और सत्र?';
  @override
  String get backToStudy => 'पढ़ाई पर लौटें';
  @override
  String get today => 'आज';
  @override
  String get thisWeek => 'पिछले 7 दिन';
  @override
  String goalProgress(int done, int goal) => '$done / $goal मिनट';
  @override
  String get goalReached => 'लक्ष्य पूरा';
  @override
  String get history => 'सत्रों का इतिहास';
  @override
  String get noSessionsYet => 'अभी कोई फ़ोकस सत्र नहीं।';
  @override
  String studyStatus(StudySessionStatus s) => switch (s) {
        StudySessionStatus.completed => 'पूरा',
        StudySessionStatus.ended => 'बीच में समाप्त',
        StudySessionStatus.interrupted => 'बाधित',
      };
  @override
  String get backgroundNote =>
      'ऐप छोड़ने पर टाइमर रुक जाता है। ऐप बंद हो जाए तो उस समय तक का समय "बाधित" सत्र के रूप में सहेजा जाता है।';
  @override
  String get studyTimeOnTopic => 'इस विषय पर फ़ोकस समय';
  @override
  String interruptedSaved(String time) => 'बीच में कटा एक सत्र सहेजा गया ($time)।';
  @override
  String get focusSettings => 'फ़ोकस सेटिंग';
  @override
  String get customLength => 'अपनी अवधि';
  @override
  String get lengthRange => '5 से 180 मिनट';
  @override
  String get labFocus => 'लैब फ़ोकस';
  @override
  String get studyFocus => 'अध्ययन फ़ोकस';
  @override
  String totalFocus(String time) => 'कुल फ़ोकस: $time';

  @override
  String get studyPath => 'आपका अध्ययन पथ';
  @override
  String get pathLearn => 'पढ़ें';
  @override
  String get pathNotes => 'मेरे नोट्स';
  @override
  String get pathPractice => 'अभ्यास';
  @override
  String get pathLab => 'लैब';
  @override
  String get pathRevise => 'दोहराएँ';
  @override
  String get recentlyStudied => 'हाल में पढ़े';
  @override
  String get unfinishedChapters => 'अधूरे अध्याय';
  @override
  String revisionItems(int n) => '$n दोहराने हैं';
  @override
  String focusToday(int done, int goal) => 'आज $done/$goal मिनट';
  @override
  String get savedForLater => 'सहेजे प्रश्न और सूत्र';
  @override
  String get continueTopic => 'जारी रखें';

  @override
  String get questionsGroup => 'प्रश्न';
  @override
  String get formulasGroup => 'सूत्र';
  @override
  String get notesGroup => 'मेरे नोट्स';

  @override
  String get tutorialTitle => 'लैब कैसे काम करती है';
  @override
  String get tutorialWelcome => 'वर्चुअल लैब में स्वागत है!';
  @override
  String get tutorialWelcomeBody => 'एक मिनट में सीखें कि यहाँ प्रयोग कैसे करते हैं। यह केवल अभ्यास है — कुछ भी सहेजा नहीं जाता।';
  @override
  String get tutorialShelf => 'रसायनों की शेल्फ़';
  @override
  String get tutorialShelfBody => 'बोतलें नीचे शेल्फ़ पर रखी हैं। बोतल का नाम और सुरक्षा नोट देखने के लिए उसे दबाएँ।';
  @override
  String get tutorialBeaker => 'कार्यस्थल';
  @override
  String get tutorialBeakerBody => 'बीच का बीकर आपका कार्यस्थल है। जो कुछ भी आप डालेंगे, वह इसी में जाएगा।';
  @override
  String get tutorialProgress => 'आपका लक्ष्य और प्रगति';
  @override
  String get tutorialProgressBody => 'ऊपर की पट्टी बताती है कि आगे क्या डालना है और कितने चरण पूरे हुए।';
  @override
  String get tutorialDemo => 'देखें: बोतल खींचें';
  @override
  String get tutorialDemoBody => 'बोतल को दबाकर रखें, ऊपर खींचें और बीकर पर छोड़ दें।';
  @override
  String get tutorialWrong => 'सही और गलत रसायन';
  @override
  String get tutorialWrongBody => 'सही रसायन बीकर में डल जाता है। गलत रसायन स्वीकार नहीं होता: बीकर हिलता है और कारण बताया जाता है। कुछ नहीं बदलता, इसलिए आप फिर कोशिश कर सकते हैं।';
  @override
  String get tutorialReset => 'रीसेट';
  @override
  String get tutorialResetBody => 'ऊपर की पट्टी का ↺ बटन बीकर खाली करके प्रयोग फिर से शुरू करता है।';
  @override
  String get tutorialComplete => 'प्रयोग पूरा होने पर';
  @override
  String get tutorialCompleteBody => 'सभी चरण पूरे होने पर परिणाम, समीकरण और सीखी बात दिखती है, और आप प्रयोग दोहरा सकते हैं।';
  @override
  String get tutorialTry => 'अब आपकी बारी';
  @override
  String tutorialTryBody(String chemical) => '$chemical को बीकर में खींचकर डालें।';
  @override
  String get tutorialTryWrong => 'यह नहीं';
  @override
  String tutorialTryWrongBody(String picked, String expected) => 'इस चरण में $picked की आवश्यकता नहीं है। $expected ढूँढें।';
  @override
  String get tutorialWellDone => 'बहुत बढ़िया!';
  @override
  String get tutorialWellDoneBody => 'बस इतना ही जानना है। इसे फिर देखने के लिए किसी भी लैब में सहायता (?) खोलें।';
  @override
  String get tutorialPracticeOnly => 'केवल अभ्यास — सहेजा नहीं जाता';
  @override
  String get skip => 'छोड़ें';
  @override
  String get continueLabel => 'आगे';
  @override
  String get replay => 'फिर देखें';
  @override
  String get replayTutorial => 'लैब का उपयोग कैसे करें';
  @override
  String get startLab => 'लैब शुरू करें';
  @override
  String get vivaTitle => '🎤 मौखिकी (वाइवा) प्रश्न';
  @override
  String get vivaHint => 'परीक्षक द्वारा पूछे जा सकने वाले प्रश्न। पहले स्वयं उत्तर बोलें, फिर जाँचने के लिए दबाएँ।';
  @override
  String get vivaShowAnswer => 'उत्तर';
  @override
  String vivaCount(int n) => '$n वाइवा प्रश्न';
  @override
  String stepNofM(int n, int m) => '$n / $m';

  @override
  String get practicalStatusTitle => 'प्रयोगों की स्थिति';
  @override
  String get practicalStatusHint => 'इस कक्षा की बोर्ड सूची का हर प्रयोग, और ऐप उसका कितना भाग करा सकता है।';
  @override
  String practicalLevel(PracticalLevel level) => switch (level) {
        PracticalLevel.fullyInteractive => 'पूरी तरह इंटरैक्टिव',
        PracticalLevel.partiallyInteractive => 'आंशिक रूप से इंटरैक्टिव',
        PracticalLevel.guideOnly => 'केवल मार्गदर्शिका',
        PracticalLevel.notImplemented => 'अभी ऐप में नहीं',
      };
  @override
  String practicalLevelHint(PracticalLevel level) => switch (level) {
        PracticalLevel.fullyInteractive => 'हर भाग वर्चुअल लैब में किया जा सकता है।',
        PracticalLevel.partiallyInteractive => 'कुछ भाग वर्चुअल लैब में किए जा सकते हैं; बाकी का अनुकरण नहीं है।',
        PracticalLevel.guideOnly => 'केवल लिखित मार्गदर्शिका।',
        PracticalLevel.notImplemented => 'अभी कोई मार्गदर्शिका या लैब नहीं।',
      };
  @override
  String get coveredBy => 'वर्चुअल लैब';
  @override
  String get notCovered => 'अनुकरण नहीं';
  @override
  String practicalCountLine(int full, int partial, int guide, int none) =>
      '$full पूरी तरह इंटरैक्टिव · $partial आंशिक · $guide केवल मार्गदर्शिका · $none अभी नहीं';
}

extension StudyStringsContext on BuildContext {
  /// Current study strings; rebuilds the caller when the language changes.
  StudyStrings get study => StudyStrings.of(watch<LanguageController>().language);

  /// Current study strings without subscribing – for event handlers.
  StudyStrings get readStudy => StudyStrings.of(read<LanguageController>().language);
}
