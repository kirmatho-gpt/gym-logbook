import 'package:flutter/material.dart';

import '../data/app_database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  int _defaultSets = 4;
  int _defaultReps = 4;
  int _historyDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.database.loadAppSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _defaultSets = settings.defaultSets;
      _defaultReps = settings.defaultReps;
      _historyDays = settings.historyDays;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    await widget.database.saveAppSettings(
      defaultSets: _defaultSets,
      defaultReps: _defaultReps,
      historyDays: _historyDays,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Group Workout Params',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _StepperRow(
                  label: 'Default number of sets',
                  value: _defaultSets,
                  min: 1,
                  max: 20,
                  onChanged: (value) => setState(() => _defaultSets = value),
                ),
                const SizedBox(height: 10),
                _StepperRow(
                  label: 'Default number of reps',
                  value: _defaultReps,
                  min: 1,
                  max: 100,
                  onChanged: (value) => setState(() => _defaultReps = value),
                ),
                const SizedBox(height: 24),
                Text(
                  'History params',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _StepperRow(
                  label: 'Days of history',
                  value: _historyDays,
                  min: 1,
                  max: 365,
                  onChanged: (value) => setState(() => _historyDays = value),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              onPressed: value <= min ? null : () => onChanged(value - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: value >= max ? null : () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
