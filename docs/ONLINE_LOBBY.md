# Supabase online play

Online play uses the same Supabase project as the topic library. Each player
needs a separate phone or browser profile; tabs in one browser profile share an
anonymous identity. The offline **Start a game** mode remains available.

## Set up the backend

1. Apply `supabase/migrations/202609290001_topic_packs.sql` and
   `supabase/seed.sql` if the topic library has not already been installed.
2. Apply `supabase/migrations/202610010001_online_game.sql` in the Supabase SQL
   Editor. It creates rooms, members, private words and votes, member-only read
   policies, server-owned game actions, and Realtime publication entries.
3. In **Authentication → Sign In / Providers**, enable **Allow anonymous
   sign-ins** and save. This is needed for each device to have an identity.
4. Run the team's project normally with `flutter run` or Android Studio. To use
   a different Supabase project, override the public settings as described in
   `docs/SUPABASE.md`.

## Play

The host picks a live published topic and creates a room. Other players enter
the six-character code. Three to eight players ready up, and the host starts.
Each player privately reveals their role; the server gives the same secret word
to everyone except the Chameleon. Players submit one clue in turn, discuss,
then vote privately. A tied or wrong accusation lets the Chameleon win. If the
group finds the Chameleon, that player guesses one word from the topic board.

Room and player updates use Supabase Realtime, with a five-second refresh if a
socket drops. Room writes go through SQL functions; direct client writes and
reads of private words and votes are denied. A room expires after six hours.
The app currently plays one round per code; create a new room for another round.
Players who close the app mid-round keep their seat but the round may wait for
them to return. There is no automatic timeout or host takeover mid-round yet.

## Validation

Run `flutter analyze` and `flutter test`. Verify a real hosted round with at
least three independent devices or browser profiles. Check that a nonmember
cannot read room data, a Chameleon cannot fetch the secret word, and a player
cannot vote twice. The older Firebase lobby prototype remains in the tree for
reference but is not used by the configured Host/Join buttons.

## If a room code is not found

- Keep the host on the **Online game** screen and use **Copy room code** to
  share the exact six characters. A room expires six hours after creation;
  leaving a lobby removes that player's seat and removes the room if empty.
- Run the same current build on both the host app and browser clients. A
  host screen titled **Host a room** is the older Firebase prototype, whose
  room codes cannot be joined by the Supabase **Join online** screen. The
  Supabase host screen is titled **Online game** once the room is created.
- Check that both builds use the same `SUPABASE_URL`. Without a build-time
  override, the current app uses the team's Supabase project. On two browser
  clients, use separate browser profiles, because tabs in one profile share a
  player identity.
