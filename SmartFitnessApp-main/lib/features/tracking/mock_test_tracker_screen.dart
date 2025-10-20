import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'progress_repository.dart';

class ActivityTrackerScreen extends StatefulWidget {
  const ActivityTrackerScreen({super.key});

  @override
  State<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends State<ActivityTrackerScreen> {
  final ProgressRepository _progressRepo = ProgressRepository();
  Stream<StepCount>? _stepCountStream;
  int _steps = 0;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(_onStepCount).onError(_onError);
  }

  void _onStepCount(StepCount event) {
    setState(() => _steps = event.steps);
  }

  void _onError(error) {
    print('Pedometer error: $error');
  }

  Future<void> _saveProgress() async {
    try {
      // just example data for now — we’ll compute later
      await _progressRepo.addProgress(
        weight: 0.0, 
        caloriesBurned: (_steps * 0.04).toInt(), 
        stepsCount: _steps,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Progress saved!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Tracker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Steps: $_steps', style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProgress,
              child: const Text('Save Progress'),
            ),
          ],
        ),
      ),
    );
  }
}
