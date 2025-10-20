import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../workout/application/generator.dart';
import '../../workout/domain/models.dart';

class _GenResult {
  const _GenResult({this.plan, this.usedFallback = false});
  final WorkoutPlan? plan;
  final bool usedFallback;
}

class WorkoutAiPage extends StatefulWidget {
  const WorkoutAiPage({super.key, this.initialDifficulty});
  final WorkoutDifficulty? initialDifficulty;

  @override
  State<WorkoutAiPage> createState() => _WorkoutAiPageState();
}

class _WorkoutAiPageState extends State<WorkoutAiPage> {
  WorkoutGoal goal = WorkoutGoal.generalFitness;
  WorkoutDifficulty difficulty = WorkoutDifficulty.easy;
  int daysPerWeek = 3;
  int minutesPerSession = 30;
  final Set<EquipmentType> equipment = <EquipmentType>{EquipmentType.none, EquipmentType.dumbbells, EquipmentType.bands};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDifficulty != null) difficulty = widget.initialDifficulty!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Quick-Plan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text('Tell us a few things', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkoutGoal>(
              value: goal,
              decoration: const InputDecoration(labelText: 'Primary goal'),
              items: const [
                DropdownMenuItem(value: WorkoutGoal.generalFitness, child: Text('General Fitness')),
                DropdownMenuItem(value: WorkoutGoal.strength, child: Text('Strength')),
                DropdownMenuItem(value: WorkoutGoal.conditioning, child: Text('Conditioning')),
              ],
              onChanged: (v) => setState(() => goal = v ?? goal),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkoutDifficulty>(
              value: difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: const [
                DropdownMenuItem(value: WorkoutDifficulty.easy, child: Text('Easy')),
                DropdownMenuItem(value: WorkoutDifficulty.medium, child: Text('Medium')),
                DropdownMenuItem(value: WorkoutDifficulty.hard, child: Text('Hard')),
              ],
              onChanged: (v) => setState(() => difficulty = v ?? difficulty),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: daysPerWeek.toString(),
                    decoration: const InputDecoration(labelText: 'Days/week'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) setState(() => daysPerWeek = parsed.clamp(1, 6));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: minutesPerSession.toString(),
                    decoration: const InputDecoration(labelText: 'Minutes/session'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) setState(() => minutesPerSession = parsed.clamp(15, 60));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Equipment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: EquipmentType.values.map((e) {
                final bool selected = equipment.contains(e);
                return FilterChip(
                  label: Text(_label(e)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        equipment.remove(e);
                      } else {
                        equipment.add(e);
                      }
                      if (equipment.isEmpty) equipment.add(EquipmentType.none);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      final result = await _generatePlanViaBackend();
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      if (result.plan != null) {
                        context.push('/home/workout/preview', extra: result.plan);
                        if (result.usedFallback) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backend unavailable. Used local generator.')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to generate plan')),
                        );
                      }
                    },
              child: _isLoading ? const Text('Generating…') : const Text('Generate Plan'),
            )
          ],
        ),
      ),
    );
  }

  Future<_GenResult> _generatePlanViaBackend() async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.backendBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
    final payload = {
      'daysPerWeek': daysPerWeek,
      'minutesPerSession': minutesPerSession,
      'equipment': equipment.map((e) => _equipKey(e)).toList(),
      'goal': _goalKey(goal),
      'difficulty': _difficultyKey(difficulty),
      'constraints': [],
      'preferences': [],
    };
    try {
      final res = await dio.post('/generate', data: payload);
      final data = res.data as Map<String, dynamic>;
      final planJson = data['plan'] as Map<String, dynamic>;
      return _GenResult(plan: _planFromJson(planJson), usedFallback: false);
    } catch (e) {
      // Fallback to local generator so UX continues
      final input = WorkoutGeneratorInput(
        goal: goal,
        difficulty: difficulty,
        daysPerWeek: daysPerWeek,
        minutesPerSession: minutesPerSession,
        equipment: equipment.toList(),
      );
      return _GenResult(plan: WorkoutGenerator.generatePlan(input), usedFallback: true);
    }
  }

  WorkoutPlan _planFromJson(Map<String, dynamic> json) {
    final sessions = (json['sessions'] as List<dynamic>).map((s) {
      final exercises = (s['exercises'] as List<dynamic>).map((e) {
        final ex = Exercise(
          id: 'ai_${e['name']}',
          name: e['name'] as String,
          primaryMuscles: const <String>[],
          equipment: EquipmentType.none,
        );
        final presc = SetPrescription(
          sets: (e['sets'] as num).toInt(),
          repsMin: (e['repsMin'] as num).toInt(),
          repsMax: (e['repsMax'] as num).toInt(),
          restSeconds: (e['restSeconds'] as num).toInt(),
          targetWeightKg: (e['targetWeightKg'] as num?)?.toDouble(),
        );
        return SessionExercise(exercise: ex, prescription: presc);
      }).toList();
      return WorkoutSession(
        id: s['id'] as String,
        title: s['title'] as String,
        estimatedDuration: Duration(seconds: (s['estimatedDurationSeconds'] as num).toInt()),
        difficulty: _difficultyFromKey(s['difficulty'] as String),
        exercises: exercises,
      );
    }).toList();
    return WorkoutPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      goal: _goalFromKey(json['goal'] as String),
      weeks: (json['weeks'] as num).toInt(),
      sessions: sessions,
    );
  }

  String _equipKey(EquipmentType e) {
    switch (e) {
      case EquipmentType.none:
        return 'none';
      case EquipmentType.bands:
        return 'bands';
      case EquipmentType.dumbbells:
        return 'dumbbells';
      case EquipmentType.barbell:
        return 'barbell';
      case EquipmentType.machines:
        return 'machines';
    }
  }

  String _goalKey(WorkoutGoal g) {
    switch (g) {
      case WorkoutGoal.generalFitness:
        return 'generalFitness';
      case WorkoutGoal.strength:
        return 'strength';
      case WorkoutGoal.conditioning:
        return 'conditioning';
    }
  }

  String _difficultyKey(WorkoutDifficulty d) {
    switch (d) {
      case WorkoutDifficulty.easy:
        return 'easy';
      case WorkoutDifficulty.medium:
        return 'medium';
      case WorkoutDifficulty.hard:
        return 'hard';
    }
  }

  WorkoutGoal _goalFromKey(String k) {
    switch (k) {
      case 'generalFitness':
        return WorkoutGoal.generalFitness;
      case 'strength':
        return WorkoutGoal.strength;
      case 'conditioning':
        return WorkoutGoal.conditioning;
      default:
        return WorkoutGoal.generalFitness;
    }
  }

  WorkoutDifficulty _difficultyFromKey(String k) {
    switch (k) {
      case 'easy':
        return WorkoutDifficulty.easy;
      case 'medium':
        return WorkoutDifficulty.medium;
      case 'hard':
        return WorkoutDifficulty.hard;
      default:
        return WorkoutDifficulty.easy;
    }
  }
  String _label(EquipmentType e) {
    switch (e) {
      case EquipmentType.none:
        return 'No equipment';
      case EquipmentType.bands:
        return 'Bands';
      case EquipmentType.dumbbells:
        return 'Dumbbells';
      case EquipmentType.barbell:
        return 'Barbell';
      case EquipmentType.machines:
        return 'Machines';
    }
  }
}


