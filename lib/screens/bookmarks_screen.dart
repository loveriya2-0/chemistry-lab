import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../state/app_state.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';
import 'topic_detail_screen.dart';
import 'topic_list_screen.dart';

/// Saved topics and labs (PYQs once they exist). Entries whose topic is no
/// longer in the syllabus are skipped rather than shown broken.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final store = context.watch<BookmarkStore>();
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
    final labs = context.read<PracticalsRepository>();
    final topics = [for (final id in store.topicIds) ?curriculum.topic(id)];
    final savedLabs = [
      for (final (topicId, labId) in store.labs)
        if (curriculum.topic(topicId) case final loc? when curriculum.labsForTopic(topicId).contains(labId)) (loc, labId),
    ];

    Widget empty() => Padding(
          padding: const EdgeInsets.all(16),
          child: ComingSoonPanel(icon: Icons.bookmark_border_rounded, title: s.bookmarksEmpty, body: s.bookmarksEmptyHint),
        );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.bookmarks),
          actions: const [LanguageToggle()],
          bottom: TabBar(tabs: [Tab(text: s.topicsGroup), Tab(text: s.labsTab), Tab(text: s.pyqsTab)]),
        ),
        body: TabBarView(
          children: [
            topics.isEmpty
                ? ListView(children: [empty()])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final loc in topics)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const IconTile(icon: Icons.topic_rounded, color: LabColors.teal, size: 36),
                            title: Text(s.ct(loc.topic.title), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${s.className(loc.syllabus.classLevel)} · ${s.ct(loc.chapter.title)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              tooltip: s.bookmarked,
                              onPressed: () => store.toggle(BookmarkStore.topicKey(loc.topic.id)),
                              icon: const Icon(Icons.bookmark_rounded, color: LabColors.primary),
                            ),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => TopicDetailScreen(
                                syllabus: loc.syllabus,
                                chapter: loc.chapter,
                                topic: loc.chapter.topics.firstWhere((t) => t.selfAndDescendants.contains(loc.topic)),
                              ),
                            )),
                          ),
                        ),
                    ],
                  ),
            savedLabs.isEmpty
                ? ListView(children: [empty()])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final (loc, labId) in savedLabs)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: IconTile(icon: labs.byId(labId).icon, color: labs.byId(labId).accent, size: 36),
                            title: Text(s.tr(labs.byId(labId).title), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(s.focusBreadcrumb(loc.syllabus.classLevel, loc.chapter.number, loc.topic.number)),
                            trailing: IconButton(
                              tooltip: s.bookmarked,
                              onPressed: () => store.toggle(BookmarkStore.labKey(loc.topic.id, labId)),
                              icon: const Icon(Icons.bookmark_rounded, color: LabColors.primary),
                            ),
                            onTap: () => openLabsForTopic(context, syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
                          ),
                        ),
                    ],
                  ),
            ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ComingSoonPanel(icon: Icons.history_edu_rounded, title: s.noPyqsYet, body: s.pyqsBeingAdded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
