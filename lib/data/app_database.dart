import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CurrentWorkoutSessionData {
  const CurrentWorkoutSessionData({
    required this.workoutName,
    required this.exercises,
  });

  final String workoutName;
  final List<CurrentWorkoutExerciseData> exercises;
}

class CurrentWorkoutExerciseData {
  const CurrentWorkoutExerciseData({
    required this.exerciseEntryId,
    required this.exerciseId,
    required this.exerciseName,
    this.lastPerformedAt,
    this.lastSetCount,
    this.lastMaxWeight,
  });

  final int exerciseEntryId;
  final int exerciseId;
  final String exerciseName;
  final DateTime? lastPerformedAt;
  final int? lastSetCount;
  final double? lastMaxWeight;
}

class ExerciseLastPerformanceData {
  const ExerciseLastPerformanceData({
    required this.performedAt,
    required this.setCount,
    required this.maxWeight,
  });

  final DateTime performedAt;
  final int setCount;
  final double maxWeight;
}

class WorkoutDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get muscleGroupId =>
      integer().nullable().references(MuscleGroups, #id)();
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class MuscleGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get muscleGroupId =>
      integer().nullable().references(MuscleGroups, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutDefinitionId =>
      integer().references(WorkoutDefinitions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {workoutDefinitionId, exerciseId},
      ];
}

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutDefinitionId =>
      integer().nullable().references(WorkoutDefinitions, #id)();
  TextColumn get nameOverride => text().nullable()();
  DateTimeColumn get performedAt => dateTime()();
  TextColumn get notes => text().nullable()();
}

class ExerciseEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutSessionId =>
      integer().references(WorkoutSessions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
}

class SetEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseEntryId =>
      integer().references(ExerciseEntries, #id)();
  IntColumn get setIndex => integer().withDefault(const Constant(0))();
  RealColumn get weight => real().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gym_logbook.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [
    WorkoutDefinitions,
    MuscleGroups,
    Exercises,
    WorkoutExercises,
    WorkoutSessions,
    ExerciseEntries,
    SetEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  static final RegExp _nameCounterSuffixPattern = RegExp(r'^(.*) #(\d+)$');

  AppDatabase(super.executor);

  AppDatabase.open() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static Future<void> wipeFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gym_logbook.sqlite'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<int> createWorkoutForMuscleGroup({
    required int muscleGroupId,
    required List<int> exerciseIds,
    String? nameOverride,
    DateTime? performedAt,
  }) async {
    return transaction(() async {
      final workoutDefinitionId =
          await _getOrCreateWorkoutDefinitionForMuscleGroup(muscleGroupId);
      final baseName = nameOverride?.trim();
      final resolvedBaseName =
          (baseName != null && baseName.isNotEmpty) ? baseName : null;
      final uniqueNameOverride = resolvedBaseName == null
          ? null
          : await _buildUniqueWorkoutSessionName(resolvedBaseName);

      await batch((batch) {
        batch.insertAll(
          workoutExercises,
          [
            for (var i = 0; i < exerciseIds.length; i++)
              WorkoutExercisesCompanion.insert(
                workoutDefinitionId: workoutDefinitionId,
                exerciseId: exerciseIds[i],
                sortOrder: Value(i),
              ),
          ],
          mode: InsertMode.insertOrIgnore,
        );
      });

      final workoutSessionId = await into(workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          workoutDefinitionId: Value(workoutDefinitionId),
          nameOverride: Value(uniqueNameOverride),
          performedAt: performedAt ?? DateTime.now(),
        ),
      );

      await batch((batch) {
        batch.insertAll(
          exerciseEntries,
          [
            for (var i = 0; i < exerciseIds.length; i++)
              ExerciseEntriesCompanion.insert(
                workoutSessionId: workoutSessionId,
                exerciseId: exerciseIds[i],
                sortOrder: Value(i),
              ),
          ],
        );
      });

      return workoutSessionId;
    });
  }

  Future<String> _buildUniqueWorkoutSessionName(String baseName) async {
    final normalizedBaseName = _stripCounterSuffix(baseName);
    final existingRows = await (select(workoutSessions)
          ..where((tbl) => tbl.nameOverride.like('$normalizedBaseName%')))
        .get();

    var hasBaseName = false;
    var highestCounter = 1;
    for (final row in existingRows) {
      final existingName = row.nameOverride?.trim();
      if (existingName == null || existingName.isEmpty) {
        continue;
      }
      if (existingName == normalizedBaseName) {
        hasBaseName = true;
        continue;
      }

      final match = _nameCounterSuffixPattern.firstMatch(existingName);
      if (match == null) {
        continue;
      }

      final suffixBaseName = match.group(1)?.trim();
      final suffixCounter = int.tryParse(match.group(2) ?? '');
      if (suffixBaseName == normalizedBaseName && suffixCounter != null) {
        if (suffixCounter > highestCounter) {
          highestCounter = suffixCounter;
        }
      }
    }

    if (!hasBaseName && highestCounter == 1) {
      return normalizedBaseName;
    }

    return '$normalizedBaseName #${highestCounter + 1}';
  }

  String _stripCounterSuffix(String name) {
    final trimmed = name.trim();
    final match = _nameCounterSuffixPattern.firstMatch(trimmed);
    if (match == null) {
      return trimmed;
    }

    final base = match.group(1)?.trim();
    return (base == null || base.isEmpty) ? trimmed : base;
  }

  Future<int> _getOrCreateWorkoutDefinitionForMuscleGroup(
    int muscleGroupId,
  ) async {
    final existingDefinition = await (select(workoutDefinitions)
          ..where((tbl) => tbl.muscleGroupId.equals(muscleGroupId))
          ..limit(1))
        .getSingleOrNull();

    if (existingDefinition != null) {
      return existingDefinition.id;
    }

    final muscleGroup = await (select(muscleGroups)
          ..where((tbl) => tbl.id.equals(muscleGroupId))
          ..limit(1))
        .getSingle();

    return into(workoutDefinitions).insert(
      WorkoutDefinitionsCompanion.insert(
        name: muscleGroup.name,
        muscleGroupId: Value(muscleGroupId),
        isCustom: const Value(false),
      ),
    );
  }

  Future<CurrentWorkoutSessionData> loadCurrentWorkoutSessionData(
    int workoutSessionId,
  ) async {
    final session = await (select(workoutSessions)
          ..where((tbl) => tbl.id.equals(workoutSessionId))
          ..limit(1))
        .getSingle();

    String workoutName = session.nameOverride?.trim() ?? '';
    if (workoutName.isEmpty && session.workoutDefinitionId != null) {
      final definition = await (select(workoutDefinitions)
            ..where((tbl) => tbl.id.equals(session.workoutDefinitionId!))
            ..limit(1))
          .getSingleOrNull();
      workoutName = definition?.name ?? '';
    }
    if (workoutName.isEmpty) {
      workoutName = 'Current Workout';
    }

    final entryRows = await (select(exerciseEntries).join([
      innerJoin(exercises, exercises.id.equalsExp(exerciseEntries.exerciseId)),
    ])
          ..where(exerciseEntries.workoutSessionId.equals(workoutSessionId))
          ..orderBy([
            OrderingTerm(expression: exerciseEntries.sortOrder),
            OrderingTerm(expression: exerciseEntries.id),
          ]))
        .get();

    final exercisesWithHistory = <CurrentWorkoutExerciseData>[];
    for (final row in entryRows) {
      final entry = row.readTable(exerciseEntries);
      final exercise = row.readTable(exercises);
      final lastPerformance = await fetchLastPerformanceForExercise(
        exercise.id,
        excludeWorkoutSessionId: workoutSessionId,
      );

      exercisesWithHistory.add(
        CurrentWorkoutExerciseData(
          exerciseEntryId: entry.id,
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          lastPerformedAt: lastPerformance?.performedAt,
          lastSetCount: lastPerformance?.setCount,
          lastMaxWeight: lastPerformance?.maxWeight,
        ),
      );
    }

    return CurrentWorkoutSessionData(
      workoutName: workoutName,
      exercises: exercisesWithHistory,
    );
  }

  Future<ExerciseLastPerformanceData?> fetchLastPerformanceForExercise(
    int exerciseId, {
    int? excludeWorkoutSessionId,
  }) async {
    final latestEntryQuery = select(exerciseEntries).join([
      innerJoin(
        workoutSessions,
        workoutSessions.id.equalsExp(exerciseEntries.workoutSessionId),
      ),
    ])
      ..where(exerciseEntries.exerciseId.equals(exerciseId));

    if (excludeWorkoutSessionId != null) {
      latestEntryQuery.where(workoutSessions.id.isNotValue(excludeWorkoutSessionId));
    }

    latestEntryQuery
      ..orderBy([
        OrderingTerm(
          expression: workoutSessions.performedAt,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(expression: exerciseEntries.id, mode: OrderingMode.desc),
      ])
      ..limit(1);

    final latestEntryRow = await latestEntryQuery.getSingleOrNull();
    if (latestEntryRow == null) {
      return null;
    }

    final latestEntry = latestEntryRow.readTable(exerciseEntries);
    final latestSession = latestEntryRow.readTable(workoutSessions);

    final setCountExpression = setEntries.id.count();
    final maxWeightExpression = setEntries.weight.max();
    final aggregateRow = await (selectOnly(setEntries)
          ..addColumns([setCountExpression, maxWeightExpression])
          ..where(setEntries.exerciseEntryId.equals(latestEntry.id)))
        .getSingle();

    final setCount = aggregateRow.read(setCountExpression);
    final maxWeight = aggregateRow.read(maxWeightExpression);
    if (setCount == null || maxWeight == null || setCount <= 0) {
      return null;
    }

    return ExerciseLastPerformanceData(
      performedAt: latestSession.performedAt,
      setCount: setCount,
      maxWeight: maxWeight,
    );
  }

  Future<void> addSetForExerciseEntry({
    required int exerciseEntryId,
    required int repetitions,
    required double weight,
  }) async {
    final maxSetIndexExpression = setEntries.setIndex.max();
    final maxSetIndexRow = await (selectOnly(setEntries)
          ..addColumns([maxSetIndexExpression])
          ..where(setEntries.exerciseEntryId.equals(exerciseEntryId)))
        .getSingle();
    final maxSetIndex = maxSetIndexRow.read(maxSetIndexExpression);

    await into(setEntries).insert(
      SetEntriesCompanion.insert(
        exerciseEntryId: exerciseEntryId,
        setIndex: Value((maxSetIndex ?? -1) + 1),
        weight: Value(weight),
        repetitions: Value(repetitions),
      ),
    );
  }
}
