# Chameleon

A Flutter social deduction party game for our four-person group project. One player is secretly the Chameleon. Everyone else knows a shared word. Give clues, find the bluff, and vote.

## Run the app

Use **Flutter 3.47.1 / Dart 3.13.1 or compatible newer versions** (the repository already requires Dart `^3.13.1`).

```sh
flutter pub get
flutter devices
flutter run
```

Select an Android emulator, iOS simulator, or connected phone. iOS builds require macOS with Xcode. For a quick browser preview:

```sh
flutter run -d chrome
```

The cloned project folder is `chameleon`. The Dart package is still named `project_4` to preserve the existing imports and platform identifiers. The visible app name on Android, iOS, and web is **Chameleon**.

## What works now

- A custom home screen, shared theme, drawn mascot, and in-app rules.
- Setup for 3–8 players, with four default slots and unique-name validation.
- Three original topic boards: Food & drink, Out & about, After class.
- Exactly one random Chameleon and one shared secret word each round.
- Private role handoffs; private views hide when the app loses focus.
- One spoken clue per player, group discussion, and private ballots.
- Vote tally, the Chameleon's final guess, results, and replay with the same crew.
- An exit confirmation that preserves player setup when leaving a round.

This is **offline pass-and-play on one device**. No accounts, server, room codes, network multiplayer, saved games, or cumulative scores are implemented. Closing or restarting the app clears the round. Keep the phone private during reveals; this starter does not block screenshots or screen recording.

## Starter rules

1. Everyone except the Chameleon sees the same secret word; all players may see the topic board.
2. Each player gives one spoken, one-word clue in the displayed order.
3. Discuss, then each player privately votes for another player. Votes cannot be changed after confirmation.
4. The player with the most votes is accused. A tie or an incorrect accusation means the Chameleon wins.
5. If caught, the Chameleon selects one final guess from the board. A correct guess wins for the Chameleon; otherwise the group wins.

These are the starter's simplified house rules, not a complete reproduction of the commercial game. Each round stands alone.

## Project structure

```text
lib/
  main.dart                         # Entry point
  app/
    chameleon_app.dart              # Root application
    theme.dart                      # Shared colors and component styling
  features/game/
    data/topic_packs.dart            # Original topic boards
    models/topic_pack.dart          # Topic data shape
    logic/game_controller.dart      # Round state, roles, votes, outcomes
    screens/
      home_screen.dart              # Home and rules
      setup_screen.dart             # Player and topic setup
      game_screen.dart              # Handoffs and round screens
    widgets/game_widgets.dart       # Layout, cards, board, mascot
```

The controller owns game transitions and exposes read-only state. Widgets call its actions and rebuild through `ListenableBuilder`. Production role selection uses `Random.secure`; tests inject deterministic randomness. No new third-party dependencies were added.

## Checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

Tests cover role secrecy, all winning outcomes, validation, illegal transitions, min/max players, a complete UI round, replay, lifecycle hiding, leaving a round, and small-screen layouts. GitHub Actions runs formatting, analysis, tests, and a web build on pushes and pull requests.

See [the team plan](docs/TEAM_PLAN.md) for a suggested four-person work split and [the architecture notes](docs/ARCHITECTURE.md) before extending game state.
