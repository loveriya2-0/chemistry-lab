import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/gemini_tutor_service.dart';
import 'ai/tutor_service.dart';
import 'content/content_catalog.dart';
import 'content/content_repository.dart';
import 'content/legacy_migration.dart';
import 'core/theme.dart';
import 'data/bookmark_store.dart';
import 'data/focus_session_store.dart';
import 'data/practical_attempt_store.dart';
import 'data/practicals_repository.dart';
import 'l10n/app_language.dart';
import 'lab/reaction_labs.dart';
import 'l10n/app_strings.dart';
import 'premium/billing_gateway.dart';
import 'premium/premium_config.dart';
import 'premium/premium_controller.dart';
import 'premium/purchase_verifier.dart';
import 'screens/board_selection_screen.dart';
import 'screens/main_shell.dart';
import 'state/app_state.dart';
import 'state/language_controller.dart';
import 'study/personal_notes_store.dart';
import 'study/study_focus.dart';
import 'study/study_progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final catalog = await ContentCatalog.load(ContentRepository());
  await migrateLegacyProgress(prefs, catalog);
  // A study session cut off by the app closing is saved as interrupted.
  await StudySessionStore(prefs).recoverInterrupted();
  runApp(VirtualChemistryLabApp(prefs: prefs, catalog: catalog));
}

/// Moves progress saved under draft curriculum ids onto the verified ids.
/// Runs once; nothing is deleted.
Future<int> migrateLegacyProgress(SharedPreferences prefs, ContentCatalog catalog) {
  final map = <String, String?>{
    for (final board in catalog.registry.available)
      ...?catalog.curriculum(board.id)?.manifest.legacyIdMap,
  };
  return LegacyProgressMigration.run(prefs, map);
}

class VirtualChemistryLabApp extends StatelessWidget {
  const VirtualChemistryLabApp({super.key, required this.prefs, required this.catalog, this.tutor, this.billing, this.verifier});

  final SharedPreferences prefs;
  final ContentCatalog catalog;

  /// The AI tutor; by default Gemini or Claude, configured at build time
  /// (see [GeminiConfig] and [TutorConfig]). Tests pass a fake.
  final TutorService? tutor;

  /// Google Play Billing and the purchase-verify server; by default the
  /// real ones, configured at build time (see [PremiumConfig]). Tests pass
  /// fakes.
  final BillingGateway? billing;
  final PurchaseVerifier? verifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: prefs),
        Provider.value(value: catalog),
        Provider(create: (_) => PracticalsRepository(reactionLabs: ReactionLabs.fromCatalog(catalog))),
        ChangeNotifierProvider(create: (_) => AppState(prefs)),
        ChangeNotifierProvider(create: (_) => LanguageController(prefs)),
        Provider(create: (_) => FocusSessionStore(prefs)),
        Provider(create: (_) => PracticalAttemptStore(prefs)),
        ChangeNotifierProvider(create: (_) => BookmarkStore(prefs)),
        ChangeNotifierProvider(create: (_) => PersonalNotesStore(prefs)),
        ChangeNotifierProvider(create: (_) => StudyProgressStore(prefs)),
        ChangeNotifierProvider(create: (_) => FocusSettings(prefs)),
        Provider(create: (_) => StudySessionStore(prefs)),
        Provider<TutorService>(create: (_) => tutor ?? tutorFromEnvironment()),
        // Not lazy: re-checks purchases (restores, refunds) at app start.
        ChangeNotifierProvider(
          lazy: false,
          create: (_) {
            final config = PremiumConfig.fromEnvironment();
            return PremiumController(
              prefs: prefs,
              billing: billing ?? PlayBillingGateway.forPlatform(),
              verifier: verifier ?? HttpPurchaseVerifier(config.verifyUrl),
              productId: config.productId,
            )..start();
          },
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          onGenerateTitle: (context) => context.strings.appName,
          debugShowCheckedModeBanner: false,
          theme: buildLabTheme(),
          // Drives Material's own text (tooltips, back button) too.
          locale: context.watch<LanguageController>().language.locale,
          supportedLocales: [for (final l in AppLanguage.values) l.locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const _Home(),
        ),
      ),
    );
  }
}

/// Board selection until a board with data is chosen, then the tabbed app.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final boardId = context.watch<AppState>().boardId;
    final hasData = boardId != null && context.read<ContentCatalog>().curriculum(boardId) != null;
    return hasData ? const MainShell() : const BoardSelectionScreen();
  }
}
