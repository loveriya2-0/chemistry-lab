# Multi-board data architecture

Board → Class → Subject → Chapter → Topic → Practical → Concepts → Reactions → Exam/PYQ.
Implemented in `lib/content/` (data layer only — no UI uses it yet) with data in
`assets/content/`. Tests: `test/content_test.dart`.

## Files

```
assets/content/
  boards.json                         registry: 20 boards; status available | comingSoon
  boards/<boardId>/<academicYear>/
    manifest.json                     classes, sources, concept + PYQ file lists, legacy id map
    class-9.json … class-12.json      one independent file per class
  (future) concepts/<id>.json         shared, board-independent concept/reaction library
  (future) pyq/<boardId>/<file>.json  questions referenced from official papers
```

Adding a board = add its folder + set it `available` in `boards.json` (and list
the folder under `assets:` in pubspec.yaml). No Dart change, no change to any
other board's files. Each board/year is a separate syllabus: its own chapter
names, order, numbering, units, marks, exam pattern, practicals and class labels
(e.g. "I PUC", "Intermediate 1st year" via `label`; `classLevel` stays 9–12).

## Rules enforced by `ContentValidator` (run in tests)

- Board ids unique; an `available` board has ≥1 syllabus; a `comingSoon` board has
  **none** (so no fake chapters/PYQs can appear for it).
- Ids unique within a syllabus; every chapter ↔ practical link resolves.
- Exam chapters have marks; formative-only chapters carry none.
- Unit-scoped marks match their unit; chapter-scoped marks add up to the theory total.
- Every chapter has a Hindi title; every source is an https link.

## Entities (Dart: `lib/content/models/`)

| Entity | Notes |
|---|---|
| `Board`, `BoardRegistry` | id, display name {en, hi}, scope (national/state), state, status, `officialName` (null until verified from the board), curricula[] |
| `CurriculumManifest` | one board + academic year: class files, sources, concept/PYQ files, legacy id map |
| `ClassSyllabus` | classLevel, board label, subject {id, code, name}, `ExamPattern`, units, chapters, practicals |
| `Chapter` | number, title, curriculumName, `Assessment` (summative / formativeOnly), `Weightage` (marks + scope: chapter / unit / notInYearEndExam), description, topics, practicalIds, conceptIds |
| `Topic` | number ("2.1"), title, nested subtopics, conceptIds |
| `Practical` | number as in the board list, title, chapterIds, relatedChapterIds, `PracticalMapping` (official / editorial / general), `ReactionRef`s, labId |
| `Concept` | content layer: type, title, 7 learning sections, equations, labIds, sources, review status — **none shipped yet** |
| `PyqQuestion` | board, class, examYear, `ExamAttempt` (main / second / term1 / term2 / compartment), paper code, question no., marks, `QuestionType`, chapter/topic/concepts, `SyllabusStatus`, similarGroupId, our summary + answer, paper and marking-scheme URLs — **none shipped yet** |
| `ExamImportance` | computed from PYQs: distinct years asked, marks, repeated (≥2 years in a reviewer-set group), level by share of years (high ≥ 60 %, medium ≥ 30 %, low > 0) |

All text is `ContentText {en, hi?, hiSrc}`; `hiSrc` = ncert / ncert-decoded /
translated. Missing Hindi falls back to English.

## Hindi provenance (CBSE 2026-27)

- Class 9/10 chapter and topic titles: NCERT Hindi books (Unicode).
- Class 11/12 chapter and topic titles: decoded from the NCERT Hindi PDFs'
  Walkman-Chanakya font with `hindi-decoding/chanakya_to_unicode.js`, proofread by
  hand (`hindi-decoding/class_11_12_topic_titles_proofread.json`). Class 12 §8.9 is
  missing from the Hindi contents page and is marked `translated`.
- Chapter descriptions, practical titles, unit names and board names: written by
  us (`translated`) — need review by a Hindi-medium teacher.

## Migration

Saved progress uses old draft ids; `manifest.legacyIdMap` maps them
(`c10_acids_bases` → `cbse-10-ch02`, …). `c9_matter_pure` has no 2026-27
equivalent and is reported as removed.

## Learning content (Phase 4 — Classes 9 and 10)

```
assets/content/
  library/concepts/*.json          46 board-independent concepts (what / how / why / uses / exam relevance)
  library/chemicals.json           22 chemicals and named reactions (formula, properties, uses, equations)
  boards/cbse/2026-27/
    notes/class-<n>-<chapter>.json 72 topic notes; every Class 9–10 topic (and the topic-less
                                   formative chapter) is explained by exactly one note
    questions/class-9|10.json      85 practice questions written from NCERT (not PYQs)
    pyq/class-10.json              52 PYQs from 4 official CBSE papers
    pyq/class-12.json              134 PYQs: all questions of 4 official Chemistry (043) papers,
                                   2023–2026 (sets 56/1/1, 56/1/1, 56/4/1, 56/1/1), answers
                                   from the official marking schemes
```

Content files are `{"hiSrc": "translated", "items": [...]}`; the file-level `hiSrc` is
applied to every `{en, hi}` text that does not set its own (`ContentRepository.jsonList`).

| Entity | Notes |
|---|---|
| `TopicNote` | targetId (topic or chapter) + `covers` (sub-topics it also explains); definition, simple explanation, key points, real-life, exam focus, common mistakes, formulas, practicalIds, conceptIds, chemicalIds, sources, review |
| `Concept` | sections, equations, relatedConceptIds, `SourceRef`s, review. "Related topics" are found from notes, not stored |
| `ChemicalEntry` | kind (compound / element / reaction), name, formula, properties, uses, equations, explanation, practicalNote |
| `PracticeQuestion` | class, chapter, topic, type (incl. `numerical`), marks, difficulty, question, options + correctOption, answer, explanation |
| `PyqQuestion` | + options/correctOption; must belong to a paper listed in `manifest.pyq.papers` |
| `ReviewStatus` | draft / needsReview / **sourceChecked** (written by us from the cited source and checked against it; not yet teacher-reviewed) / verified. Only sourceChecked and verified are shown, always with a provenance line |

Exam importance = `ExamImportance` over PYQs of the chapter/topic, with the window =
years of the papers actually entered (`LoadedCurriculum.enteredExamYears`), never the
full 2022–2026 availability list. No content file stores importance or weightage.

`ContentValidator.learningContent` (run in `test/learning_content_test.dart`) enforces:
every Class 9–10 topic covered exactly once; all references resolve (topics, chapters,
practicals, concepts, chemicals, sources, papers); English + Hindi on every text, Hindi
actually in Devanagari and with provenance; no placeholder text; marks match question
type (MCQ/AR 1, VSA 2, SA 3, case 4, LA 5); 4 options and a valid answer index for
choice questions; PYQs only for board-exam classes and only from listed papers; every
library entry linked from some note; only checked content published.

## Memory tricks and quick revision (all classes)

Two optional fields on every `TopicNote` (`lib/content/models/topic_note.dart`).
They use the same bilingual `{en, hi}` form as every other text, so the field
`memoryTrick.en` / `.hi` is the English / Hindi trick, and so on:

```json
"memoryTricks": [
  {"trick":  {"en": "isotoPes → same P (protons); isobArs → same A", "hi": "…"},
   "recall": {"en": "What the trick stands for", "hi": "…"}}
],
"quickRevision": {
  "oneLine": {"en": "1-line definition", "hi": "…"},
  "formula": "one formula copied from this note's own formulas (optional)",
  "points":  [{"en": "must-remember point", "hi": "…"}]
}
```

- "Main points" are the existing `keyPoints`; no second copy is stored.
- `memoryTricks` may be absent or empty. Add a trick only where it really helps;
  never force one onto a topic. At most 3 per note.
- Every trick carries its `recall` (meaning), so a mnemonic is never learnt without
  the facts it stands for. Tricks only restate facts already in the note/NCERT.
- Validator rules: English + Devanagari Hindi with provenance; no placeholder or
  template text ("ABC…", "...", "trick goes here", TODO); trick ≠ its meaning;
  quick revision has 1–3 points; its `formula` must be one of the note's `formulas`.
- Notes page order: Definition (concept) → Easy explanation → 🧠 Memory trick →
  ⭐ Main points → 🧪 Reactions & formulas → 🌍 Real-life use → 🎯 Exam importance
  (exam focus + PYQ-based importance) → ⚠️ Common mistakes → ⚡ Quick revision →
  📝 Practice questions. Empty optional sections are hidden.
- Class 9–10 (shipped): all 72 notes have a quick revision; 44 notes carry 52 tricks.
- Teacher review: `dart run tool/export_review_sheets.dart` includes both fields.

## Class 11–12 status (not in the manifest yet, so not shown in the app)

| File(s) | Notes written | Memory tricks / quick revision |
|---|---|---|
| notes/class-11-ch01 … ch09, class-11-formative | 74 (all 72 topics + 2 formative chapters) | not added yet |
| notes/class-12-ch01 … ch03 | 20 (Ch 1–3) | not added yet |

Still to do before Class 11–12 can ship: Class 12 Ch 4–10 notes and 4 formative
chapters; memory tricks + quick revision on all Class 11–12 notes (same structure);
new concept/chemical library entries the notes already reference (e.g. `mole-concept`,
`chemical-equilibrium`, `oxalic-acid`, `potassium-permanganate`); practice questions for
19 chapters; Class 12 PYQs from official papers only; manifest entries; tests for all
four classes. Class 11 has no board exam: practice questions but no PYQs or importance.
