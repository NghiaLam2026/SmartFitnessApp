import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/supabase/supabase_client.dart';
import 'package:smart_fitness_app/features/scheduler/scheduler_calendar_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/recipes/presentation/recipe_library_page.dart';
import '../features/recipes/presentation/recipe_detail_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/injury/presentation/injury_planner_page.dart';
import '../features/exercises/presentation/exercise_library_page.dart';
import '../features/exercises/presentation/exercise_detail_page.dart';
import '../features/tracking/mock_test_tracker_screen.dart';
import '../features/workouts/presentation/workout_library_page.dart';
import '../features/workouts/presentation/create_workout_page.dart';
import '../features/workouts/presentation/ai_workout_page.dart';
import '../features/workouts/presentation/workout_detail_page.dart';
import '../features/news/presentation/news_feed_page.dart';
import '../features/wellness/presentation/meditation_page.dart';
import '../features/wellness/presentation/mood_calendar_page.dart';
import 'package:smart_fitness_app/features/events/presentation/create_event_page.dart';
import 'package:smart_fitness_app/features/events/presentation/event_detail_screen.dart';
import 'package:smart_fitness_app/features/events/presentation/event_page.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) {
      final bool isLoggedIn = supabase.auth.currentUser != null;
      final String location = state.matchedLocation;
      final params = state.uri.queryParameters;
      final justSignedUp = params['justSignedUp'] == '1';

      final bool isLoginRoute = location == '/login';
      // Require auth for any /home subtree
      if (!isLoggedIn && location.startsWith('/home')) return '/login';
      if (isLoggedIn && isLoginRoute && !justSignedUp) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'events',
            builder: (context, state) => const EventPage(),
            routes: [
              GoRoute(
                path: 'createEvent',
                builder: (context, state) => const CreateEventPage(),
              ),

              GoRoute(
                path: 'eventDetail/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return EventDetailScreen(eventId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'recipes',
            builder: (context, state) => const RecipeLibraryPage(),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (context, state) {
                  final id = (state.extra as String?) ?? '';
                  return RecipeDetailPage(recipeId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'exercises',
            builder: (context, state) => const ExerciseLibraryPage(),
          ),
          GoRoute(
            path: 'exercise/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ExerciseDetailPage(exerciseId: id);
            },
          ),
          GoRoute(
            path: 'activity-tracker',
            builder: (context, state) => const ActivityTrackerScreen(),
          ),
          GoRoute(
            path: 'injury',
            builder: (context, state) => const InjuryPlannerPage(),
          ),
          GoRoute(
            path: 'scheduler',
            builder: (context, state) => const SchedulerCalendarPage(),
          ),
          GoRoute(
            path: 'news',
            builder: (context, state) => const NewsFeedPage(),
          ),
          GoRoute(
            path: 'meditation',
            builder: (context, state) => const MeditationPage(),
          ),
          GoRoute(
            path: 'mood',
            builder: (context, state) => const MoodCalendarPage(),
          ),
          GoRoute(
            path: 'workouts',
            builder: (context, state) => const WorkoutLibraryPage(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateWorkoutPage(),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return CreateWorkoutPage(workoutId: id);
                },
              ),
              GoRoute(
                path: 'ai',
                builder: (context, state) => const AIWorkoutPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return WorkoutDetailPage(workoutId: id);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ],
  );
});
