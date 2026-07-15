import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/generator.dart';
import '../logic/validator.dart';
import '../models/difficulty.dart';
import '../models/puzzle.dart';

/// Holds the live state of one puzzle: placed rectangles, the current drag
/// preview, undo history, and remaining hint/wand charges.
class GameController extends ChangeNotifier {
  final PuzzleGenerator _generator = const PuzzleGenerator();
  final ShikakuValidator _validator = const ShikakuValidator();

  bool hapticsEnabled = true;

  Difficulty difficulty;
  late Puzzle _puzzle;
  final List<PlacedRect> _placed = [];
  final List<List<PlacedRect>> _history = [];

  int? _dragStartRow;
  int? _dragStartCol;
  GridRect? _preview;
  int _colorCounter = 0;

  int hintsLeft = 6;
  int wandsLeft = 1;
  bool _solved = false;
  final Stopwatch _stopwatch = Stopwatch();

  Puzzle get puzzle => _puzzle;
  List<PlacedRect> get placed => List.unmodifiable(_placed);
  GridRect? get preview => _preview;
  /// Palette slot for the rectangle currently being drawn (preview).
  int get previewColorIndex => _colorCounter;
  bool get solved => _solved;
  bool get canUndo => _history.isNotEmpty;
  Duration get elapsed => _stopwatch.elapsed;

  GameController(int level, {this.difficulty = Difficulty.easy}) {
    _load(level);
  }

  void loadLevel(int level, {Difficulty? difficulty}) {
    if (difficulty != null) this.difficulty = difficulty;
    _load(level);
    notifyListeners();
  }

  void _load(int level) {
    _puzzle = _generator.generate(level);
    _placed.clear();
    _history.clear();
    _preview = null;
    _dragStartRow = null;
    _dragStartCol = null;
    _colorCounter = 0;
    hintsLeft = 6;
    wandsLeft = 1;
    _solved = false;
    _stopwatch
      ..reset()
      ..start();
  }

  void reset() {
    _load(_puzzle.level);
    notifyListeners();
  }

  // --- Drag interaction -----------------------------------------------------

  void startDrag(int row, int col) {
    if (_solved) return;
    _dragStartRow = row;
    _dragStartCol = col;
    _preview = GridRect.fromCorners(row, col, row, col);
    notifyListeners();
  }

  void updateDrag(int row, int col) {
    if (_dragStartRow == null || _dragStartCol == null) return;
    final r = row.clamp(0, _puzzle.rows - 1);
    final c = col.clamp(0, _puzzle.cols - 1);
    final next = GridRect.fromCorners(_dragStartRow!, _dragStartCol!, r, c);
    if (next != _preview) {
      _preview = next;
      _tick();
      notifyListeners();
    }
  }

  void endDrag() {
    final rect = _preview;
    final startR = _dragStartRow;
    final startC = _dragStartCol;
    _dragStartRow = null;
    _dragStartCol = null;
    _preview = null;

    if (rect == null) {
      notifyListeners();
      return;
    }

    // Single-cell touch: preview only — never paint. Tap an existing shape to
    // remove it (same as eraser on that rectangle).
    if (rect.area < 2) {
      if (startR != null && startC != null) {
        final existing = _rectAt(startR, startC);
        if (existing != null) {
          _pushHistory();
          _placed.remove(existing);
          _tick();
        }
      }
      notifyListeners();
      return;
    }

    _commitRect(rect);
    notifyListeners();
  }

  void _commitRect(GridRect rect) {
    _pushHistory();
    _placed.removeWhere((p) => p.rect.intersects(rect));
    _placed.add(PlacedRect(rect, _colorCounter++));
    _checkSolved();
  }

  // --- Tools ----------------------------------------------------------------

  void eraseAt(int row, int col) {
    final existing = _rectAt(row, col);
    if (existing == null) return;
    _pushHistory();
    _placed.remove(existing);
    _tick();
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    _placed
      ..clear()
      ..addAll(_history.removeLast());
    _solved = false;
    _tick();
    notifyListeners();
  }

  /// Reveals one correct rectangle from the solution that isn't placed yet.
  void useHint() {
    if (hintsLeft <= 0 || _solved) return;
    for (final sol in _puzzle.solution) {
      final already = _placed.any((p) => p.rect == sol);
      if (already) continue;
      _pushHistory();
      _placed.removeWhere((p) => p.rect.intersects(sol));
      _placed.add(PlacedRect(sol, _colorCounter++));
      hintsLeft--;
      _tick();
      _checkSolved();
      notifyListeners();
      return;
    }
  }

  /// Auto-completes the whole puzzle from the stored solution.
  void useWand() {
    if (wandsLeft <= 0 || _solved) return;
    _pushHistory();
    _placed.clear();
    for (final sol in _puzzle.solution) {
      _placed.add(PlacedRect(sol, _colorCounter++));
    }
    wandsLeft--;
    _tick();
    _checkSolved();
    notifyListeners();
  }

  // --- Helpers --------------------------------------------------------------

  PlacedRect? _rectAt(int row, int col) {
    for (final p in _placed) {
      if (p.rect.containsCell(row, col)) return p;
    }
    return null;
  }

  PlacedRect? rectAt(int row, int col) => _rectAt(row, col);

  ValidationResult evaluate() => _validator.evaluate(_puzzle, _placed);

  void _checkSolved() {
    final result = _validator.evaluate(_puzzle, _placed);
    if (result.solved && !_solved) {
      _solved = true;
      _stopwatch.stop();
      _heavyTick();
    }
  }

  void _pushHistory() {
    _history.add(List<PlacedRect>.from(_placed));
  }

  void _tick() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }

  void _heavyTick() {
    if (hapticsEnabled) HapticFeedback.mediumImpact();
  }
}
