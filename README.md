# virtual_chemistry_lab

Virtual Chemistry Lab: a Flutter app for chemistry notes, practice questions,
PYQs and virtual lab experiments, managed from the Lab Console (`console/`, `api/`).

## Building the APK

The app syncs content from the Lab Console API and reports installs/purchases to it.
The API URL is baked in at build time with `--dart-define`:

| Setting | Value |
|---|---|
| `CONTENT_API_URL` | `https://lab-console-api.wearepartnerha.workers.dev` |

Use the base URL only: the app adds `/api/v1/public/...` itself, so don't append
`/api/v1` or a trailing path. Without `CONTENT_API_URL` the app runs fully offline on
its bundled content.

```sh
flutter pub get

# Release APK (install directly on a phone / share the file)
flutter build apk --release   --dart-define=CONTENT_API_URL=https://lab-console-api.wearepartnerha.workers.dev

# Smaller APKs, one per CPU type (most phones need app-arm64-v8a-release.apk)
flutter build apk --release --split-per-abi   --dart-define=CONTENT_API_URL=https://lab-console-api.wearepartnerha.workers.dev
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (or `app-<abi>-release.apk`).
Install on a connected phone with `flutter install` or `adb install <file>.apk`.

On Windows PowerShell, put the command on one line or replace the trailing `\` with
a backtick (`` ` ``).

Add these too when the features are set up (see the sections below):

```sh
  --dart-define=AI_TUTOR_PROXY_URL=https://your-server.example/v1/messages   --dart-define=PREMIUM_VERIFY_URL=https://.../verifyPurchase
```

For the Play Store, build an app bundle with the same flags instead:
`flutter build appbundle --release --dart-define=CONTENT_API_URL=...` (needs the upload
key, see [Upload key](#upload-key-required-by-google-play)). Without
`android/key.properties` the release APK is signed with the debug key: fine for
testing on phones, not accepted by Google Play.

## AI Chemistry Tutor

Every topic, chapter, concept and reaction screen has an **Ask AI** button
(`lib/ai/`, `lib/screens/ai_tutor_screen.dart`). The tutor is told the board,
class, chapter, topic and the app's checked notes for it, and every answer is
labelled **AI Explanation** — it is never mixed into the verified notes or PYQs.

No API key is stored in the code. Connect the tutor at build time.

**Gemini** (used whenever a Gemini setting is given):

```sh
# Release builds: your own server keeps the key (recommended)
flutter build apk --dart-define=GEMINI_PROXY_URL=https://your-server.example/gemini

# Local testing only: the key is compiled into the app, so never ship this
flutter run --dart-define=GEMINI_API_KEY=AIza...
```

Optional: `--dart-define=GEMINI_MODEL=gemini-3.8-flash` (default). The app calls
`https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`
with header `x-goog-api-key`. A Gemini proxy receives that JSON body unchanged,
adds the key, forwards it to the model URL and returns the response as-is.
Get a key at https://aistudio.google.com/apikey.

**Claude** (used when no Gemini setting is given):

```sh
# Release builds: your own server keeps the key (recommended)
flutter build apk --dart-define=AI_TUTOR_PROXY_URL=https://your-server.example/v1/messages

# Local testing only: the key is compiled into the app, so never ship this
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
```

Optional: `--dart-define=AI_TUTOR_MODEL=claude-opus-5` (default) and
`--dart-define=AI_TUTOR_EFFORT=medium` (default; `high` for deeper answers).
Without either setting the app works normally and the tutor screen says it is
not set up.

**Proxy contract:** the app POSTs the Claude Messages API JSON body unchanged
with headers `anthropic-version` and `anthropic-beta`. The proxy adds
`x-api-key`, forwards to `https://api.anthropic.com/v1/messages`, and returns the
response as-is. Add rate limiting per device or user there. Use the proxy for the
web build too: browsers cannot call the API directly with a secret key.

## Premium (₹99 one-time, Google Play Billing)

Free: notes, topics, labs, practicals, practice questions, mistake revision,
focus mode, personal notes and basic progress. **Premium** unlocks all PYQs
(Exam tab, PYQ practice, PYQs on topic/concept screens) and the detailed
analysis (accuracy breakdown, chapter-wise progress) in the Progress tab.
Advanced revision sets and extra mock tests are listed as *coming soon* and
are not sold as existing features.

Code: `lib/premium/` (billing, controller, verifier), `lib/screens/premium_screen.dart`,
`lib/widgets/premium_gate.dart`, `lib/l10n/premium_strings.dart`; server in
`server/` (see `server/README.md`). Tests: `test/premium_test.dart`,
`cd server/functions && npm test`.

Premium is granted **only** after the server verifies the purchase with the
Google Play Developer API. Builds without a verify URL show "Purchases are
not set up" and unlock nothing:

```sh
flutter build appbundle --release \
  --dart-define=PREMIUM_VERIFY_URL=https://.../verifyPurchase \
  --dart-define=AI_TUTOR_PROXY_URL=...   # as before
# optional: --dart-define=PREMIUM_PRODUCT_ID=premium_lifetime (default)
```

### Upload key (required by Google Play)

```sh
keytool -genkey -v -keystore %USERPROFILE%\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` (git-ignored, never commit it):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/Users/<you>/upload-keystore.jks
```

Back up the keystore and passwords. Without this file release builds use the
debug key, which Google Play rejects.

### Google Play Console

1. Developer account + **Payments profile** (Setup → Payments profile).
2. Create the app; package name `com.vlab.virtual_chemistry_lab` (permanent).
3. Upload a signed **AAB** (built as above) to **Testing → Internal testing**
   and roll it out. The product screens unlock after a build with the
   BILLING permission is uploaded (the plugin adds it).
4. **Monetize → Products → One-time products → Create**: product ID
   `premium_lifetime`, name "Premium", price **₹99 INR** (let Play convert
   other countries or leave India only), purchase option *Buy*, **Activate**.
5. **Settings → License testing**: add tester Gmail accounts (test purchases,
   no real charge; test cards "always approves", "approves after delay"
   (pending), "declines").
6. Internal testing → Testers: add the same accounts, share the opt-in link,
   install **from Google Play** (sideloaded APKs cannot buy).
7. Set up the verify server (`server/README.md`).

### Test checklist (on a real device, internal testing track)

- Buy with "always approves" → Premium active, PYQs open.
- "Approves after a delay" → Payment pending, unlocks later.
- Cancel the sheet / "declines" → stays free, message shown.
- Uninstall + reinstall (or another phone, same account) → Restore purchase.
- Play Console → Order management → Refund with *Remove entitlement* →
  reopen the app online → Premium removed.

Payments are live only after the product is active and these tests pass on
the testing track, then a production release is published.

## Topic pictures

Topic notes can show hand-drawn, labelled diagrams (English and Hindi) under
**🖼️ Understand with a picture**; tap one to zoom. They are drawn in code
(`lib/widgets/topic_diagrams.dart`) and attached to a note with
`"diagrams": ["ph-scale"]` in its JSON; the content validator rejects unknown
ids. Available: ph-scale, reaction-types, activity-series, ionic-bond-nacl,
covalent-methane, bohr-sodium, gold-foil, tyndall-effect, paper-chromatography,
periodic-trends, vsepr-shapes, daniell-cell, activation-energy, soap-micelle,
dynamic-equilibrium.

Every balanced equation in a note is also drawn automatically as a reaction
picture (reactant cards → product cards with the number of units, state
symbols and conditions over the arrow) — `lib/widgets/reaction_picture.dart`.
