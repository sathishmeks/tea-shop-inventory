import 'package:flutter/material.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/stock_monitoring_service.dart';
import '../../widgets/loading_widget.dart';

class StockNotificationSettingsPage extends StatefulWidget {
  const StockNotificationSettingsPage({super.key});

  @override
  State<StockNotificationSettingsPage> createState() => _StockNotificationSettingsPageState();
}

class _StockNotificationSettingsPageState extends State<StockNotificationSettingsPage> {
  bool _notificationsEnabled = false;
  bool _lowStockAlerts = true;
  bool _criticalStockAlerts = true;
  bool _dailyReminders = false;
  bool _isLoading = true;
  bool _stockMonitoringActive = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      _notificationsEnabled = await NotificationService.areNotificationsEnabled();
      _stockMonitoringActive = StockMonitoringService().isMonitoring;
    } catch (e) {
      print('Error loading notification settings: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission denied. Please enable in settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
    
    setState(() {
      _notificationsEnabled = enabled;
    });
    
    if (enabled) {
      // Start stock monitoring when notifications are enabled
      await StockMonitoringService().startMonitoring();
    } else {
      // Stop monitoring when notifications are disabled
      StockMonitoringService().stopMonitoring();
      await NotificationService().cancelAllNotifications();
    }
    
    setState(() {
      _stockMonitoringActive = StockMonitoringService().isMonitoring;
    });
  }

  Future<void> _testNotification() async {
    if (!_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable notifications first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await NotificationService().showLowStockNotification(
      productName: 'Earl Grey Tea (Test)',
      currentStock: 2,
      minimumStock: 10,
      unit: 'kg',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _forceStockCheck() async {
    if (!_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable notifications first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await StockMonitoringService().forceStockCheck();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock check completed! Check your notifications.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Stock Notifications'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await NotificationService.openNotificationSettings();
            },
            tooltip: 'Open System Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                                color: _notificationsEnabled ? AppTheme.successColor : AppTheme.errorColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Notification Status',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _notificationsEnabled ? 'Notifications are enabled' : 'Notifications are disabled',
                            style: TextStyle(
                              color: _notificationsEnabled ? AppTheme.successColor : AppTheme.errorColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_stockMonitoringActive) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.monitor_heart, color: AppTheme.successColor, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Stock monitoring active',
                                  style: TextStyle(
                                    color: AppTheme.successColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Main Settings
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable Stock Notifications'),
                          subtitle: const Text('Receive alerts for low stock items'),
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          secondary: const Icon(Icons.notifications),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Low Stock Alerts'),
                          subtitle: const Text('Get notified when items are running low'),
                          value: _lowStockAlerts && _notificationsEnabled,
                          onChanged: _notificationsEnabled
                              ? (value) => setState(() => _lowStockAlerts = value)
                              : null,
                          secondary: const Icon(Icons.warning_amber),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Critical Stock Alerts'),
                          subtitle: const Text('Immediate alerts for out-of-stock items'),
                          value: _criticalStockAlerts && _notificationsEnabled,
                          onChanged: _notificationsEnabled
                              ? (value) => setState(() => _criticalStockAlerts = value)
                              : null,
                          secondary: const Icon(Icons.error, color: Colors.red),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Daily Stock Reminders'),
                          subtitle: const Text('Daily reminder to check inventory (9 AM)'),
                          value: _dailyReminders && _notificationsEnabled,
                          onChanged: _notificationsEnabled
                              ? (value) async {
                                  setState(() => _dailyReminders = value);
                                  if (value) {
                                    await NotificationService().schedulePeriodicStockCheck();
                                  } else {
                                    await NotificationService().cancelAllScheduledNotifications();
                                  }
                                }
                              : null,
                          secondary: const Icon(Icons.schedule),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Test & Actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Testing & Actions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _testNotification,
                              icon: const Icon(Icons.send),
                              label: const Text('Send Test Notification'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _forceStockCheck,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Check Stock Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await NotificationService().cancelAllNotifications();
                                StockMonitoringService().clearNotificationHistory();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All notifications cleared'),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear All Notifications'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Information Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'How it works',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Stock levels are checked every 30 minutes\n'
                            '• Low stock alerts when items fall below minimum threshold\n'
                            '• Critical alerts for out-of-stock items\n'
                            '• Summary notifications prevent spam\n'
                            '• Notifications automatically stop after restocking',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
