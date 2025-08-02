import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../services/notification_service.dart';
import '../../domain/entities/product.dart';

class StockMonitoringService {
  static final StockMonitoringService _instance = StockMonitoringService._internal();
  factory StockMonitoringService() => _instance;
  StockMonitoringService._internal();

  Timer? _monitoringTimer;
  final NotificationService _notificationService = NotificationService();
  
  // Track previously notified items to avoid spam
  final Set<String> _notifiedLowStock = {};
  final Set<String> _notifiedOutOfStock = {};
  
  // Last check timestamps to control notification frequency
  DateTime? _lastLowStockCheck;
  DateTime? _lastCriticalStockCheck;
  DateTime? _lastSummaryNotification;

  // Configuration
  static const Duration checkInterval = Duration(minutes: 30); // Check every 30 minutes
  static const Duration lowStockNotificationCooldown = Duration(hours: 2); // Don't spam low stock alerts
  static const Duration criticalStockNotificationCooldown = Duration(hours: 1); // More frequent for critical
  static const Duration summaryNotificationCooldown = Duration(hours: 6); // Summary every 6 hours

  /// Start monitoring stock levels
  Future<void> startMonitoring() async {
    // Stop any existing monitoring
    stopMonitoring();
    
    // Perform initial check
    await checkStockLevels();
    
    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(checkInterval, (timer) {
      checkStockLevels();
    });
    
    print('Stock monitoring started - checking every ${checkInterval.inMinutes} minutes');
  }

  /// Stop monitoring stock levels
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    print('Stock monitoring stopped');
  }

  /// Check stock levels and send notifications if needed
  Future<void> checkStockLevels({bool forceNotification = false}) async {
    try {
      final products = await _fetchProducts();
      if (products.isEmpty) return;

      final lowStockProducts = <Product>[];
      final outOfStockProducts = <Product>[];
      final criticalStockProducts = <Product>[];

      // Categorize products by stock level
      for (final product in products) {
        if (product.isOutOfStock) {
          outOfStockProducts.add(product);
        } else if (product.isCriticalStock) {
          criticalStockProducts.add(product);
        } else if (product.isLowStock) {
          lowStockProducts.add(product);
        }
      }

      // Handle critical/out of stock notifications (highest priority)
      await _handleCriticalStockNotifications(
        outOfStockProducts + criticalStockProducts,
        forceNotification,
      );

      // Handle low stock notifications
      await _handleLowStockNotifications(lowStockProducts, forceNotification);

      // Send summary notification if significant issues
      await _handleSummaryNotifications(
        lowStockProducts.length,
        outOfStockProducts.length + criticalStockProducts.length,
        forceNotification,
      );

    } catch (e) {
      print('Error checking stock levels: $e');
    }
  }

  /// Handle critical stock notifications (out of stock + critical low)
  Future<void> _handleCriticalStockNotifications(
    List<Product> criticalProducts,
    bool forceNotification,
  ) async {
    final now = DateTime.now();
    
    // Check cooldown period
    if (!forceNotification && 
        _lastCriticalStockCheck != null && 
        now.difference(_lastCriticalStockCheck!) < criticalStockNotificationCooldown) {
      return;
    }

    for (final product in criticalProducts) {
      // Skip if already notified recently (unless forced)
      if (!forceNotification && _notifiedOutOfStock.contains(product.id)) {
        continue;
      }

      if (product.isOutOfStock) {
        await _notificationService.showCriticalStockNotification(
          productName: product.name,
          unit: product.unit,
        );
      } else {
        // Critical low stock (different from regular low stock)
        await _notificationService.showLowStockNotification(
          productName: product.name,
          currentStock: product.stockQuantity,
          minimumStock: product.minimumStock,
          unit: product.unit,
        );
      }

      _notifiedOutOfStock.add(product.id);
    }

    if (criticalProducts.isNotEmpty) {
      _lastCriticalStockCheck = now;
    }
  }

  /// Handle low stock notifications
  Future<void> _handleLowStockNotifications(
    List<Product> lowStockProducts,
    bool forceNotification,
  ) async {
    final now = DateTime.now();
    
    // Check cooldown period
    if (!forceNotification && 
        _lastLowStockCheck != null && 
        now.difference(_lastLowStockCheck!) < lowStockNotificationCooldown) {
      return;
    }

    int newLowStockAlerts = 0;

    for (final product in lowStockProducts) {
      // Skip if already notified recently (unless forced)
      if (!forceNotification && _notifiedLowStock.contains(product.id)) {
        continue;
      }

      await _notificationService.showLowStockNotification(
        productName: product.name,
        currentStock: product.stockQuantity,
        minimumStock: product.minimumStock,
        unit: product.unit,
      );

      _notifiedLowStock.add(product.id);
      newLowStockAlerts++;
    }

    if (newLowStockAlerts > 0) {
      _lastLowStockCheck = now;
    }
  }

  /// Handle summary notifications
  Future<void> _handleSummaryNotifications(
    int lowStockCount,
    int criticalStockCount,
    bool forceNotification,
  ) async {
    final now = DateTime.now();
    
    // Only send summary if there are issues and cooldown has passed
    if ((lowStockCount > 0 || criticalStockCount > 0) &&
        (forceNotification || 
         _lastSummaryNotification == null ||
         now.difference(_lastSummaryNotification!) > summaryNotificationCooldown)) {
      
      await _notificationService.showLowStockSummaryNotification(
        lowStockCount: lowStockCount,
        outOfStockCount: criticalStockCount,
      );
      
      _lastSummaryNotification = now;
    }
  }

  /// Fetch products from database
  Future<List<Product>> _fetchProducts() async {
    try {
      if (AppConstants.enableSupabase) {
        final response = await Supabase.instance.client
            .from(AppConstants.productsTable)
            .select()
            .eq('is_active', true);

        return (response as List)
            .map((json) => Product.fromJson(json))
            .toList();
      } else {
        // Return mock data for offline mode
        return _getMockProducts();
      }
    } catch (e) {
      print('Error fetching products for stock monitoring: $e');
      return [];
    }
  }

  /// Mock products for testing/offline mode
  List<Product> _getMockProducts() {
    return [
      Product(
        id: '1',
        name: 'Earl Grey Tea',
        description: 'Premium Earl Grey black tea',
        category: 'Black Tea',
        price: 250.00,
        costPrice: 180.00,
        stockQuantity: 2, // Low stock
        minimumStock: 10,
        unit: 'kg',
        supplier: 'Premium Tea Suppliers',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: '2',
        name: 'Green Tea',
        description: 'Organic green tea leaves',
        category: 'Green Tea',
        price: 300.00,
        costPrice: 220.00,
        stockQuantity: 0, // Out of stock
        minimumStock: 10,
        unit: 'kg',
        supplier: 'Organic Tea Co',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  /// Clear notification history (useful after restocking)
  void clearNotificationHistory() {
    _notifiedLowStock.clear();
    _notifiedOutOfStock.clear();
    print('Notification history cleared');
  }

  /// Force a stock check (ignoring cooldowns)
  Future<void> forceStockCheck() async {
    await checkStockLevels(forceNotification: true);
  }

  /// Get monitoring status
  bool get isMonitoring => _monitoringTimer?.isActive ?? false;

  /// Schedule restock reminders for specific products
  Future<void> scheduleRestockReminders(List<String> productNames) async {
    if (productNames.isNotEmpty) {
      await _notificationService.showRestockReminderNotification(
        productNames: productNames,
      );
    }
  }

  /// Handle product stock update (call this when stock changes)
  Future<void> onStockUpdated(String productId, int newStock, int minimumStock) async {
    // Remove from notification history if stock is now adequate
    if (newStock > minimumStock) {
      _notifiedLowStock.remove(productId);
      _notifiedOutOfStock.remove(productId);
    }
    
    // Check if immediate notification is needed for this product
    if (newStock <= 0) {
      // Still out of stock - might need immediate notification
      if (!_notifiedOutOfStock.contains(productId)) {
        final products = await _fetchProducts();
        final product = products.where((p) => p.id == productId).firstOrNull;
        if (product != null) {
          await _notificationService.showCriticalStockNotification(
            productName: product.name,
            unit: product.unit,
          );
          _notifiedOutOfStock.add(productId);
        }
      }
    } else if (newStock <= minimumStock) {
      // Still low stock - might need notification
      if (!_notifiedLowStock.contains(productId)) {
        final products = await _fetchProducts();
        final product = products.where((p) => p.id == productId).firstOrNull;
        if (product != null) {
          await _notificationService.showLowStockNotification(
            productName: product.name,
            currentStock: newStock,
            minimumStock: minimumStock,
            unit: product.unit,
          );
          _notifiedLowStock.add(productId);
        }
      }
    }
  }
}
