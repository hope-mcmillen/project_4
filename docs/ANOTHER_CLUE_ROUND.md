# Repeating online clue rounds

Offline play already supports Another Round on the discussion screen. Online
hosts now have the same choice beside Start voting. Guests see a waiting message.
The category and private roles remain the same; each new pass clears the previous
submitted clues, starts at the first occupied seat, and returns to discussion
after everyone submits. Voting and scoring happen only after the group chooses
to vote.

## Required database update

Apply `supabase/migrations/202610010002_another_clue_round.sql` to the same
Supabase project used by the app, after `202610010001_online_game.sql`.
For an existing deployment, paste only the new migration into Supabase's SQL
Editor and run it once. Do not rerun the original tables migration.

The new RPC is `online_another_clue_round(p_room, p_expected_round)`. It locks
the room and checks authentication, membership, host identity, room expiry,
discussion phase, and clue-round number. Stale and duplicate requests fail;
the private secret table is untouched. The room's existing Realtime subscription
and polling refresh move every device into the next clue pass.

The application change alone does not install this RPC. Deploy the migration
before using the new online button. No service-role key belongs in the app.

## Verification

`test/lobby/online_round_ui_test.dart` covers repeated clue passes, continuing
to voting, host versus guest controls, failed requests, private word hiding,
the mascot, and a small-screen layout with enlarged text. Existing offline
tests cover repeated clue rounds with the same roles and word.

Run the migrations in an isolated PostgreSQL runtime (no live credentials):

```sh
npm install --prefix build/ui-sql-check --no-save --package-lock=false @electric-sql/pglite
node supabase/tests/another_clue_round.mjs
```

This executes both online migrations and checks real SQL transitions, repeated
rounds, unchanged secrets, cleared clues, authentication, membership, host-only
access, expiry, stale and duplicate requests, voting, and execute grants.

After applying the migration, verify with three separate devices: complete
roles and clues, let the host choose Another Round twice, confirm every device
returns to clues, then choose Start voting and finish the game. Check that a
guest cannot call the new RPC and that an old round number is rejected.
