import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    // Check if URL is provided via environment variable
    const envUrl = String.fromEnvironment('AI_WORKOUT_BACKEND_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // Default based on platform
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return 'http://localhost:3000';
    } else {
      // Desktop or web
      return 'http://localhost:3000';
    }
  }
}