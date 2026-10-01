# Backend decision (CHM-S1)

**What the team built: Supabase for topic words, Firebase for online rooms.**

| Concern | Backend | Built in | Setup |
|---|---|---|---|
| Topic packs and words (CHM-1/2) | Supabase (Postgres + Data API) | PR #3 | [SUPABASE.md](SUPABASE.md) |
| Online rooms, players, lobby (CHM-3/4, stage 1) | Firebase: anonymous Auth, Firestore, Cloud Functions | PR #8, #9 | [ONLINE_LOBBY.md](ONLINE_LOBBY.md) |

This page records why, what it costs, and how the next online stage
(CHM-11/12) keeps each player's secret. Recorded 2026-10-01, after both were
merged. An earlier draft of this PR proposed Supabase for rooms too; the team
built rooms on Firebase instead, and this version describes what exists.

Still open: confirm with the instructor that online play and hosted backends
are in scope.

## Why two backends

The two were chosen in parallel for different jobs, and both fit:

- **Words are public, read-only content.** Supabase serves them through its
  Data API with plain `http`, and the app falls back to bundled topics when
  offline, so a Supabase outage never blocks a game.
- **Rooms need identity, live updates and server-side rules.** Firebase gives
  anonymous sign-in, Firestore listeners, security rules and callable
  functions in one place, and `firebase_room_repository.dart` uses all four.

**Cost of the split:** two consoles, two sets of config, two things to keep
alive before a demo. Moving topic packs into Firestore later would remove one,
but is not needed for the course.

## How rooms stay secure today

- Every write goes through a callable Cloud Function (`createRoom`,
  `joinRoom`, `setReady`, `setTopic`, `leaveRoom`, …). Clients cannot write
  Firestore directly: `firestore.rules` denies `create`, `update`, `delete`
  and `list` everywhere.
- A client may `get` a room document only if it is signed in, its `uid` is in
  the room's `players`, and the room has not expired.

## Keeping the secret word off the Chameleon's phone (CHM-11)

The room document is readable by **every** player in the room. So:

- **Never put roles or the secret word in the room document**, or in any
  document all players can read. A field that "the app doesn't show" is still
  delivered to every phone, readable by anyone with a debugger.
- Give each player their own role document, for example
  `rooms/{roomId}/roles/{uid}`, with a rule like
  `allow get: if request.auth != null && request.auth.uid == uid;`.
  The Chameleon's document has no word, only the flag.
- **Assign roles in a Cloud Function**, never on the host's phone: the
  function picks the Chameleon and the word and writes the role documents.
- Votes go through a function too (reject self-votes and second votes); the
  function tallies and writes only the public result (counts, accused, secret
  word) into the room document **after** voting closes.
- Test the rule with the Firestore emulator: a player reading another
  player's role document must be denied. This is the one rule where a mistake
  ends the game.

`docs/ARCHITECTURE.md` already says the online `GameRepository` must send each
device only its own `PlayerView`; the role documents above are how Firestore
enforces that.

## Before a demo or submission

- **Cloud Functions need the Blaze plan to deploy** (Firebase: "to deploy
  functions, your project must be on the Blaze pricing plan"). Without a
  deployed backend, online play only works against the local emulators.
  `ONLINE_LOBBY.md` covers both routes. Decide which one the demo uses well
  before the day.
- **Supabase free projects pause after a week of inactivity**
  (supabase.com/pricing). Offline fallback keeps the game playable, but the
  remote topics would be missing. Open the Supabase dashboard in the days
  before a demo.
- Never ship a Supabase service-role key or Firebase admin credentials in
  the app. The Supabase publishable key and the Firebase client config are
  designed to be public; security comes from RLS and Firestore rules.

Sources read 2026-09-29 and 2026-10-01: supabase.com/pricing,
firebase.google.com/docs/functions/get-started, and the repository's own
`firestore.rules`, `functions/src/index.ts` and lobby code.
