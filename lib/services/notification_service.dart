import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';

/// Background handler entrypoint. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase isn't guaranteed to be initialised in the background isolate.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance._handleRemoteMessage(message, fromBackground: true);
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'fitness_notification_channel',
    'Fitness Notifications',
    description: 'General updates about your Smart Fitness account.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialised || kIsWeb) {
      return;
    }
    _initialised = true;

    // Ensure notifications work on Android by creating the default channel.
    await _configureLocalNotifications();

    // Request permission on iOS/macOS and ensure auto-init is enabled everywhere.
    await _requestPermissions();

    // Configure background handler once at start-up.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Listen for runtime events.
    FirebaseMessaging.onMessage.listen(_handleRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);
    _messaging.onTokenRefresh.listen(_persistToken);

    // Persist the current token if available.
    await _syncInitialToken();

    // Handle a notification that launched the app.
    await _handleInitialMessage();
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_defaultChannel);
    }
  }

  Future<void> _requestPermissions() async {
    await _messaging.setAutoInitEnabled(true);

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: false,
        provisional: false,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    }
  }

  Future<void> _syncInitialToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _persistToken(token);
      }
    } catch (error, stackTrace) {
      debugPrint('NotificationService: failed to fetch token – $error');
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
    }
  }

  Future<void> _handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleRemoteMessage(initialMessage, openedApplication: true);
    }
  }

  Future<void> _handleRemoteMessage(
    RemoteMessage message, {
    bool openedApplication = false,
    bool fromBackground = false,
  }) async {
    if (!fromBackground) {
      await _showLocalNotification(message);
    }

    // TODO: route users into the app using message.data, if required.
    debugPrint('NotificationService: received message '
        '(opened=$openedApplication, background=$fromBackground) -> ${message.data}');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null && message.data.isEmpty) return;

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      message.hashCode,
      notification?.title ?? message.data['title'] as String?,
      notification?.body ?? message.data['body'] as String?,
      notificationDetails,
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  Future<void> _onNotificationTap(NotificationResponse response) async {
    debugPrint('NotificationService: notification tapped -> ${response.payload}');
    // TODO: add navigation handling based on response.payload when UX is ready.
  }

  Future<void> _persistToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('NotificationService: no authenticated user, skipping token sync.');
      return;
    }

    try {
      final deviceName = await _resolveDeviceName();
      final packageInfo = await PackageInfo.fromPlatform();

      await Supabase.instance.client.from('user_notification_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_name': '$deviceName (v${packageInfo.version})',
      });

      debugPrint('NotificationService: token synced for $deviceName');
    } catch (error, stackTrace) {
      debugPrint('NotificationService: failed to persist token – $error');
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
    }
  }

  Future<String> _resolveDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return '${info.manufacturer} ${info.model}';
    }
    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return '${info.name} (${info.systemName} ${info.systemVersion})';
    }
    if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      return '${info.computerName} (macOS ${info.osRelease})';
    }
    return 'Unknown Device';
  }

  Future<void> subscribeToTopic(String topic) => _messaging.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) => _messaging.unsubscribeFromTopic(topic);
}
