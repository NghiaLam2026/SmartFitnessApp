import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification service for handling push notifications via OneSignal + Supabase.
/// 
/// This service will:
/// - Initialize OneSignal and request permissions
/// - Register device tokens with Supabase
/// - Handle incoming notifications and deep linking
/// - Display local notifications when app is in foreground
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'fitness_notification_channel',
    'Fitness Notifications',
    description: 'General updates about your Smart Fitness account.',
    importance: Importance.high,
  );

  /// Initialize the notification service.
  /// 
  /// TODO: Once OneSignal is set up:
  /// 1. Initialize OneSignal with App ID
  /// 2. Request notification permissions
  /// 3. Get device push token
  /// 4. Register token with Supabase
  /// 5. Set up notification handlers
  Future<void> initialize() async {
    if (_initialised || kIsWeb) {
      return;
    }
    _initialised = true;

    // Configure local notifications (for displaying notifications when app is open)
    await _configureLocalNotifications();

    // TODO: Request OneSignal permissions
    // await _requestOneSignalPermissions();

    // TODO: Get OneSignal device token and register with Supabase
    // await _registerDeviceToken();

    // TODO: Set up OneSignal notification handlers
    // _setupOneSignalHandlers();

    debugPrint('NotificationService: initialized (OneSignal implementation pending)');
  }

  /// Configure local notifications for Android/iOS
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

  /// Handle notification tap
  Future<void> _onNotificationTap(NotificationResponse response) async {
    debugPrint('NotificationService: notification tapped -> ${response.payload}');
    // TODO: Parse payload and navigate to appropriate screen
    // Example: if payload contains route, navigate using go_router
  }

  /// Register device token with Supabase.
  /// 
  /// This will be called when OneSignal provides a device token.
  /// Stores token in Supabase 'device_tokens' table (to be created).
  // TODO: Uncomment and implement once OneSignal is set up
  // ignore: unused_element
  Future<void> _persistToken(String token, String platform) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('NotificationService: no authenticated user, skipping token sync.');
        return;
      }

    try {
      final deviceName = await _resolveDeviceName();
      final packageInfo = await PackageInfo.fromPlatform();

      // TODO: Update table name once created in Supabase
      // Expected table: device_tokens (id, user_id, token, platform, device_name, created_at, updated_at)
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform, // 'ios', 'android', or 'web'
        'device_name': '$deviceName (v${packageInfo.version})',
      });

      debugPrint('NotificationService: token synced for $deviceName ($platform)');
    } catch (error, stackTrace) {
      debugPrint('NotificationService: failed to persist token – $error');
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
    }
  }

  /// Resolve device name for display in Supabase
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

  /// Show local notification (for foreground notifications)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
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
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: data != null ? data.toString() : null,
    );
  }
}
