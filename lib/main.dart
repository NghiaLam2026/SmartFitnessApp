import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase/supabase_client.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'features/scheduler/scheduler_calendar_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
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
