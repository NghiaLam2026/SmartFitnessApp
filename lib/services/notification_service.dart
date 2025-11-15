import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_client.dart';

/// Background message handler - must be a top-level function
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  await NotificationService.instance._handleRemoteMessage(message, fromBackground: true);
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'fitness_notification_channel',
    'Fitness Notifications',
    description: 'Notifications for fitness app events',
    importance: Importance.high,
  );

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialised || kIsWeb) {
      return;
    }
    _initialised = true;

    try {
      debugPrint('Initializing notification service...');

      // Request permissions for iOS
      await _requestPermissions();

      // Initialize local notifications
      await _configureLocalNotifications();

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleRemoteMessage);

      // Set up message opened handler (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _handleRemoteMessage(message, openedApplication: true),
      );

      // Get initial token and persist to Supabase
      await _syncInitialToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_persistToken);

      // Check for initial message (app opened from notification tap)
      await _handleInitialMessage();

      debugPrint('Notification service initialized successfully');
    } catch (error, stackTrace) {
      debugPrint('Error initializing notification service: $error');
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
    }
  }

  /// Request notification permissions (iOS/macOS)
  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('Notification permissions: ${settings.authorizationStatus}');
    } else if (Platform.isAndroid) {
      // Android 13+ requires runtime permission
      // This is handled by flutter_local_notifications
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        debugPrint('Android notification permission granted: $granted');
      }
    }
  }

  /// Configure local notifications for Android/iOS
  Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    // Create notification channel for Android
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_defaultChannel);
    }
  }

  /// iOS background notification handler
  Future<void> _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    debugPrint('iOS local notification: $title - $body - $payload');
  }

  /// Handle notification tap
  Future<void> _onNotificationTap(NotificationResponse response) async {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Parse payload and navigate using GoRouter
    // Example: if payload contains route, navigate to that route
  }

  /// Handle background notification tap
  static Future<void> _onDidReceiveBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint('Background notification tapped: ${response.payload}');
  }

  /// Handle remote messages
  Future<void> _handleRemoteMessage(
    RemoteMessage message, {
    bool openedApplication = false,
    bool fromBackground = false,
  }) async {
    debugPrint(
      'Handling remote message (opened=$openedApplication, background=$fromBackground): '
      '${message.messageId}',
    );

    // Show local notification if app is in foreground
    if (!openedApplication && !fromBackground) {
      await _showLocalNotification(message);
    }

    // TODO: Handle deep linking based on notification data
    // if (openedApplication || message.data.containsKey('route')) {
    //   final route = message.data['route'];
    //   // Navigate using GoRouter
    // }
  }

  /// Show local notification (for foreground)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fitness_notification_channel',
      'Fitness Notifications',
      channelDescription: 'Notifications for fitness app events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: _encodePayload(message.data),
    );
  }

  /// Get FCM token and persist to Supabase
  Future<void> _syncInitialToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _persistToken(token);
      }
    } catch (e) {
      debugPrint('Error syncing initial token: $e');
    }
  }

  /// Persist FCM token to Supabase
  Future<void> _persistToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('NotificationService: No authenticated user, skipping token sync');
        return;
      }

      final deviceName = await _resolveDeviceName();

      await supabase.from('user_notification_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_name': deviceName,
      });

      debugPrint('NotificationService: Token persisted for $deviceName');
    } catch (error, stackTrace) {
      debugPrint('NotificationService: Failed to persist token - $error');
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
    }
  }

  /// Resolve device name for storage
  Future<String> _resolveDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model} (v${packageInfo.version})';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return '${info.name} (${info.systemName} ${info.systemVersion}) (v${packageInfo.version})';
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        return '${info.computerName} (macOS ${info.osRelease}) (v${packageInfo.version})';
      }
    } catch (e) {
      debugPrint('Error resolving device name: $e');
    }

    return 'Unknown Device (v${packageInfo.version})';
  }

  /// Handle initial message when app is opened from notification
  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleRemoteMessage(initialMessage, openedApplication: true);
      }
    } catch (e) {
      debugPrint('Error handling initial message: $e');
    }
  }

  /// Encode payload for local notification
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// Subscribe to a notification topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('NotificationService: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a notification topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('NotificationService: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }
}

