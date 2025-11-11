import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/supabase/supabase_client.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Initialize Supabase
  await initSupabase();

  // Initialize notification service
  await NotificationService.instance.initialize();

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
