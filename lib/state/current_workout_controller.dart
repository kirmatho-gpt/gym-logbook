import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';

class WorkoutSetState {
  const WorkoutSetState({
    required this.repetitions,
    this.isValidated = false,
    this.validatedWeight,
  });

  final int repetitions;
  final bool isValidated;
  final double? validatedWeight;

  WorkoutSetState copyWith({
    int? repetitions,
    bool? isValidated,
    double? validatedWeight,
    bool clearValidatedWeight = false,
  }) {
    return WorkoutSetState(
      repetitions: repetitions ?? this.repetitions,
      isValidated: isValidated ?? this.isValidated,
      validatedWeight: clearValidatedWeight
          ? null
          : (validatedWeight ?? this.validatedWeight),
    );
  }
}

class CurrentWorkoutExerciseState {
  const CurrentWorkoutExerciseState({
    required this.exerciseEntryId,
    required this.exerciseId,
    required this.exerciseName,
    this.lastPerformedAt,
    this.lastSetCount,
    this.lastMaxWeight,
    this.configuredWeight = 20,
    this.isFinished = false,
    this.timerStartedAt,
    this.timeSinceLastValidation,
    this.timeSinceSetIndex,
    bool? isTimeSinceRunning = false,
    this.sets = const [
      WorkoutSetState(repetitions: 8),
      WorkoutSetState(repetitions: 8),
      WorkoutSetState(repetitions: 8),
      WorkoutSetState(repetitions: 8),
    ],
  }) : _isTimeSinceRunning = isTimeSinceRunning;

  final int exerciseEntryId;
  final int exerciseId;
  final String exerciseName;
  final DateTime? lastPerformedAt;
  final int? lastSetCount;
  final double? lastMaxWeight;
  final double configuredWeight;
  final bool isFinished;
  final DateTime? timerStartedAt;
  final Duration? timeSinceLastValidation;
  final int? timeSinceSetIndex;
  final bool? _isTimeSinceRunning;
  final List<WorkoutSetState> sets;

  bool get isTimeSinceRunning => _isTimeSinceRunning ?? false;

  int get validatedSetCount =>
      sets.where((setLine) => setLine.isValidated).length;

  CurrentWorkoutExerciseState copyWith({
    double? configuredWeight,
    bool? isFinished,
    DateTime? timerStartedAt,
    Duration? timeSinceLastValidation,
    int? timeSinceSetIndex,
    bool? isTimeSinceRunning,
    bool clearTimerStartedAt = false,
    bool clearTimeSinceLastValidation = false,
    bool clearTimeSinceSetIndex = false,
    List<WorkoutSetState>? sets,
    DateTime? lastPerformedAt,
    int? lastSetCount,
    double? lastMaxWeight,
    bool clearLastHistory = false,
  }) {
    return CurrentWorkoutExerciseState(
      exerciseEntryId: exerciseEntryId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      lastPerformedAt:
          clearLastHistory ? null : (lastPerformedAt ?? this.lastPerformedAt),
      lastSetCount: clearLastHistory ? null : (lastSetCount ?? this.lastSetCount),
      lastMaxWeight:
          clearLastHistory ? null : (lastMaxWeight ?? this.lastMaxWeight),
      configuredWeight: configuredWeight ?? this.configuredWeight,
      isFinished: isFinished ?? this.isFinished,
      timerStartedAt: clearTimerStartedAt
          ? null
          : (timerStartedAt ?? this.timerStartedAt),
      timeSinceLastValidation: clearTimeSinceLastValidation
          ? null
          : (timeSinceLastValidation ?? this.timeSinceLastValidation),
      timeSinceSetIndex: clearTimeSinceSetIndex
          ? null
          : (timeSinceSetIndex ?? this.timeSinceSetIndex),
      isTimeSinceRunning: isTimeSinceRunning ?? this.isTimeSinceRunning,
      sets: sets ?? this.sets,
    );
  }
}

class CurrentWorkoutController extends ChangeNotifier {
  CurrentWorkoutController({required AppDatabase database}) : _database = database;

  final AppDatabase _database;
  Timer? _timeSinceTicker;

  int? _workoutSessionId;
  String _workoutName = 'Current Workout';
  bool _isSavingSet = false;
  List<CurrentWorkoutExerciseState> _exercises = const [];

  int? get workoutSessionId => _workoutSessionId;
  String get workoutName => _workoutName;
  bool get hasActiveWorkout => _workoutSessionId != null && _exercises.isNotEmpty;
  bool get isSavingSet => _isSavingSet;
  List<CurrentWorkoutExerciseState> get exercises => _exercises;

  @override
  void dispose() {
    _timeSinceTicker?.cancel();
    super.dispose();
  }

  Future<void> startWorkout(int workoutSessionId) async {
    final data = await _database.loadCurrentWorkoutSessionData(workoutSessionId);

    _workoutSessionId = workoutSessionId;
    _workoutName = data.workoutName;
    _exercises = [
      for (final exercise in data.exercises)
        CurrentWorkoutExerciseState(
          exerciseEntryId: exercise.exerciseEntryId,
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          lastPerformedAt: exercise.lastPerformedAt,
          lastSetCount: exercise.lastSetCount,
          lastMaxWeight: exercise.lastMaxWeight,
          configuredWeight: exercise.lastMaxWeight ?? 20,
          sets: List<WorkoutSetState>.generate(
            4,
            (_) => const WorkoutSetState(repetitions: 8),
            growable: false,
          ),
        ),
    ];

    _syncTimeSinceTicker();
    notifyListeners();
  }

  void setTargetSets(int exerciseId, int setsCount) {
    _exercises = _freezeRunningTimers(_exercises)
        .map(
          (exercise) {
            if (exercise.exerciseId != exerciseId) {
              return exercise;
            }
            if (exercise.isFinished) {
              return exercise;
            }

            final minSets = exercise.validatedSetCount > 0
                ? exercise.validatedSetCount
                : 1;
            final nextCount = setsCount.clamp(minSets, 20);
            final currentSets = exercise.sets;

            if (nextCount == currentSets.length) {
              return exercise;
            }

            if (nextCount < currentSets.length) {
              return exercise.copyWith(
                sets: currentSets.sublist(0, nextCount),
              );
            }

            return exercise.copyWith(
              sets: [
                ...currentSets,
                ...List<WorkoutSetState>.generate(
                  nextCount - currentSets.length,
                  (_) => const WorkoutSetState(repetitions: 8),
                  growable: false,
                ),
              ],
            );
          },
        )
        .toList(growable: false);
    _syncTimeSinceTicker();
    notifyListeners();
  }

  void changeExerciseWeight({
    required int exerciseId,
    required double delta,
  }) {
    _exercises = _freezeRunningTimers(_exercises)
        .map(
          (exercise) {
            if (exercise.exerciseId != exerciseId) {
              return exercise;
            }
            if (exercise.isFinished) {
              return exercise;
            }
            final clamped =
                (exercise.configuredWeight + delta).clamp(0.0, 200.0);
            final stepped = ((clamped * 2).round() / 2).toDouble();
            return exercise.copyWith(configuredWeight: stepped);
          },
        )
        .toList(growable: false);
    _syncTimeSinceTicker();
    notifyListeners();
  }

  void changeSetRepetitions({
    required int exerciseId,
    required int setIndex,
    required int delta,
  }) {
    _exercises = _freezeRunningTimers(_exercises)
        .map(
          (exercise) {
            if (exercise.exerciseId != exerciseId ||
                setIndex < 0 ||
                setIndex >= exercise.sets.length) {
              return exercise;
            }
            if (exercise.isFinished) {
              return exercise;
            }

            final setLine = exercise.sets[setIndex];
            if (setLine.isValidated) {
              return exercise;
            }

            final updatedSets = exercise.sets.toList(growable: false);
            updatedSets[setIndex] = setLine.copyWith(
              repetitions: (setLine.repetitions + delta).clamp(1, 100),
            );

            return exercise.copyWith(sets: updatedSets);
          },
        )
        .toList(growable: false);
    _syncTimeSinceTicker();
    notifyListeners();
  }

  Future<void> validateSet({
    required int exerciseId,
    required int setIndex,
  }) async {
    final exercise = _exercises
        .where((item) => item.exerciseId == exerciseId)
        .cast<CurrentWorkoutExerciseState?>()
        .firstWhere((item) => item != null, orElse: () => null);

    if (exercise == null || _isSavingSet) {
      return;
    }
    if (exercise.isFinished) {
      return;
    }
    if (setIndex < 0 || setIndex >= exercise.sets.length) {
      return;
    }

    final setLine = exercise.sets[setIndex];
    if (setLine.isValidated) {
      return;
    }

    _isSavingSet = true;
    notifyListeners();

    try {
      await _database.addSetForExerciseEntry(
        exerciseEntryId: exercise.exerciseEntryId,
        repetitions: setLine.repetitions,
        weight: exercise.configuredWeight,
      );

      _exercises = _exercises
          .map(
            (item) {
              if (item.exerciseId != exerciseId) {
                if (!item.isTimeSinceRunning) {
                  return item;
                }
                return item.copyWith(
                  timeSinceLastValidation: _finalizeElapsed(item),
                  isTimeSinceRunning: false,
                  clearTimerStartedAt: true,
                );
              }
              if (setIndex < 0 || setIndex >= item.sets.length) {
                return item;
              }

              final updatedSets = item.sets.toList(growable: false);
              updatedSets[setIndex] = updatedSets[setIndex].copyWith(
                isValidated: true,
                validatedWeight: item.configuredWeight,
              );

              return item.copyWith(
                sets: updatedSets,
                timerStartedAt: DateTime.now(),
                timeSinceLastValidation: Duration.zero,
                timeSinceSetIndex: setIndex,
                isTimeSinceRunning: true,
              );
            },
          )
          .toList(growable: false);
      _syncTimeSinceTicker();
    } finally {
      _isSavingSet = false;
      notifyListeners();
    }
  }

  Future<void> finishExercise(int exerciseId) async {
    final exercise = _exercises
        .where((item) => item.exerciseId == exerciseId)
        .cast<CurrentWorkoutExerciseState?>()
        .firstWhere((item) => item != null, orElse: () => null);

    if (exercise == null || _isSavingSet || exercise.isFinished) {
      return;
    }

    _isSavingSet = true;
    notifyListeners();

    try {
      _exercises = _exercises
          .map(
            (item) {
              if (item.exerciseId != exerciseId) {
                if (!item.isTimeSinceRunning) {
                  return item;
                }
                return item.copyWith(
                  timeSinceLastValidation: _finalizeElapsed(item),
                  isTimeSinceRunning: false,
                  clearTimerStartedAt: true,
                );
              }
              return item.copyWith(
                isFinished: true,
                timerStartedAt: DateTime.now(),
                timeSinceLastValidation: Duration.zero,
                clearTimeSinceSetIndex: true,
                isTimeSinceRunning: true,
                sets: item.sets
                    .where((setLine) => setLine.isValidated)
                    .toList(growable: false),
              );
            },
          )
          .toList(growable: false);
      _syncTimeSinceTicker();
    } finally {
      _isSavingSet = false;
      notifyListeners();
    }
  }

  void clear() {
    _timeSinceTicker?.cancel();
    _timeSinceTicker = null;
    _workoutSessionId = null;
    _workoutName = 'Current Workout';
    _exercises = const [];
    notifyListeners();
  }

  Duration? _finalizeElapsed(CurrentWorkoutExerciseState exercise) {
    final existing = exercise.timeSinceLastValidation;
    if (exercise.isTimeSinceRunning && exercise.timerStartedAt != null) {
      return DateTime.now().difference(exercise.timerStartedAt!);
    }
    return existing;
  }

  List<CurrentWorkoutExerciseState> _freezeRunningTimers(
    List<CurrentWorkoutExerciseState> source,
  ) {
    return source
        .map((exercise) {
          if (!exercise.isTimeSinceRunning) {
            return exercise;
          }
          return exercise.copyWith(
            timeSinceLastValidation: _finalizeElapsed(exercise),
            isTimeSinceRunning: false,
            clearTimerStartedAt: true,
          );
        })
        .toList(growable: false);
  }

  void _syncTimeSinceTicker() {
    final hasRunningTimer = _exercises.any((exercise) => exercise.isTimeSinceRunning);
    if (!hasRunningTimer) {
      _timeSinceTicker?.cancel();
      _timeSinceTicker = null;
      return;
    }

    _timeSinceTicker ??=
        Timer.periodic(const Duration(seconds: 1), (_) => _tickTimeSince());
  }

  void _tickTimeSince() {
    var hasChanges = false;
    final now = DateTime.now();
    _exercises = _exercises
        .map((exercise) {
          if (!exercise.isTimeSinceRunning || exercise.timerStartedAt == null) {
            return exercise;
          }

          final nextElapsed = now.difference(exercise.timerStartedAt!);
          if (exercise.timeSinceLastValidation == nextElapsed) {
            return exercise;
          }

          hasChanges = true;
          return exercise.copyWith(timeSinceLastValidation: nextElapsed);
        })
        .toList(growable: false);

    if (hasChanges) {
      notifyListeners();
    }
    _syncTimeSinceTicker();
  }
}
