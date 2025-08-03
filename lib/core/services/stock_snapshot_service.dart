import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_snapshot.dart';

class StockSnapshotService {
  static const String _snapshotsTable = 'stock_snapshots';
  static const String _snapshotItemsTable = 'stock_snapshot_items';

  /// Creates a stock snapshot at session start
  static Future<StockSnapshot> createSessionStartSnapshot({
    required String sessionId,
    required String userId,
  }) async {
    return await _createSnapshot(
      sessionId: sessionId,
      userId: userId,
      snapshotType: 'session_start',
    );
  }

  /// Creates a stock snapshot at session end
  static Future<StockSnapshot> createSessionEndSnapshot({
    required String sessionId,
    required String userId,
  }) async {
    return await _createSnapshot(
      sessionId: sessionId,
      userId: userId,
      snapshotType: 'session_end',
    );
  }

  /// Creates a stock snapshot
  static Future<StockSnapshot> _createSnapshot({
    required String sessionId,
    required String userId,
    required String snapshotType,
  }) async {
    if (!AppConstants.enableSupabase) {
      throw Exception('Supabase is disabled');
    }

    const uuid = Uuid();
    final snapshotId = uuid.v4();
    final now = DateTime.now();

    try {
      // Get all active products
      final productsResponse = await Supabase.instance.client
          .from(AppConstants.productsTable)
          .select()
          .eq('is_active', true)
          .order('name');

      final products = (productsResponse as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Calculate totals
      int totalProductsCount = products.length;
      double totalStockValue = 0.0;
      final snapshotItems = <StockSnapshotItem>[];

      for (final product in products) {
        final itemValue = product.stockQuantity * product.price;
        totalStockValue += itemValue;

        final snapshotItem = StockSnapshotItem(
          id: uuid.v4(),
          snapshotId: snapshotId,
          productId: product.id,
          productName: product.name,
          category: product.category,
          unit: product.unit,
          quantityRecorded: product.stockQuantity.toDouble(),
          unitPrice: product.price,
          totalValue: itemValue,
          createdAt: now,
        );

        snapshotItems.add(snapshotItem);
      }

      // Create the main snapshot record
      final snapshot = StockSnapshot(
        id: snapshotId,
        sessionId: sessionId,
        userId: userId,
        snapshotType: snapshotType,
        snapshotDate: now,
        totalProductsCount: totalProductsCount,
        totalStockValue: totalStockValue,
        createdAt: now,
      );

      // Insert snapshot into database
      await Supabase.instance.client
          .from(_snapshotsTable)
          .insert(snapshot.toJson());

      // Insert all snapshot items in batch
      final itemsJson = snapshotItems.map((item) => item.toJson()).toList();
      await Supabase.instance.client
          .from(_snapshotItemsTable)
          .insert(itemsJson);

      print('Stock snapshot created: $snapshotType with ${snapshotItems.length} products, total value: ₹${totalStockValue.toStringAsFixed(2)}');

      return snapshot;
    } catch (e) {
      print('Error creating stock snapshot: $e');
      throw Exception('Failed to create stock snapshot: $e');
    }
  }

  /// Gets stock snapshot by ID
  static Future<StockSnapshot?> getSnapshot(String snapshotId) async {
    if (!AppConstants.enableSupabase) return null;

    try {
      final response = await Supabase.instance.client
          .from(_snapshotsTable)
          .select()
          .eq('id', snapshotId)
          .maybeSingle();

      if (response != null) {
        return StockSnapshot.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error getting stock snapshot: $e');
      return null;
    }
  }

  /// Gets stock snapshot items for a snapshot
  static Future<List<StockSnapshotItem>> getSnapshotItems(String snapshotId) async {
    if (!AppConstants.enableSupabase) return [];

    try {
      final response = await Supabase.instance.client
          .from(_snapshotItemsTable)
          .select()
          .eq('snapshot_id', snapshotId)
          .order('product_name');

      return (response as List)
          .map((json) => StockSnapshotItem.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting snapshot items: $e');
      return [];
    }
  }

  /// Gets all snapshots for a session
  static Future<List<StockSnapshot>> getSessionSnapshots(String sessionId) async {
    if (!AppConstants.enableSupabase) return [];

    try {
      final response = await Supabase.instance.client
          .from(_snapshotsTable)
          .select()
          .eq('session_id', sessionId)
          .order('snapshot_date');

      return (response as List)
          .map((json) => StockSnapshot.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting session snapshots: $e');
      return [];
    }
  }

  /// Verifies stock accuracy by comparing start and end snapshots
  static Future<List<StockVerificationResult>> verifySessionStock({
    required String sessionId,
    required String userId,
  }) async {
    if (!AppConstants.enableSupabase) return [];

    try {
      // Get session snapshots
      final snapshots = await getSessionSnapshots(sessionId);
      
      StockSnapshot? startSnapshot;
      StockSnapshot? endSnapshot;
      
      for (final snapshot in snapshots) {
        if (snapshot.snapshotType == 'session_start') {
          startSnapshot = snapshot;
        } else if (snapshot.snapshotType == 'session_end') {
          endSnapshot = snapshot;
        }
      }

      if (startSnapshot == null || endSnapshot == null) {
        throw Exception('Missing session snapshots for verification');
      }

      // Get snapshot items
      final startItems = await getSnapshotItems(startSnapshot.id);
      final endItems = await getSnapshotItems(endSnapshot.id);

      // Calculate sales during session
      final sessionSales = await _getSessionSales(sessionId, userId, startSnapshot.snapshotDate, endSnapshot.snapshotDate);

      // Compare and generate verification results
      final results = <StockVerificationResult>[];
      
      for (final startItem in startItems) {
        StockSnapshotItem? endItem;
        for (final item in endItems) {
          if (item.productId == startItem.productId) {
            endItem = item;
            break;
          }
        }
        
        final soldQuantity = sessionSales[startItem.productId] ?? 0.0;
        
        final expectedQuantity = startItem.quantityRecorded - soldQuantity;
        final actualQuantity = endItem?.quantityRecorded ?? 0.0;
        final variance = actualQuantity - expectedQuantity;
        final isAccurate = variance.abs() <= 0.01; // Allow small rounding differences

        final result = StockVerificationResult(
          productId: startItem.productId,
          productName: startItem.productName,
          startingQuantity: startItem.quantityRecorded,
          currentQuantity: actualQuantity,
          soldQuantity: soldQuantity,
          expectedQuantity: expectedQuantity,
          variance: variance,
          isAccurate: isAccurate,
          discrepancyReason: !isAccurate ? _getDiscrepancyReason(variance) : null,
        );

        results.add(result);
      }

      return results..sort((a, b) => a.productName.compareTo(b.productName));
    } catch (e) {
      print('Error verifying session stock: $e');
      throw Exception('Failed to verify stock: $e');
    }
  }

  /// Gets sales quantities for products during a session
  static Future<Map<String, double>> _getSessionSales(
    String sessionId,
    String userId,
    DateTime sessionStart,
    DateTime sessionEnd,
  ) async {
    try {
      // Get all sales during the session period
      final salesResponse = await Supabase.instance.client
          .from(AppConstants.salesTable)
          .select('id')
          .eq('created_by', userId)
          .gte('sale_date', sessionStart.toIso8601String())
          .lte('sale_date', sessionEnd.toIso8601String());

      if (salesResponse.isEmpty) return {};

      final saleIds = (salesResponse as List).map((s) => s['id'] as String).toList();

      // Get sale items for these sales
      final saleItemsResponse = await Supabase.instance.client
          .from('sale_items')
          .select('product_id, quantity')
          .inFilter('sale_id', saleIds);

      // Aggregate quantities by product
      final productSales = <String, double>{};
      for (final item in saleItemsResponse as List) {
        final productId = item['product_id'] as String;
        final quantity = (item['quantity'] as num).toDouble();
        productSales[productId] = (productSales[productId] ?? 0.0) + quantity;
      }

      return productSales;
    } catch (e) {
      print('Error getting session sales: $e');
      return {};
    }
  }

  /// Determines discrepancy reason based on variance
  static String _getDiscrepancyReason(double variance) {
    if (variance > 0) {
      return 'More stock than expected (possible restock or counting error)';
    } else {
      return 'Less stock than expected (possible theft, damage, or counting error)';
    }
  }

  /// Gets stock verification summary for a session
  static Future<Map<String, dynamic>> getVerificationSummary(String sessionId) async {
    try {
      final snapshots = await getSessionSnapshots(sessionId);
      
      StockSnapshot? startSnapshot;
      StockSnapshot? endSnapshot;
      
      for (final snapshot in snapshots) {
        if (snapshot.snapshotType == 'session_start') {
          startSnapshot = snapshot;
        } else if (snapshot.snapshotType == 'session_end') {
          endSnapshot = snapshot;
        }
      }

      if (startSnapshot == null || endSnapshot == null) {
        return {
          'has_snapshots': false,
          'message': 'Session snapshots not found',
        };
      }

      final verificationResults = await verifySessionStock(
        sessionId: sessionId,
        userId: startSnapshot.userId,
      );

      final accurateCount = verificationResults.where((r) => r.isAccurate).length;
      final discrepancyCount = verificationResults.length - accurateCount;
      final totalVarianceValue = verificationResults.fold<double>(
        0.0, 
        (sum, r) => sum + (r.variance * (r.variance > 0 ? 1 : -1)),
      );

      return {
        'has_snapshots': true,
        'total_products': verificationResults.length,
        'accurate_count': accurateCount,
        'discrepancy_count': discrepancyCount,
        'accuracy_percentage': verificationResults.isNotEmpty 
            ? (accurateCount / verificationResults.length * 100) 
            : 0.0,
        'total_variance_value': totalVarianceValue,
        'start_total_value': startSnapshot.totalStockValue,
        'end_total_value': endSnapshot.totalStockValue,
        'value_difference': endSnapshot.totalStockValue - startSnapshot.totalStockValue,
      };
    } catch (e) {
      print('Error getting verification summary: $e');
      return {
        'has_snapshots': false,
        'message': 'Error calculating verification summary: $e',
      };
    }
  }
}
