import 'package:drift/drift.dart';

part 'app_database.g.dart';

class WorkoutDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text().nullable()();
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
  Set<Column> get uniqueKeys => {
        {workoutDefinitionId, exerciseId},
      };
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

@DriftDatabase(
  tables: [
    WorkoutDefinitions,
    Exercises,
    WorkoutExercises,
    WorkoutSessions,
    ExerciseEntries,
    SetEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
