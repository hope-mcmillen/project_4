import 'game_phase.dart';
import 'topic_pack.dart';

enum PlayerRole { chameleon, insider }

/// Everything one device is allowed to know right now.
///
/// Secret-bearing fields are null until the rules allow them to be shown:
/// [roleWord] is never set for the Chameleon, and [secretWord] and
/// [resultReason] are set only once the round is over.
class PlayerView {
  const PlayerView({
    required this.players,
    required this.topic,
    required this.phase,
    required this.turn,
    required this.viewerIndex,
    required this.privateOpen,
    this.ownRole,
    this.roleWord,
    this.chameleonName,
    this.secretWord,
    this.winner,
    this.resultReason,
    this.voteCounts = const {},
  });

  final List<String> players;
  final TopicPack topic;
  final GamePhase phase;

  /// Index of the player whose reveal, clue or ballot is in progress.
  final int turn;

  /// Index of the player this view belongs to. On a shared device it follows
  /// [turn], because the phone is handed to whoever acts next.
  final int viewerIndex;

  /// Whether the viewer has opened their private reveal or ballot.
  final bool privateOpen;

  /// The viewer's own role, once they are allowed to see it.
  final PlayerRole? ownRole;

  /// The shared word, for a non-Chameleon viewer who may currently see it.
  final String? roleWord;

  /// Set once the vote has caught the Chameleon.
  final String? chameleonName;

  /// The secret word, public only after the round ends.
  final String? secretWord;
  final RoundWinner? winner;
  final String? resultReason;

  /// Votes received per player index, available only after the round ends.
  final Map<int, int> voteCounts;

  String get turnPlayer => players[turn];
  String get viewerName => players[viewerIndex];
}
