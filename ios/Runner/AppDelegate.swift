import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register for remote notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    // Set up Flutter local notifications
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle notification when app is in foreground
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    
    // Print full message.
    print(userInfo)
    
    // Change this to your preferred presentation option
    completionHandler([[.banner, .badge, .sound]])
  }
  
  // Handle notification tap when app is in background or terminated
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     didReceive response: UNNotificationResponse,
                                     withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    
    // Print full message.
    print(userInfo)
    
    // TODO: Handle deep linking based on notification payload
    
    completionHandler()
  }
  
  // Handle registration for remote notifications
  // TODO: Once OneSignal is set up, forward APNs token to OneSignal
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // TODO: Send device token to OneSignal
    print("APNs token retrieved: \(deviceToken)")
  }
  
  // Handle silent notifications
  override func application(_ application: UIApplication,
                           didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                           fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Print full message.
    print(userInfo)
    
    // TODO: Handle background notification processing
    
    completionHandler(UIBackgroundFetchResult.newData)
  }
}
