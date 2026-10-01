# Supabase topic library (CHM-2)

CHM-1's topic library and preview are complete. CHM-2 now implements the remote
repository against the following CHM-S1 backend contract. The app includes the
team project's public URL and publishable key, so a normal `flutter run` connects
to Supabase. Other projects can override those public settings as below.

## Create the backend

1. Create a Supabase project in your team's account.
2. In SQL Editor, run `supabase/migrations/202609290001_topic_packs.sql` once.
3. Run `supabase/seed.sql` to add the ten starter packs. Rerunning the seed does
   not overwrite packs you have edited.
4. Ensure the Data API is enabled and the `public` schema is exposed.
5. Copy the project URL and **publishable** key from the project connection/API
   settings. A legacy **anon** key also works. Never use a secret/service-role key.

The schema uses `public.topic_packs` with `id` (text), `name` (text), `words`
(text array), and `is_published` (boolean). The app reads only published packs.
Each pack must contain exactly 12 distinct, nonempty words, matching CHM-1.
Names are at most 80 characters and words at most 40 characters. RLS and SQL
grants allow anonymous and signed-in app users to read published packs only;
they cannot insert, modify, or delete packs. Manage content through the team's
Supabase dashboard. Topic lists are public; do not store player secrets here.

## Connect the app

For this team's project, run or build normally:

```sh
flutter run
flutter build apk
```

To use another Supabase project, copy `config/supabase.example.json` to
`config/supabase.json` and replace both placeholders. That local file is ignored
by Git. Then run or build with the override:

```sh
flutter run --dart-define-from-file=config/supabase.json
flutter build apk --dart-define-from-file=config/supabase.json
flutter build web --dart-define-from-file=config/supabase.json
```

In Android Studio, the team project works with a normal Flutter run. For a
different project, put `--dart-define-from-file=config/supabase.json` in the
Flutter run configuration's **Additional run args** and use the same override
for release/CI builds. Both overrides must be supplied together. The publishable
key is expected to be in the app binary; access control comes from RLS and
grants, not hiding this key.

## Add or edit topics without an app release

In Supabase Table Editor, open `topic_packs`. Add a row (ID is generated unless
you provide a stable ID), enter its name, and enter `words` as an array of twelve
strings. Set `is_published` to true when ready. Edit a row's word array to change
its words, or set `is_published` to false to retire a pack. Do not rerun the schema
migration to edit content.

Example word-array value for a new topic named **At home**:

```json
["Sofa", "Lamp", "Mirror", "Carpet", "Curtain", "Pillow", "Fridge", "Oven", "Kettle", "Toaster", "Bathtub", "Bookshelf"]
```

## Fetching, caching, and offline behavior

- One `RemoteWordRepository` is shared for the lifetime of the app.
- Opening setup fetches published packs via Supabase's REST Data API. Pages are
  ordered by stable ID and loaded until an empty page. Only a complete, valid
  response replaces the cache.
- Successful results are cached in memory for **10 minutes**. Reopening setup
  within that window does not refetch. After expiration, the next setup load
  fetches updated content. Restarting the app also fetches on entering setup.
- Replay uses the topic captured at round creation and never fetches. To get
  updated packs, return home and reopen setup after the cache expires. An active
  round's word list never changes underneath players.
- Simultaneous requests share one fetch. The complete operation has an **8-second
  timeout**; timeout closes the HTTP client.
- On network, HTTP, or malformed-data failures, previously fetched packs remain
  available. Without cached packs, the ten bundled packs are used. Further calls
  reuse that fallback for **30 seconds**, then allow another network attempt.
- A successful empty catalog is respected: setup shows no available topics.
- The cache does **not** persist across app restarts. Starting offline uses the
  bundled list. Persistent disk caching can be added separately if needed.

## Validation

`test/remote_word_repository_test.dart` uses mocked HTTP responses to test the
Supabase request contract, pagination, cache expiration, concurrent requests,
offline fallback, recovery, malformed packs, empty catalogs, timeouts, and safe
configuration. Existing preview and game tests still exercise the app locally.

Once the actual project exists, verify the live deployment: publish a test pack,
launch with its public credentials, open setup and preview it; restart offline
and check local fallback; verify an anonymous request cannot read unpublished
packs or write to the table. Hosted permissions and the SQL migration must be
verified against that project before release.

References: [Supabase Data API security](https://supabase.com/docs/guides/api/securing-your-api)
and [public API keys](https://supabase.com/docs/guides/getting-started/api-keys).
