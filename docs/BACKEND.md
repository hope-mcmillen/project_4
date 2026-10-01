# Backend decision (CHM-S1)

**Supabase is the app's backend: topic words and online play.**

| Concern | Backend | Built in | Setup |
|---|---|---|---|
| Topic packs and words (CHM-1/2) | Supabase | PR #3 | [SUPABASE.md](SUPABASE.md) |
| Online rooms, roles, clues, votes, results | Supabase: anonymous Auth, Postgres with RLS, server functions, Realtime | PR #10 | [ONLINE_LOBBY.md](ONLINE_LOBBY.md) |

Updated 2026-10-01 after #10. Earlier versions of this page said rooms would run
on Firebase, which matched what was on `master` at the time (#8). Online play
now goes through Supabase: the home screen's **Host online** / **Join online**
open `SupabaseOnlineScreen` when a Supabase client is configured (`lib/main.dart`).
Without that configuration the online buttons are hidden and the home screen
says online play isn't set up. The in-memory `RoomRepository` rooms from #9 are
only passed in by tests; the app itself never uses them.

Still open: confirm with the instructor that online play and a hosted backend
are in scope.

## Why Supabase

- One backend for words and rooms: one project, one set of keys, one thing to
  keep alive before a demo.
- Postgres row-level security lets the database, not the app, decide what each
  phone can read, which is what keeps the secret word off the Chameleon's phone.
- Anonymous sign-in gives each phone an identity without accounts.
- Realtime pushes room and player changes, so every phone advances together.

## How the secret stays secret

The design in `supabase/migrations/202610010001_online_game.sql` is the
reference for any future online feature:

- **The secret word and the Chameleon's identity live in their own table,
  `online_secrets`, which no client can read.** All table grants are revoked,
  it has no select policy, and it is **not** published to Realtime.
- A player learns their own role only through `online_my_role(room)`, a
  `security definer` function that returns the word to everyone except the
  Chameleon.
- Every action (`online_create_room`, `online_join_room`, `online_start_round`,
  `online_submit_clue`, `online_cast_vote`, `online_guess_word`, …) is a
  `security definer` function that
  validates the caller. Clients never write tables directly.
- Only `online_rooms` and `online_members` are published to Realtime, and
  clients can read them only for rooms they belong to.

**Keep it that way.** Never add `online_secrets` (or `online_votes`) to the
Realtime publication: Supabase's docs say "RLS policies are not applied to
`DELETE` statements" for Realtime, so a published secrets table could broadcast
rows when a room is deleted. And never put the word or roles in `online_rooms`,
which every member can read.

## Firebase

`master` still contains a Firebase lobby (#8): `lib/features/lobby/online_screen.dart`,
`firebase_room_repository.dart`, `firebase_options.dart`, `functions/`,
`firestore.rules`, and the Android `google-services` plugin with
`android/app/google-services.json`. **Nothing in the app opens that lobby any
more.** The plugin is still part of every Android build, which is why renaming
the app ID broke the build on 2026-10-01 (#6, fixed in #11).

Removing the unused Firebase code and plugin, or wiring the lobby back in, is a
team decision. Until then, the Android application ID must stay
`com.example.project_4`, the ID `google-services.json` is registered to.

## Before a demo or submission

- **Supabase free projects pause after a week of inactivity**
  (supabase.com/pricing, read 2026-09-29). A paused project means no online
  play and no remote topics (offline play still works with the bundled
  topics). Open the dashboard or play an online round in the days before.
- Anonymous sign-in is rate-limited per IP (30 per hour by default, per
  Supabase's auth docs). Phones on one Wi-Fi share an IP; fine for a demo, but
  repeated reinstalls during testing can hit it.
- Never ship the Supabase service-role key. The publishable key is designed to
  be public; security comes from RLS and the functions above.
