import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Conditional import - Platform only available on mobile/desktop
import 'dart:io' if (dart.library.html) 'app_constants_web_stub.dart';

/// Application constants
/// 
/// All API keys and sensitive configuration should be loaded from environment variables.
/// Never commit API keys directly in code.
class AppConstants {
  // AI Workout Generator Backend URL
  // For Android emulator: use http://10.0.2.2:3000
  // For iOS simulator: use http://localhost:3000
  // For physical device: use your computer's IP address (e.g., http://192.168.1.100:3000)
  // For production: use your deployed backend URL
  static String get aiWorkoutBackendUrl {
    // Priority 1: Check dotenv (for Vercel environment variables)
    final dotenvUrl = dotenv.maybeGet('AI_WORKOUT_BACKEND_URL');
    if (dotenvUrl != null && dotenvUrl.isNotEmpty) {
      return dotenvUrl;
    }
    
    // Priority 2: Check build-time environment variable (--dart-define)
    const envUrl = String.fromEnvironment('AI_WORKOUT_BACKEND_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // Web check - for Vercel/production, use production URL or require env var
    if (kIsWeb) {
      // On web/Vercel, localhost won't work - return a placeholder
      // User should set AI_WORKOUT_BACKEND_URL in Vercel environment variables
      // For now, return a placeholder that will show an error if backend is called
      return 'https://backend-nine-theta-13.vercel.app'; // Replace with your actual backend URL
    }
    
    // Mobile platforms - use Platform (only available on mobile/desktop)
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return 'http://localhost:3000';
    } else {
      // Desktop
      return 'http://localhost:3000';
    }
  }
}
