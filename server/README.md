# Premium purchase verification (Firebase Cloud Function)

The app never unlocks Premium on Google Play's word alone. After a purchase
(and on every app start / Restore) it sends the purchase token here; this
function asks the **Google Play Developer API** whether the purchase is
paid, pending, cancelled or refunded, and answers
`{"state": "valid" | "pending" | "invalid"}`.

- No key file anywhere: the function runs as its own Google service account,
  which you give access in Play Console. Nothing secret is in the app.
- Only `premium_lifetime` for `com.vlab.virtual_chemistry_lab` is accepted
  (`functions/index.js`).
- The app acknowledges a purchase only after this function says `valid`;
  unacknowledged purchases are refunded by Google after 3 days.
- Refunds: Google removes refunded purchases from the account's purchase
  list, and this function also checks the Voided Purchases API, so Premium
  is removed the next time the app is online.

## One-time setup

1. **Firebase project** (Blaze plan; Cloud Functions need billing enabled,
   this function's usage fits in the free tier for a small app).
   Install the CLI: `npm i -g firebase-tools`, then `firebase login`.
2. From `server/`: `firebase use --add` and pick the project.
3. `cd functions && npm install && npm test`
4. `firebase deploy --only functions` – note the URL it prints, e.g.
   `https://asia-south1-<project>.cloudfunctions.net/verifyPurchase`
   (or `https://verifypurchase-<hash>-el.a.run.app`).
5. **Google Cloud console** (same project) → APIs & Services → enable
   **Google Play Android Developer API**.
6. Find the function's service account: Cloud Run → `verifypurchase` →
   Security → Service account (by default
   `<project-number>-compute@developer.gserviceaccount.com`).
7. **Play Console** → Users and permissions → Invite new users → that
   service-account email → App permissions: this app →
   **View financial data, orders and cancellation survey responses**.
   It can take up to 24 hours before the API accepts it.
8. Build the app with the URL:

   ```sh
   flutter build appbundle --release --dart-define=PREMIUM_VERIFY_URL=https://.../verifyPurchase
   ```

Check calls in Firebase console → Functions → Logs (order ids are logged,
purchase tokens never are).
