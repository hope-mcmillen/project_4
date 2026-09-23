# Four-person team plan

Assign real names together. These are suggested ownership areas, not existing assignments.

| Teammate | Main responsibility | Starting files | Next deliverable |
| --- | --- | --- | --- |
| 1 | Home, design, accessibility | `lib/app/`, `home_screen.dart`, shared widgets | Refine visual identity, launcher icons, contrast, and screen-reader behavior |
| 2 | Players, setup, topic content | `setup_screen.dart`, `models/`, `data/` | More original topic packs and a topic preview |
| 3 | Game engine and multiplayer research | `game_controller.dart`, controller tests | Agree on scoring/rules, then design server-owned rooms if online play is required |
| 4 | Round UI, quality, integration | `game_screen.dart`, widget tests, CI | Device testing, improved handoffs, and integration of teammate changes |

## Work together

1. Agree on the first milestone and claim an issue before editing.
2. Create one feature branch per task, such as `feature/topic-packs`.
3. Keep changes focused; coordinate shared edits to the controller and common widgets.
4. Run formatting, analysis, and tests before opening a pull request.
5. Have another teammate review the pull request and try the flow before merging.

The foundation branch is `codex/chameleon-foundation`. Use it as the starting point for reviewing and integrating the starter app.

## Suggested milestones

### 1. Playable local prototype — foundation provided

Play a full round on one shared phone, including all outcome paths. Agree on tie behavior and final guesses. Replace default player names with the group's names during testing.

### 2. Class demo readiness

- Replace generated Flutter launcher icons and finalize the app name/package IDs.
- Test Android and iOS devices, landscape mode, keyboard use, long names, and larger text.
- Add agreed scoring, optional clue/discussion timer, and more topic boards.
- Decide whether a round should survive app termination; add persistence only if needed.
- Capture screenshots and prepare the required course deliverables.

### 3. Optional online multiplayer

Confirm that online play is part of the course scope before adding a backend. Design room creation/joining, host permissions, reconnect behavior, and server-owned roles/secret words. Never send every player's role or the secret word to the Chameleon client. The local controller is not a secure multiplayer backend.

## Quick manual demo

Start with four players → privately reveal every role → say one clue each → discuss → vote → try both a caught Chameleon and an escape → replay → leave a round → change the topic. Background the app during a reveal and verify it returns to the locked handoff.
