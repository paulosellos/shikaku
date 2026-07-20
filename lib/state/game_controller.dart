import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/generator.dart';
import '../logic/validator.dart';
import '../models/puzzle_difficulty.dart';
import '../models/puzzle.dart';

/// Holds the live state of one puzzle: placed rectangles, the current drag
/// preview, undo history, tool charges, and per-level usage stats.
class GameController extends ChangeNotifier {
  final PuzzleGenerator _generator = const PuzzleGenerator();
  final ShikakuValidator _validator = const ShikakuValidator();

  bool hapticsEnabled = true;

  PuzzleDifficulty difficulty;
  final int? _generationSeed;
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

  /// Semi-transparent outline of the hinted rectangle (not placed).
  GridRect? hintPreviewRect;
  int? hintedClueIndex;

  /// Clue the player last touched — wand and hint prefer this region.
  int? lastInteractedClueIndex;

  int hintsUsed = 0;
  int wandUsed = 0;
  int undoCount = 0;

  Puzzle get puzzle => _puzzle;
  List<PlacedRect> get placed => List.unmodifiable(_placed);
  GridRect? get preview => _preview;
  /// Palette slot for the rectangle currently being drawn (preview).
  int get previewColorIndex => _colorCounter;
  bool get solved => _solved;
  bool get canUndo => _history.isNotEmpty;
  Duration get elapsed => _stopwatch.elapsed;

  GameController(
    int level, {
    this.difficulty = PuzzleDifficulty.medium,
    int? seed,
  }) : _generationSeed = seed {
    _load(level);
  }

  void loadLevel(int level, {PuzzleDifficulty? difficulty}) {
    if (difficulty != null) this.difficulty = difficulty;
    _load(level);
    notifyListeners();
  }

  void _load(int level) {
    _puzzle = _generator.generate(
      level,
      difficulty: difficulty,
      seed: _generationSeed,
    );
    _placed.clear();
    _history.clear();
    _preview = null;
    _dragStartRow = null;
    _dragStartCol = null;
    _colorCounter = 0;
    hintsLeft = 6;
    wandsLeft = 1;
    _solved = false;
    _clearHintPreview();
    lastInteractedClueIndex = null;
    hintsUsed = 0;
    wandUsed = 0;
    undoCount = 0;
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
    _noteClueInteraction(row, col);
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
        _noteClueInteraction(startR, startC);
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
    if (hintPreviewRect != null && hintPreviewRect == rect) {
      _clearHintPreview();
    }
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
    undoCount++;
    _tick();
    notifyListeners();
  }

  /// Shows a ghost outline for one unsolved region without placing it.
  void useHint() {
    if (hintsLeft <= 0 || _solved) return;
    final target = _pickTargetRegion();
    if (target == null) return;

    hintPreviewRect = target.$2;
    hintedClueIndex = target.$1;
    hintsLeft--;
    hintsUsed++;
    _tick();
    notifyListeners();
  }

  /// Auto-places exactly one unsolved rectangle from the solution.
  void useWand() {
    if (wandsLeft <= 0 || _solved) return;
    final target = _pickTargetRegion();
    if (target == null) return;

    final sol = target.$2;
    _pushHistory();
    _placed.removeWhere((p) => p.rect.intersects(sol));
    _placed.add(PlacedRect(sol, _colorCounter++));
    if (hintPreviewRect != null && hintPreviewRect == sol) {
      _clearHintPreview();
    }
    wandsLeft--;
    wandUsed++;
    _tick();
    _checkSolved();
    notifyListeners();
  }

  void addHintCharges(int amount) {
    if (amount <= 0) return;
    hintsLeft += amount;
    notifyListeners();
  }

  void addWandCharges(int amount) {
    if (amount <= 0) return;
    wandsLeft += amount;
    notifyListeners();
  }

  void clearHintPreview() {
    if (hintPreviewRect == null && hintedClueIndex == null) return;
    _clearHintPreview();
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

  List<(int clueIndex, GridRect rect)> _unsolvedRegions() {
    final regions = <(int, GridRect)>[];
    for (var i = 0; i < _puzzle.solution.length; i++) {
      final sol = _puzzle.solution[i];
      final placed = _placed.any((p) => p.rect == sol);
      if (!placed) regions.add((i, sol));
    }
    return regions;
  }

  /// Prefers [lastInteractedClueIndex] when still unsolved, else smallest area.
  (int clueIndex, GridRect rect)? _pickTargetRegion() {
    final unsolved = _unsolvedRegions();
    if (unsolved.isEmpty) return null;

    final last = lastInteractedClueIndex;
    if (last != null) {
      for (final region in unsolved) {
        if (region.$1 == last) return region;
      }
    }

    unsolved.sort((a, b) => a.$2.area.compareTo(b.$2.area));
    return unsolved.first;
  }

  void _noteClueInteraction(int row, int col) {
    for (var i = 0; i < _puzzle.clues.length; i++) {
      final clue = _puzzle.clues[i];
      if (clue.row == row && clue.col == col) {
        lastInteractedClueIndex = i;
        return;
      }
    }
  }

  void _clearHintPreview() {
    hintPreviewRect = null;
    hintedClueIndex = null;
  }

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
