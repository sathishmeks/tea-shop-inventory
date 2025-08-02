import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notification service
  static Future<void> init() async {
    await _instance._initializeAwesomeNotifications();
    await _instance._initializeFlutterLocalNotifications();
  }

  // Initialize Awesome Notifications
  Future<void> _initializeAwesomeNotifications() async {
    await AwesomeNotifications().initialize(
      null, // Use default app icon
      [
        NotificationChannel(
          channelKey: 'stock_alerts',
          channelName: 'Stock Alerts',
          channelDescription: 'Notifications for low stock items',
          defaultColor: const Color(0xFF4CAF50),
          ledColor: Colors.orange,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'critical_stock',
          channelName: 'Critical Stock Alerts',
          channelDescription: 'Critical notifications for out of stock items',
          defaultColor: const Color(0xFFFF5722),
          ledColor: Colors.red,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'restock_reminders',
          channelName: 'Restock Reminders',
          channelDescription: 'Periodic reminders to restock items',
          defaultColor: const Color(0xFF2196F3),
          ledColor: Colors.blue,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
          playSound: false,
          enableVibration: false,
        ),
      ],
    );
  }

  // Initialize Flutter Local Notifications
  Future<void> _initializeFlutterLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // Handle notification tap
  static void _onNotificationTap(NotificationResponse notificationResponse) {
    // Handle navigation when notification is tapped
    // You can add navigation logic here
    print('Notification tapped: ${notificationResponse.payload}');
  }

  // Request notification permissions
  static Future<bool> requestPermissions() async {
    final awesomePermission = await AwesomeNotifications().isNotificationAllowed();
    if (!awesomePermission) {
      return await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    return true;
  }

  // Show low stock notification
  Future<void> showLowStockNotification({
    required String productName,
    required int currentStock,
    required int minimumStock,
    required String unit,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'stock_alerts',
        title: '📦 Low Stock Alert',
        body: '$productName is running low!\nCurrent: $currentStock $unit (Min: $minimumStock $unit)',
        bigPicture: null,
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'low_stock',
          'product_name': productName,
          'current_stock': currentStock.toString(),
          'minimum_stock': minimumStock.toString(),
        },
      ),
    );
  }

  // Show critical stock notification (out of stock)
  Future<void> showCriticalStockNotification({
    required String productName,
    required String unit,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'critical_stock',
        title: '🚨 Critical: Out of Stock!',
        body: '$productName is completely out of stock!\nImmediate restocking required.',
        bigPicture: null,
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'out_of_stock',
          'product_name': productName,
        },
      ),
    );
  }

  // Show multiple low stock items summary
  Future<void> showLowStockSummaryNotification({
    required int lowStockCount,
    required int outOfStockCount,
  }) async {
    String title = '📊 Stock Alert Summary';
    String body = '';
    
    if (outOfStockCount > 0 && lowStockCount > 0) {
      body = '$outOfStockCount items out of stock, $lowStockCount items low on stock';
    } else if (outOfStockCount > 0) {
      body = '$outOfStockCount items are completely out of stock';
    } else if (lowStockCount > 0) {
      body = '$lowStockCount items are running low on stock';
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: lowStockCount > 0 ? 'stock_alerts' : 'critical_stock',
        title: title,
        body: body,
        bigPicture: null,
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'stock_summary',
          'low_stock_count': lowStockCount.toString(),
          'out_of_stock_count': outOfStockCount.toString(),
        },
      ),
    );
  }

  // Show restock reminder notification
  Future<void> showRestockReminderNotification({
    required List<String> productNames,
  }) async {
    String body = productNames.length == 1
        ? 'Don\'t forget to restock ${productNames.first}'
        : 'Reminder: ${productNames.length} items need restocking';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'restock_reminders',
        title: '⏰ Restock Reminder',
        body: body,
        bigPicture: null,
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'restock_reminder',
          'product_count': productNames.length.toString(),
        },
      ),
    );
  }

  // Schedule periodic stock check notifications
  Future<void> schedulePeriodicStockCheck() async {
    // Cancel any existing scheduled notifications
    await cancelAllScheduledNotifications();

    // Schedule daily stock check at 9 AM
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999, // Fixed ID for daily check
        channelKey: 'restock_reminders',
        title: '📋 Daily Stock Check',
        body: 'Time for your daily inventory review',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: 9,
        minute: 0,
        second: 0,
        repeats: true,
      ),
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  // Cancel scheduled notifications only
  Future<void> cancelAllScheduledNotifications() async {
    await AwesomeNotifications().cancelAllSchedules();
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  // Open notification settings
  static Future<void> openNotificationSettings() async {
    await AwesomeNotifications().showNotificationConfigPage();
  }
}
