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
  bool _previewAreaMatchActive = false;
  int _colorCounter = 0;

  int hintsLeft = 6;
  int wandsLeft = 1;
  bool _solved = false;
  final Stopwatch _stopwatch = Stopwatch();

  /// Ghost outlines for hinted regions (not placed).
  final List<HintGhost> _hintGhosts = [];

  /// Clue the player last touched — wand and hint prefer this region.
  int? lastInteractedClueIndex;

  int hintsUsed = 0;
  int wandUsed = 0;
  int undoCount = 0;

  Puzzle get puzzle => _puzzle;
  List<PlacedRect> get placed => List.unmodifiable(_placed);
  List<HintGhost> get hintGhosts => List.unmodifiable(_hintGhosts);
  GridRect? get preview => _preview;
  /// True when the drag preview contains exactly one clue and its area equals
  /// that clue's value (even if the rectangle is not the correct shape).
  bool get previewAreaMatchesClue => _previewAreaMatchClueIndex() != null;
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
    _previewAreaMatchActive = false;
    _dragStartRow = null;
    _dragStartCol = null;
    _colorCounter = 0;
    hintsLeft = 6;
    wandsLeft = 1;
    _solved = false;
    _clearHintGhosts();
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
    _previewAreaMatchActive = false;
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
      final matches = _previewAreaMatchClueIndex() != null;
      if (matches && !_previewAreaMatchActive) {
        _previewAreaMatchActive = true;
        _areaMatchSnap();
      } else if (!matches) {
        _previewAreaMatchActive = false;
        _tick();
      }
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
    _previewAreaMatchActive = false;

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
        if (existing != null && !existing.wandPlaced) {
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
    if (_intersectsWandPlaced(rect)) return;

    _pushHistory();
    _placed.removeWhere((p) => p.rect.intersects(rect) && !p.wandPlaced);
    _placed.add(PlacedRect(rect, _colorCounter++));
    _hintGhosts.removeWhere((h) => h.rect == rect);
    _checkSolved();
  }

  bool _intersectsWandPlaced(GridRect rect) =>
      _placed.any((p) => p.wandPlaced && p.rect.intersects(rect));

  // --- Tools ----------------------------------------------------------------

  void eraseAt(int row, int col) {
    final existing = _rectAt(row, col);
    if (existing == null || existing.wandPlaced) return;
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
    final target = _pickHintTarget();
    if (target == null) return;

    _hintGhosts.add(
      HintGhost(
        clueIndex: target.$1,
        rect: target.$2,
        colorIndex: _colorCounter + _hintGhosts.length,
      ),
    );
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
    _placed.removeWhere((p) => p.rect.intersects(sol) && !p.wandPlaced);
    _placed.add(PlacedRect(sol, _colorCounter++, wandPlaced: true));
    _hintGhosts.removeWhere((h) => h.clueIndex == target.$1);
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

  void clearHintGhosts() {
    if (_hintGhosts.isEmpty) return;
    _clearHintGhosts();
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

  bool isRemovableAt(int row, int col) {
    final existing = _rectAt(row, col);
    return existing != null && !existing.wandPlaced;
  }

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

  /// Picks an unsolved region that does not already have a ghost hint.
  (int clueIndex, GridRect rect)? _pickHintTarget() {
    final hinted = _hintGhosts.map((h) => h.clueIndex).toSet();
    final unsolved =
        _unsolvedRegions().where((r) => !hinted.contains(r.$1)).toList();
    if (unsolved.isEmpty) return null;

    final last = lastInteractedClueIndex;
    if (last != null && !hinted.contains(last)) {
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

  /// Clue index when [preview] contains exactly one clue and its area matches
  /// that clue's value; otherwise `null`.
  int? _previewAreaMatchClueIndex() {
    final pv = _preview;
    if (pv == null) return null;

    int? matched;
    for (var i = 0; i < _puzzle.clues.length; i++) {
      final clue = _puzzle.clues[i];
      if (!pv.containsCell(clue.row, clue.col)) continue;
      if (matched != null) return null;
      matched = i;
    }
    if (matched == null) return null;

    final clue = _puzzle.clues[matched];
    return pv.area == clue.value ? matched : null;
  }

  void _clearHintGhosts() {
    _hintGhosts.clear();
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

  void _areaMatchSnap() {
    if (hapticsEnabled) HapticFeedback.lightImpact();
  }

  void _heavyTick() {
    if (hapticsEnabled) HapticFeedback.mediumImpact();
  }
}
