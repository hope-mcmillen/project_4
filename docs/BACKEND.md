# Backend decision (CHM-S1)

**Decision: Supabase, for both topic words and online rooms.** One backend,
so CHM-2, CHM-3/4 and CHM-11/12 build on the same technology.

Status: proposed 2026-09-29. Still open: confirm with the instructor that
online play is in scope and that a hosted Supabase project is allowed.

## Why Supabase

- **It is already in use.** PR #3 (CHM-2) reads topic packs from a Supabase
  project, with row-level security, a migration and seed data. A second
  backend for rooms would mean two dashboards, two sets of keys and two
  failure modes for a class project.
- **Secrets can be enforced by the database, not by the app.** Postgres
  row-level security (RLS) can let each phone read only its own role row.
  That is the guarantee CHM-11 needs: the Chameleon's phone never *receives*
  the word, rather than receiving it and choosing not to show it.
- **Identity without accounts.** Anonymous sign-in gives each phone a stable
  user id (`auth.uid()`) that RLS policies can use, with no email or password.
  Dart: `await supabase.auth.signInAnonymously();` Must be enabled in the
  dashboard under Auth providers.
- **Live updates.** Supabase Realtime pushes row changes to subscribed clients,
  which covers the lobby list (CHM-3/4) and every phone advancing together
  (CHM-12).

## Alternatives considered

| Option | Why not |
|---|---|
| Firebase Auth + Firestore | Equivalent capability — anonymous auth, security rules, live listeners — but it would be a second backend beside the Supabase one PR #3 already uses. |
| Our own WebSocket server | Needs an always-on host, and free hosts sleep idle servers. More code to write and secure, for the same result. |

## Cost — Supabase Free plan

Figures from supabase.com/pricing, read 2026-09-29:

- 500 MB database, 50,000 monthly active users, 5 GB egress
- Realtime: 200 concurrent connections, 2 million messages a month
- **Free projects are paused after 1 week of inactivity.**

A class demo is far inside every limit except the last. **If nobody uses the
project for a week, it will be paused at demo time.** Open the dashboard or run
the app against it in the days before any demo or submission.

## How each phone gets only its own role (CHM-11)

Proposed schema; names are suggestions for CHM-11/12's owner.

- `rooms` — code, host's user id, topic, status. Readable by room members.
- `room_players` — room, user id, display name, seat. Readable by room members.
- `rounds` — room, round number, phase, turn, and the **public** result
  (secret word, Chameleon's seat, vote counts), which is filled in **only when
  the round reaches its result**.
- `round_roles` — round, user id, `is_chameleon`, `word`. **`word` is null on
  the Chameleon's row.** RLS: `select` only where `user_id = auth.uid()`. No
  client may insert or update it.
- `votes` — round, voter, accused seat. Clients cannot read other people's
  votes; only the tally in `rounds`, after the result.

**Clients never pick roles or count votes.** Postgres functions do, declared
`security definer` so they can write rows clients cannot:

- `start_round(code)` — checks the caller is the host, picks the Chameleon and
  the word, writes one `round_roles` row per player.
- `cast_vote(round, seat)` — checks the phase, rejects self-votes and second
  votes.
- `resolve_round(round)` — tallies, applies the rules, publishes the result
  into `rounds`.

Clients subscribe with Realtime to `rooms`, `room_players` and `rounds` —
public state only — and fetch their own `round_roles` row once per round with
an ordinary select. **Do not subscribe to `round_roles` at all.** Supabase
does check RLS per subscriber for Realtime inserts and updates ("Postgres
Changes authorizes every event against each subscriber"), but its docs also
say: "RLS policies are not applied to `DELETE` statements." Deleting old role
rows while anyone is subscribed could broadcast them. Still, **prove the
select policy with a test**: this is the one table where a leak ends the game.

(Quotes from supabase.com/docs/guides/realtime/postgres-changes, read
2026-09-29.)

## Fitting the existing code

Kameron's `RoomRepository` interface (`feature/CHM-3-create-room`) maps
directly: `createRoom` and `joinRoom` become functions that raise errors
mapped onto `RoomError` (`full`, `alreadyStarted`, `nameTaken`, …);
`watchRoom` becomes a Realtime subscription; `startRound` calls
`start_round`. The in-memory fake stays for tests.

`GameRepository` gets an online implementation beside
`LocalGameRepository`, per `docs/ARCHITECTURE.md`: the server owns state and
sends each device only its own `PlayerView`.

**One new dependency is needed:** the official `supabase_flutter` client.
PR #3 reads topic packs with plain `http` against the Data API, which is
enough for public reads, but anonymous auth and Realtime need the client
library. Adding a dependency is a team call; this document recommends it over
hand-writing the Realtime protocol.

## Watch out for

- **Paused project** — see Cost.
- **Anonymous sign-in rate limit:** 30 per hour per IP by default. Phones on
  one Wi-Fi share an IP. One sign-in per phone is fine, but repeated reinstalls
  during testing can hit it. Configurable in the dashboard.
- Supabase recommends CAPTCHA (or Cloudflare Turnstile) for anonymous
  sign-ins in production. Not needed for a class demo; note it if the app is
  ever published.
- **Never ship the service-role key** in the app. The publishable (or legacy
  anon) key is designed to be public; security comes from RLS, as
  `docs/SUPABASE.md` already says.
