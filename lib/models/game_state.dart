import '../game/game_mode.dart';
import 'board_position.dart';

enum GameStatus { playing, solved, failed }

class GameState {
  final int boardSize;
  final List<List<StoneColor>> board;
  final StoneColor currentPlayer;
  final GameMode gameMode;
  final List<BoardPosition> capturedByBlack;
  final List<BoardPosition> capturedByWhite;
  final List<List<List<StoneColor>>> history; // board snapshots for undo
  final BoardPosition? lastMove;
  final List<List<StoneColor>>? koState; // board state before last ko capture
  final GameStatus status;
  final List<BoardPosition> targetCaptures;
  final List<BoardPosition> atariStones; // stones in atari
  final int consecutivePasses;

  GameState({
    required this.boardSize,
    required this.board,
    required this.currentPlayer,
    this.gameMode = GameMode.capture,
    List<BoardPosition>? capturedByBlack,
    List<BoardPosition>? capturedByWhite,
    List<List<List<StoneColor>>>? history,
    this.lastMove,
    this.koState,
    this.status = GameStatus.playing,
    List<BoardPosition>? targetCaptures,
    List<BoardPosition>? atariStones,
    this.consecutivePasses = 0,
  })  : capturedByBlack = capturedByBlack ?? [],
        capturedByWhite = capturedByWhite ?? [],
        history = history ?? [],
        targetCaptures = targetCaptures ?? [],
        atariStones = atariStones ?? [];

  factory GameState.initial({
    required int boardSize,
    required List<Stone> initialStones,
    required List<BoardPosition> targetCaptures,
    StoneColor firstPlayer = StoneColor.black,
    GameMode gameMode = GameMode.capture,
  }) {
    final board = List.generate(
      boardSize,
      (_) => List.filled(boardSize, StoneColor.empty),
    );
    for (final stone in initialStones) {
      board[stone.position.row][stone.position.col] = stone.color;
    }
    return GameState(
      boardSize: boardSize,
      board: board,
      currentPlayer: firstPlayer,
      gameMode: gameMode,
      targetCaptures: targetCaptures,
    );
  }

  GameState copyWith({
    List<List<StoneColor>>? board,
    StoneColor? currentPlayer,
    GameMode? gameMode,
    List<BoardPosition>? capturedByBlack,
    List<BoardPosition>? capturedByWhite,
    List<List<List<StoneColor>>>? history,
    BoardPosition? lastMove,
    List<List<StoneColor>>? koState,
    GameStatus? status,
    List<BoardPosition>? targetCaptures,
    List<BoardPosition>? atariStones,
    int? consecutivePasses,
  }) {
    return GameState(
      boardSize: boardSize,
      board: board ?? this.board,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      gameMode: gameMode ?? this.gameMode,
      capturedByBlack: capturedByBlack ?? List.from(this.capturedByBlack),
      capturedByWhite: capturedByWhite ?? List.from(this.capturedByWhite),
      history: history ?? List.from(this.history),
      lastMove: lastMove ?? this.lastMove,
      koState: koState,
      status: status ?? this.status,
      targetCaptures: targetCaptures ?? this.targetCaptures,
      atariStones: atariStones ?? this.atariStones,
      consecutivePasses: consecutivePasses ?? this.consecutivePasses,
    );
  }

  StoneColor colorAt(int row, int col) => board[row][col];

  bool get canUndo => history.isNotEmpty;
}
