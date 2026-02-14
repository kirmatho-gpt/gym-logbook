import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/app_database.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  int? _selectedMuscleGroupId;
  int? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final descriptionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: compact ? 11.5 : 12,
    );

    final muscleGroupsStream = (widget.database.select(widget.database.muscleGroups)
          ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.name)]))
        .watch();

    final selectedMuscleGroupId = _selectedMuscleGroupId;
    final exercisesStream = selectedMuscleGroupId == null
        ? const Stream<List<Exercise>>.empty()
        : (widget.database.select(widget.database.exercises)
              ..where((tbl) => tbl.muscleGroupId.equals(selectedMuscleGroupId))
              ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.name)]))
            .watch();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<MuscleGroup>>(
            stream: muscleGroupsStream,
            builder: (context, snapshot) {
              final muscleGroups = snapshot.data ?? const <MuscleGroup>[];
              return DropdownButtonFormField<int>(
                value: _selectedMuscleGroupId,
                isDense: true,
                itemHeight: 48,
                menuMaxHeight: 280,
                decoration: _dropdownDecoration(
                  context,
                  label: 'Muscle group',
                ),
                items: [
                  for (final group in muscleGroups)
                    DropdownMenuItem<int>(
                      value: group.id,
                      child: Text(
                        group.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMuscleGroupId = value;
                    _selectedExerciseId = null;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exercises',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_selectedMuscleGroupId != null)
                IconButton(
                  tooltip: 'Add exercise',
                  onPressed: () => _showCreateExerciseDialog(
                    _selectedMuscleGroupId!,
                  ),
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedMuscleGroupId == null
                ? const Center(
                    child: Text('Select a muscle group to see exercises.'),
                  )
                : StreamBuilder<List<Exercise>>(
                    stream: exercisesStream,
                    builder: (context, snapshot) {
                      final exercises = snapshot.data ?? const <Exercise>[];
                      final selectedExerciseId = _selectedExerciseId;

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          exercises.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (selectedExerciseId != null &&
                          !exercises.any((exercise) => exercise.id == selectedExerciseId)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _selectedExerciseId = null;
                          });
                        });
                      }

                      if (exercises.isEmpty) {
                        return const Center(
                          child: Text('No exercises for this muscle group.'),
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: exercises.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final exercise = exercises[index];
                                final isSelected = exercise.id == selectedExerciseId;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ListTile(
                                      selected: isSelected,
                                      title: Text(exercise.name),
                                      onTap: () {
                                        setState(() {
                                          _selectedExerciseId = exercise.id;
                                        });
                                      },
                                    ),
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          10,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary.withValues(
                                                    alpha: 0.35,
                                                  ),
                                            ),
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.22),
                                          ),
                                          child: FutureBuilder<String?>(
                                            future: widget.database
                                                .fetchExerciseImagePath(
                                              exercise.id,
                                            ),
                                            builder: (context, imageSnapshot) {
                                              final imagePath =
                                                  imageSnapshot.data;
                                              final expectedPath = widget
                                                  .database
                                                  .buildStandardExerciseImagePath(
                                                exercise.id,
                                              );
                                              final resolvedImagePath =
                                                  imagePath ?? expectedPath;

                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        style: descriptionStyle,
                                                        children: [
                                                          const TextSpan(
                                                            text: 'Exercise ID: ',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                '${exercise.id}\n',
                                                          ),
                                                          const TextSpan(
                                                            text: 'Notes: ',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                '${(exercise.notes == null || exercise.notes!.trim().isEmpty) ? '-' : exercise.notes!}\n',
                                                          ),
                                                          const TextSpan(
                                                            text: 'Created: ',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: _formatDate(
                                                              exercise.createdAt,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  _ExerciseImagePreview(
                                                    imagePath: resolvedImagePath,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  InputDecoration _dropdownDecoration(
    BuildContext context, {
    required String label,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
      ),
    );
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Future<void> _showCreateExerciseDialog(int muscleGroupId) async {
    final createdExerciseId = await showDialog<int>(
      context: context,
      builder: (_) => _CreateExerciseDialog(
        database: widget.database,
        muscleGroupId: muscleGroupId,
      ),
    );

    if (!mounted || createdExerciseId == null) {
      return;
    }

    setState(() {
      _selectedExerciseId = createdExerciseId;
    });
  }
}

class _CreateExerciseDialog extends StatefulWidget {
  const _CreateExerciseDialog({
    required this.database,
    required this.muscleGroupId,
  });

  final AppDatabase database;
  final int muscleGroupId;

  @override
  State<_CreateExerciseDialog> createState() => _CreateExerciseDialogState();
}

class _CreateExerciseDialogState extends State<_CreateExerciseDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  String? _pickedImageFilePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New exercise'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Pick image'),
          ),
          const SizedBox(height: 6),
          Text(
            _pickedImageFilePath == null
                ? 'No image selected'
                : p.basename(_pickedImageFilePath!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open file picker: $error')),
        );
      }
      return;
    }

    if (picked == null || picked.files.isEmpty) {
      return;
    }
    final selectedPath = picked.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }

    setState(() {
      _pickedImageFilePath = selectedPath;
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final notes = _notesController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Exercise name is required.')),
      );
      return;
    }

    final nameExists = await widget.database.exerciseNameExists(name);
    if (nameExists) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Exercise name already exists.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    int? createdExerciseId;
    try {
      createdExerciseId =
          await widget.database.into(widget.database.exercises).insert(
                ExercisesCompanion.insert(
                  name: name,
                  muscleGroupId: drift.Value(widget.muscleGroupId),
                  notes: drift.Value(notes.isEmpty ? null : notes),
                ),
              );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not create exercise.')),
        );
        setState(() {
          _isSaving = false;
        });
      }
      return;
    }

    if (_pickedImageFilePath != null && createdExerciseId != null) {
      try {
        final standardPath =
            widget.database.buildStandardExerciseImagePath(createdExerciseId);
        final absoluteTargetPath = _resolveProjectAssetAbsolutePath(standardPath);
        final targetFile = File(absoluteTargetPath);
        await targetFile.parent.create(recursive: true);
        await File(_pickedImageFilePath!).copy(targetFile.path);
        await widget.database.setExerciseImagePath(
          createdExerciseId,
          imagePath: standardPath,
        );
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Exercise created, but image could not be copied.'),
            ),
          );
        }
      }
    }

    if (!mounted || createdExerciseId == null) {
      return;
    }

    Navigator.of(context).pop(createdExerciseId);
  }
}

String _resolveProjectAssetAbsolutePath(String relativePath) {
  var current = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    if (File(p.join(current.path, 'pubspec.yaml')).existsSync()) {
      return p.join(current.path, relativePath);
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
  return p.join(Directory.current.path, relativePath);
}

class _ExerciseImagePreview extends StatelessWidget {
  const _ExerciseImagePreview({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final imagePath = this.imagePath;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? Icon(
              Icons.image_outlined,
              color: Theme.of(context).colorScheme.outline,
            )
          : Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
    );
  }
}
