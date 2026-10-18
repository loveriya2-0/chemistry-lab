# Sources — CBSE Chemistry, 2026–27 (Phase 1 data verification)

Everything in `assets/content/boards/cbse/2026-27/` traces to one of these. Retrieved October 2026.
The app's UI does not read this data yet.

## Primary — CBSE (source of truth for what is in the syllabus)

| id | Document | Used for |
|---|---|---|
| `cbse-sci-9` | CBSE Science (086) Class IX 2026-27 — https://cbseacademic.nic.in/web_material/CurriculumMain27/SecPart1/ScienceSt_SecP1_2026-27.pdf | Class 9 units, marks, chapter numbers, key concepts, practicals (with chapter numbers) |
| `cbse-sci-9-adv` | CBSE Science at Advanced Level (Optional) Grade 9 2026-27 — https://cbseacademic.nic.in/web_material/CurriculumMain27/SecPart1/ScienceAd_SecP1_2026-27.pdf | Existence of the optional advanced track (not loaded yet) |
| `cbse-sci-10` | CBSE Science (086) Class X 2026-27 — https://cbseacademic.nic.in/web_material/CurriculumMain27/SecPart1/Science_SecP1_2026-27.pdf | Class 10 units, marks, chapter topics, formative-only topics, practicals |
| `cbse-sci-10-rm` | CBSE Reading Material, Science Class X 2026-27 — https://cbseacademic.nic.in/web_material/CurriculumMain27/SecPart1/Science_SecP1IX_2026-27_RM.pdf | Text for formative-only "Periodic Classification of Elements" |
| `cbse-chem-11-12` | CBSE Chemistry (043) Classes XI–XII 2026-27 — https://cbseacademic.nic.in/web_material/CurriculumMain27/SecPart2/Chemistry_SecP2_2026-27.pdf | Class 11/12 units, marks per unit, topic lists, formative-only topics, practicals, projects |
| `cbse-chem-rm` | CBSE Reading Material, Chemistry XI–XII 2026-27 — https://cbseacademic.nic.in/web_material/CurriculumMain27/SecPart2/Chemistry_SecP2_2026-27_RM.pdf | Text for formative-only topics (States of Matter, s/p-block, Surface Chemistry, etc.) |
| `cbse-qp` | CBSE previous question papers — https://www.cbse.gov.in/cbsenew/question-paper.html | PYQ availability: Class X Science and Class XII Chemistry papers listed for 2022, 2023, 2024, 2025, 2026 |
| `cbse-ms` | CBSE marking schemes — https://www.cbse.gov.in/cbsenew/marking-scheme.html | Marking schemes listed for the same years (basis for answers/explanations) |

## Primary — NCERT (chapter titles, section/topic titles, Hindi names)

| id | Book (NCERT, Reprint 2026-27 where stated) | Used for |
|---|---|---|
| `ncert-9-en` | Class IX Science **"Exploration"** (new textbook) — https://ncert.nic.in/textbook.php?iesc1=0-13 (iesc1ps.pdf, iesc105/108/109.pdf) | Class 9 chapter titles and section headings |
| `ncert-9-hi` | Class IX विज्ञान **"Anveshan" (अन्वेषण)** — https://ncert.nic.in/textbook.php?ihsc1=0-13 (ihsc105/108/109.pdf) | Class 9 Hindi chapter and section titles |
| `ncert-10-en` | Class X Science, Reprint 2026-27 — https://ncert.nic.in/textbook.php?jesc1=0-13 (jesc1ps.pdf, jesc101–104.pdf) | Class 10 chapter titles and section headings |
| `ncert-10-hi` | Class X विज्ञान — https://ncert.nic.in/textbook.php?jhsc1=0-13 (jhsc1ps.pdf, jhsc101–104.pdf) | Class 10 Hindi chapter and section titles |
| `ncert-11-en` | Chemistry Part I & II, Class XI, Reprint 2026-27 — kech1=0-6, kech2=0-3 | Class 11 unit titles and section headings |
| `ncert-11-hi` | रसायन विज्ञान भाग I & II, Class XI — khch1, khch2 | Class 11 Hindi unit titles (decoded from legacy KrutiDev font — proofread before release) |
| `ncert-12-en` | Chemistry Part I & II, Class XII, Reprint 2026-27 — lech1=0-5, lech2=0-5 | Class 12 unit titles and section headings |
| `ncert-12-hi` | रसायन विज्ञान भाग I & II, Class XII — lhch1, lhch2 | Class 12 Hindi unit titles (decoded from legacy KrutiDev font — proofread before release) |

## Secondary (context only — not used for any data value)

- News reports on the April 2021 cancellation of Class 10 board exams (COVID-19), e.g. https://www.etvbharat.com/amp/english/bharat/cbse-cancels-class-10-board-exams-postpones-class-12-exams/na20210414140155065
- News reports on two Class 10 board exams from 2026 (February mandatory, May optional), e.g. https://news.careers360.com/twice-year-board-exams-for-class-10-from-2026-phase-1-mandatory-phase-2-optional-cbse
- Third-party solution sites (Allen, Extramarks) only to cross-check that "Exploration" Chapter 5 is "Exploring Mixtures and their Separation".

## Hindi provenance flags (`hiSrc`)

- `"hiSrc": "ncert"` — copied from the NCERT Hindi textbook (Unicode), with extraction glitches fixed (matra order).
- `"hiSrc": "ncert-decoded"` — decoded from the NCERT Hindi PDF's legacy font; needs a proofread.
- `"hiSrc": "translated"` — no official Hindi found; written by us; **needs review** by a Hindi-medium teacher.

## Phase 4 — learning content (Classes 9–10)

Notes, concepts, chemicals and practice questions were written by us from the NCERT
chapter text (downloaded and read in October 2026):

- Class 9 "Exploration" (new book): iesc105, iesc108, iesc109 — https://ncert.nic.in/textbook/pdf/iesc1NN.pdf
- Class 10 Science, Reprint 2026-27: jesc101–jesc104 — https://ncert.nic.in/textbook/pdf/jesc10N.pdf
- Periodic Classification (formative only): CBSE Reading Material `cbse-sci-10-rm`.

Each note/concept/chemical/question cites `sourceId` + section. Notable reprint detail
followed: bleaching powder is written Ca(ClO)₂ with 2Ca(OH)₂ + 2Cl₂ → Ca(ClO)₂ + CaCl₂ + 2H₂O.

All Hindi in this phase is ours (`hiSrc: translated`) using NCERT Hindi-medium terms,
and needs review by a Hindi-medium teacher. Status `sourceChecked` = checked against
the source text by us, not yet teacher-reviewed.

### PYQs entered (Class 10 Science 086, main exam, chemistry questions only)

| Year | Set | Paper | Marking scheme | Questions |
|---|---|---|---|---|
| 2023 | 31/2/1 | question-paper/2023/X/SCIENCE.zip | Marking-Scheme/2023/X/Science_English_Medium.zip (X_086_31_2_MS) | 1–7, 17, 21, 27, 28, 34, 37 |
| 2024 | 31/1/1 | question-paper/2024/X/SCIENCE.zip | Marking-Scheme/2024/X/Science.zip (set 1) | 1–7, 17, 21, 27, 28, 34, 37 |
| 2025 | 31/1/1 | question-paper/2025/X/086_Science.zip | Marking-Scheme/2025/X/Science.zip (31-1-1 to 3) | 1–7, 17, 21, 27, 28, 34, 37 |
| 2026 | 31/2/1 | question-paper/2026/X/Science.zip | marking-scheme/2026/X/086_SCIENCE.zip (Set 2) | 17–29 (Section B Chemistry) |

All under https://www.cbse.gov.in/cbsenew/. Question wording is summarised in our words
(Hindi ours); answers follow the marking scheme. One set per year only — other sets,
2022 (term papers), compartment and 2026 second-exam papers are not entered, so
importance levels describe these four papers, not the whole exam. 2025 Q7 and Q21 rely
on diagrams; the summaries point to the official paper for them.
