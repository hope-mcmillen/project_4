# Online lobbies (stage 1)

From Home, choose **Play online**. Players sign in anonymously, create a code or
join one, and see the same player list. Each player can change their readiness;
only the host can change the topic. Changing the topic resets all ready flags.
There must be at least three players, all ready, to show “Everyone is ready”.
Online role assignment and rounds are stage 2; the lobby does not start an offline
round independently on each phone. **Start a game** still opens offline play.

## Firebase services required

The Flutter configuration targets `chameleongame-2214d`. Configuration alone does
not enable its backend services. In the Firebase console:

1. Enable **Authentication → Sign-in method → Anonymous**.
2. Create the default **Cloud Firestore** database in production mode. For this
   setup, `us-central1` keeps it near the callable functions.
3. Cloud Functions deployment requires the **Blaze** plan and a linked billing
   account. Set this up yourself if you want the hosted backend; the local emulator
   flow below does not require a billing account.

Use Node.js 22 for the backend. From the project root:

```powershell
npm.cmd --prefix functions ci
npx.cmd --yes firebase-tools deploy --only "functions:lobby,firestore:rules" --project chameleongame-2214d
flutter run -d chrome
```

The deployment pre-step compiles the TypeScript. Authentication must be enabled
separately. Test players should use separate phones or separate browser profiles
(normal and private windows also work); tabs in one profile share an identity.
Android release builds include the Internet permission. Start with Android or web;
native desktop Firebase plugin support differs by platform.

## Run entirely locally

Install Node.js 22 and Java 21 or newer, then from the project root:

```powershell
npm.cmd --prefix functions ci
npm.cmd --prefix functions run build
npx.cmd --yes firebase-tools emulators:start --project demo-chameleon --only auth,firestore,functions
```

In a second terminal:

```powershell
flutter run -d chrome --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

The define selects the isolated `demo-chameleon` project as well as the local
endpoints. Never supply it for the hosted project. Android emulator clients use
`10.0.2.2` instead of `127.0.0.1`. Emulator state is temporary by default.

## Validation

```powershell
flutter analyze
flutter test
flutter build web
npx.cmd --yes firebase-tools emulators:exec --project demo-chameleon --only auth,firestore,functions "npm --prefix functions test"
```

The backend integration test covers authenticated callables, duplicate names,
idempotent create/join, readiness, host-only topic changes, concurrent joins at the
eight-player limit, host transfer, empty-room closure, expiry, and Firestore rules.
It clears only the demo emulator database. Flutter tests cover lobby creation,
join failure/retry, live updates, readiness, host controls, cached state, seat
restoration, leaving, and small screens, alongside the offline game tests.

## Design and current boundaries

- `RoomRepository` separates lobby UI from Firebase. `FirebaseRoomRepository`
  initializes Firebase on entering online mode, signs in, and restores an active
  room. The offline app does not depend on Firebase startup.
- Functions run in `us-central1`. Authentication identifies the caller; clients
  cannot supply another player's identity. All changes run through the functions.
- Members can read their shared `rooms/{id}` document. No client can list rooms,
  write room documents, or read code lookups or membership mappings.
- `roomCodes/{code}` maps six-character codes to room IDs. `lobbyMembers/{uid}`
  enforces one active lobby per identity and makes create retries safe.
- Transactions reserve codes, enforce capacity and unique names, and transfer host
  ownership to the earliest remaining member when the host explicitly leaves.
- Rooms expire after six hours. Expiry is enforced on reads and actions; expired
  records are not automatically deleted yet. Codes may be reused after expiry.
- Closing the app keeps the seat; choosing Play online restores it under the same
  anonymous identity. Clearing app/browser data loses that identity.
- Ready means the player has tapped Ready, not that they are currently connected.
  Disconnect presence, automatic host transfer on disconnect, kicking absent
  players, and scheduled cleanup remain later work. Explicit Leave transfers host.
- The client shows cached lobby data as connecting and disables readiness/topic
  changes until a server snapshot arrives. Server errors support retry.
- No roles, ballots or secret words are stored in stage 1. Add private per-player
  data and server-owned round rules in stage 2; never put secrets in the shared room.
- Before public distribution, add App Check enforcement and request throttling.
  This initial backend is for small-group development and testing.
