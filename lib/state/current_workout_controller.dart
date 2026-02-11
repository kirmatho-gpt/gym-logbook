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
    this.lastRepetitions,
    this.lastWeight,
    this.configuredWeight = 20,
    this.isFinished = false,
    this.sets = const [
      WorkoutSetState(repetitions: 8),
      WorkoutSetState(repetitions: 8),
      WorkoutSetState(repetitions: 8),
      WorkoutSetState(repetitions: 8),
    ],
  });

  final int exerciseEntryId;
  final int exerciseId;
  final String exerciseName;
  final DateTime? lastPerformedAt;
  final int? lastRepetitions;
  final double? lastWeight;
  final double configuredWeight;
  final bool isFinished;
  final List<WorkoutSetState> sets;

  int get validatedSetCount =>
      sets.where((setLine) => setLine.isValidated).length;

  CurrentWorkoutExerciseState copyWith({
    double? configuredWeight,
    bool? isFinished,
    List<WorkoutSetState>? sets,
    DateTime? lastPerformedAt,
    int? lastRepetitions,
    double? lastWeight,
    bool clearLastHistory = false,
  }) {
    return CurrentWorkoutExerciseState(
      exerciseEntryId: exerciseEntryId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      lastPerformedAt:
          clearLastHistory ? null : (lastPerformedAt ?? this.lastPerformedAt),
      lastRepetitions:
          clearLastHistory ? null : (lastRepetitions ?? this.lastRepetitions),
      lastWeight: clearLastHistory ? null : (lastWeight ?? this.lastWeight),
      configuredWeight: configuredWeight ?? this.configuredWeight,
      isFinished: isFinished ?? this.isFinished,
      sets: sets ?? this.sets,
    );
  }
}

class CurrentWorkoutController extends ChangeNotifier {
  CurrentWorkoutController({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  int? _workoutSessionId;
  String _workoutName = 'Current Workout';
  bool _isSavingSet = false;
  List<CurrentWorkoutExerciseState> _exercises = const [];

  int? get workoutSessionId => _workoutSessionId;
  String get workoutName => _workoutName;
  bool get hasActiveWorkout => _workoutSessionId != null && _exercises.isNotEmpty;
  bool get isSavingSet => _isSavingSet;
  List<CurrentWorkoutExerciseState> get exercises => _exercises;

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
          lastRepetitions: exercise.lastRepetitions,
          lastWeight: exercise.lastWeight,
          configuredWeight: exercise.lastWeight ?? 20,
          sets: List<WorkoutSetState>.generate(
            4,
            (_) => const WorkoutSetState(repetitions: 8),
            growable: false,
          ),
        ),
    ];

    notifyListeners();
  }

  void setTargetSets(int exerciseId, int setsCount) {
    _exercises = _exercises
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
    notifyListeners();
  }

  void changeExerciseWeight({
    required int exerciseId,
    required double delta,
  }) {
    _exercises = _exercises
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
    notifyListeners();
  }

  void changeSetRepetitions({
    required int exerciseId,
    required int setIndex,
    required int delta,
  }) {
    _exercises = _exercises
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
              if (item.exerciseId != exerciseId ||
                  setIndex < 0 ||
                  setIndex >= item.sets.length) {
                return item;
              }

              final updatedSets = item.sets.toList(growable: false);
              updatedSets[setIndex] = updatedSets[setIndex].copyWith(
                isValidated: true,
                validatedWeight: item.configuredWeight,
              );

              return item.copyWith(
                sets: updatedSets,
              );
            },
          )
          .toList(growable: false);
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
      for (var i = 0; i < exercise.sets.length; i++) {
        final setLine = exercise.sets[i];
        if (setLine.isValidated) {
          continue;
        }
        await _database.addSetForExerciseEntry(
          exerciseEntryId: exercise.exerciseEntryId,
          repetitions: setLine.repetitions,
          weight: exercise.configuredWeight,
        );
      }

      _exercises = _exercises
          .map(
            (item) {
              if (item.exerciseId != exerciseId) {
                return item;
              }
              return item.copyWith(
                isFinished: true,
                sets: [
                  for (final setLine in item.sets)
                    setLine.copyWith(
                      isValidated: true,
                      validatedWeight:
                          setLine.validatedWeight ?? item.configuredWeight,
                    ),
                ],
              );
            },
          )
          .toList(growable: false);
    } finally {
      _isSavingSet = false;
      notifyListeners();
    }
  }

  void clear() {
    _workoutSessionId = null;
    _workoutName = 'Current Workout';
    _exercises = const [];
    notifyListeners();
  }
}
