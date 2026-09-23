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

`GameScreen` owns and disposes its controller. It keeps temporary ballot/guess selections locally, while confirmed actions go to the controller. It does not calculate winners. There are no routes to old role screens: the active phase replaces its content. A hidden handoff separates each role or vote. Back navigation requires confirmation during play and returns to the existing setup.

When the app becomes inactive, hidden, paused, or detached, an open private view closes and a tentative ballot selection clears. Revealing it again requires another tap. This is a local privacy convenience, not screenshot protection or network security. Role text is not exposed by the controller's UI getters outside the appropriate reveal; the secret is public only after the round ends.

## Extend without tangling features

- **Content:** Add a `TopicPack` in `data/topic_packs.dart`; use distinct, nonempty words. Existing boards use 12 words for phone readability.
- **Appearance:** Put shared changes in `app/theme.dart` and `widgets/game_widgets.dart`.
- **Rules/scoring:** Change controller actions, then add outcome tests. Keep scoring in a separate session model if it spans rounds.
- **Persistence:** Add a repository abstraction and an explicit resume policy. Do not persist private roles accidentally in plain logs.
- **Online play:** Introduce server-owned state and per-player views, stable player IDs, authentication/room membership, and validated actions. Do not serialize the full local controller to every client.

## Current boundaries

No external state-management package or backend is required. Clues and discussion happen aloud; the app does not record audio. Votes are anonymous in the results: only aggregate counts are displayed. Replay keeps players and topic but creates a fresh controller with new random selections; consecutive rounds may coincidentally select the same word or Chameleon.

The existing platform scaffolding remains. Android/iOS store signing, production identifiers, launcher artwork, distribution, and physical-device validation remain team tasks.
