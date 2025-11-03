import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../exercises/infrastructure/exercises_repository.dart';
import '../application/workout_providers.dart';
import '../domain/workout_models.dart';

final uuid = Uuid();

class AIWorkoutPage extends ConsumerStatefulWidget {
  const AIWorkoutPage({super.key});

  @override
  ConsumerState<AIWorkoutPage> createState() => _AIWorkoutPageState();
}

class _AIWorkoutPageState extends ConsumerState<AIWorkoutPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'Hi! I\'m your AI fitness coach. Tell me what kind of workout you\'d like, and I\'ll create a personalized plan for you!',
      isUser: false,
      workoutPlan: null,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
      _messageController.clear();
    });
    _scrollToBottom();

    // Load available exercises
    final exercisesRepo = SupabaseExercisesRepository();
    final exercises = await exercisesRepo.fetchExercises(limit: 100);

    // Generate workout using AI
    final aiService = ref.read(aiWorkoutServiceProvider);
    
    setState(() {
      _messages.add(ChatMessage(
        text: '...',
        isUser: false,
        isLoading: true,
      ));
    });

    final result = await aiService.generateWorkout(message, exercises);

    setState(() {
      _messages.removeLast(); // Remove loading message
      _messages.add(ChatMessage(
        text: result.message,
        isUser: false,
        workoutPlan: result.plan,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _saveWorkoutPlan(WorkoutPlan plan) async {
    try {
      final repository = ref.read(workoutRepositoryProvider);
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create final plan with proper IDs
      final finalPlan = WorkoutPlan(
        id: uuid.v4(),
        title: plan.title,
        description: plan.description,
        userId: user.id,
        createdAt: DateTime.now(),
        isAIGenerated: true,
        exercises: plan.exercises.map((ex) {
          // Generate IDs for exercises and sets
          final exerciseId = uuid.v4();
          final sets = ex.sets.map((s) => s.copyWith(
            id: uuid.v4(),
            workoutExerciseId: exerciseId,
          )).toList();

          return ex.copyWith(
            id: exerciseId,
            sets: sets,
          );
        }).toList(),
      );

      await repository.createWorkoutPlan(finalPlan);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving workout: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Workout Generator'),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(message: message, onSave: _saveWorkoutPlan);
              },
            ),
          ),

          // Input field
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Describe your workout...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final WorkoutPlan? workoutPlan;
  final bool isLoading;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.workoutPlan,
    this.isLoading = false,
  });
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onSave});

  final ChatMessage message;
  final void Function(WorkoutPlan) onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.isLoading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16).copyWith(
                  topRight: message.isUser ? Radius.zero : null,
                  topLeft: message.isUser ? null : Radius.zero,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (message.workoutPlan != null) ...[
              const SizedBox(height: 12),
              WorkoutPreviewCard(
                plan: message.workoutPlan!,
                onSave: onSave,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WorkoutPreviewCard extends StatelessWidget {
  const WorkoutPreviewCard({
    super.key,
    required this.plan,
    required this.onSave,
  });

  final WorkoutPlan plan;
  final void Function(WorkoutPlan) onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (plan.description != null && plan.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    plan.description!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '${plan.exercises.length} exercises',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => onSave(plan),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add to My Workouts'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

