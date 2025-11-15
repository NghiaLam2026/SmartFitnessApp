import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/supabase/supabase_client.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (not on web)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }

  // Initialize Supabase
  await initSupabase();

  // Initialize notification service
  if (!kIsWeb) {
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Notification service initialization error: $e');
    }
  }

  runApp(const ProviderScope(child: SmartFitnessApp()));
}

class SmartFitnessApp extends ConsumerWidget {
  const SmartFitnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Smart Fitness',
      theme: appTheme,
      routerConfig: router,
    );
  }
}
