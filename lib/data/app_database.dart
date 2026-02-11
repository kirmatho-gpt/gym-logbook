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
    this.lastRepetitions,
    this.lastWeight,
  });

  final int exerciseEntryId;
  final int exerciseId;
  final String exerciseName;
  final DateTime? lastPerformedAt;
  final int? lastRepetitions;
  final double? lastWeight;
}

class ExerciseLastSetData {
  const ExerciseLastSetData({
    required this.performedAt,
    required this.repetitions,
    required this.weight,
  });

  final DateTime performedAt;
  final int repetitions;
  final double weight;
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
          nameOverride: Value(nameOverride?.trim().isNotEmpty == true
              ? nameOverride!.trim()
              : null),
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
      final lastSet = await fetchLastSetForExercise(
        exercise.id,
        excludeWorkoutSessionId: workoutSessionId,
      );

      exercisesWithHistory.add(
        CurrentWorkoutExerciseData(
          exerciseEntryId: entry.id,
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          lastPerformedAt: lastSet?.performedAt,
          lastRepetitions: lastSet?.repetitions,
          lastWeight: lastSet?.weight,
        ),
      );
    }

    return CurrentWorkoutSessionData(
      workoutName: workoutName,
      exercises: exercisesWithHistory,
    );
  }

  Future<ExerciseLastSetData?> fetchLastSetForExercise(
    int exerciseId, {
    int? excludeWorkoutSessionId,
  }) async {
    final query = select(setEntries).join([
      innerJoin(
        exerciseEntries,
        exerciseEntries.id.equalsExp(setEntries.exerciseEntryId),
      ),
      innerJoin(
        workoutSessions,
        workoutSessions.id.equalsExp(exerciseEntries.workoutSessionId),
      ),
    ])
      ..where(exerciseEntries.exerciseId.equals(exerciseId));

    if (excludeWorkoutSessionId != null) {
      query.where(workoutSessions.id.isNotValue(excludeWorkoutSessionId));
    }

    query
      ..orderBy([
        OrderingTerm(
          expression: workoutSessions.performedAt,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(expression: setEntries.setIndex, mode: OrderingMode.desc),
        OrderingTerm(expression: setEntries.id, mode: OrderingMode.desc),
      ])
      ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    final set = row.readTable(setEntries);
    final session = row.readTable(workoutSessions);
    return ExerciseLastSetData(
      performedAt: session.performedAt,
      repetitions: set.repetitions,
      weight: set.weight,
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
