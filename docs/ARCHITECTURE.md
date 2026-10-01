# Architecture and extension points

## Flow

```text
Home → Setup → Role handoffs → Spoken clues → Discussion → Private voting
                                                               │
                          ┌────────────────────────────────────┤
                          ↓                                    ↓
               Tie / wrong accusation                 Chameleon caught
                          ↓                                    ↓
                       Results ←────────────────────── One final guess
                          ↓
                   Replay or return to setup
```

`GameController` is the single source of truth for a local round. `GamePhase` makes phase transitions explicit. It validates player setup, gates actions by phase, prevents self-votes, and resolves results. Names are trimmed and case-insensitively unique. Player identity within a round is its stable list index; names are display labels.

`GameScreen` owns and disposes a `GameRepository` (built by a factory, so replay gets a fresh round) and only reads its `PlayerView`. Each phase lives in its own widget under `screens/phases/` and receives the view plus callbacks. `GameScreen` does not calculate winners. There are no routes to old role screens: the active phase replaces its content, keyed per handoff so scroll position and tentative selections reset. A hidden handoff separates each role or vote. Back navigation requires confirmation during play and returns to the existing setup.

`PlayerView` is the boundary for secrets. `roleWord` is never set for the Chameleon, and `secretWord`, `resultReason`, and `voteCounts` are set only after the round ends. `ChameleonCard` takes no word at all, so it cannot display one. `player_view_test.dart` checks that a Chameleon's view never carries the word before the result.

When the app becomes inactive, hidden, paused, or detached, an open private view closes and a tentative ballot selection clears. Revealing it again requires another tap. This is a local privacy convenience, not screenshot protection or network security. Role text is not exposed by the controller's UI getters outside the appropriate reveal; the secret is public only after the round ends.

## Online rooms (lobby)

`features/lobby/` holds everything before an online round starts. `RoomRepository` is its only seam to a backend: create a room (the host is its first player), watch it as a stream, join by code, and start (host only, 3–8 players). Failures are `RoomException`s with a readable message. `Room` carries no secrets; roles and the word are dealt when the round starts (CHM-11).

`FakeRoomRepository` is an in-memory stand-in until the backend is chosen (CHM-S1). `ChameleonApp` owns one instance for the whole app and passes it to `HomeScreen`, so hosting and joining on one device see the same rooms. Tests pass their own. A real backend implements the same interface; nothing above it changes.

`CreateRoomScreen` owns a `HostLobbyController` (setup → creating → lobby → starting → started) for as long as the host stays on it, and switches to `HostLobbyView` once the room exists. `JoinRoomScreen` mirrors it for guests with a `JoinRoomController` (entry → joining → lobby → started) and `GuestLobbyView`. Unknown, full and started rooms and taken names come back as errors on the form so the player can retry. Both lobbies render players with the shared `LobbyPlayerList`.

With the fake backend, rooms exist only in one app's memory, so hosting and joining work on the same device (and in `join_flow_test.dart`, which runs two app instances on one fake). Joining from a different phone needs the real backend. Room codes are five characters from an alphabet without 0/O/1/I/L; `normalizeRoomCode` accepts lowercase, spaces and dashes for typed input.

## Extend without tangling features

- **Content:** Add a `TopicPack` in `data/topic_packs.dart` with exactly 12 distinct, nonempty words. `word_repository_test.dart` checks every pack. Setup loads the catalog through `WordRepository.getTopics()`; `LocalWordRepository` supplies the const offline list. CHM-2 supplies `RemoteWordRepository`, selected by build-time Supabase configuration and shared through the app and home screen. Its in-memory cache lasts ten minutes, coalesces simultaneous loads, and retains the last valid catalog (or the local catalog) on failure. See `SUPABASE.md` for the schema and lifecycle. Topic previews display the complete board and require an explicit choice before changing the selection. Secret-word selection still happens only when starting a round.
- **Appearance:** Put shared changes in `app/theme.dart` and `widgets/game_widgets.dart`.
- **Rules/scoring:** Change controller actions, then add outcome tests. Keep scoring in a separate session model if it spans rounds.
- **Persistence:** Add a repository abstraction and an explicit resume policy. Do not persist private roles accidentally in plain logs.
- **Online play:** Implement `GameRepository` against a server that owns state and sends each device only its own `PlayerView`, with stable player IDs, authentication/room membership, and validated actions. Do not serialize the full local controller to every client.

## Current boundaries

No external state-management package or backend is required. Clues and discussion happen aloud; the app does not record audio. Votes are anonymous in the results: only aggregate counts are displayed. Replay keeps players and topic but creates a fresh controller with new random selections; consecutive rounds may coincidentally select the same word or Chameleon.

The existing platform scaffolding remains. Android/iOS store signing, production identifiers, launcher artwork, distribution, and physical-device validation remain team tasks.
