import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/stock_snapshot_service.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sales_history.dart';
import '../../widgets/loading_widget.dart';
import 'add_sale_page.dart';
import 'edit_sale_page.dart';
import 'sales_history_page.dart';
import 'stock_verification_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Sale> _sales = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime? _selectedDate;
  bool _hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
    _checkActiveSession();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    
    try {
      if (AppConstants.enableSupabase) {
        final response = await Supabase.instance.client
            .from('sales')
            .select()
            .order('sale_date', ascending: false);

        _sales = (response as List)
            .map((json) => Sale.fromJson(json))
            .toList();
      } else {
        // Mock data for offline mode
        await Future.delayed(const Duration(seconds: 1));
        _sales = _getMockSales();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sales: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  List<Sale> _getMockSales() {
    return [
      Sale(
        id: '1',
        saleNumber: 'SALE-001',
        customerName: 'John Doe',
        customerPhone: '+91 9876543210',
        totalAmount: 750.00,
        discountAmount: 50.00,
        taxAmount: 0.00,
        paymentMethod: 'cash',
        saleDate: DateTime.now().subtract(const Duration(hours: 2)),
        createdBy: 'user-1',
        status: 'completed',
      ),
      Sale(
        id: '2',
        saleNumber: 'SALE-002',
        customerName: 'Jane Smith',
        totalAmount: 1200.00,
        discountAmount: 0.00,
        taxAmount: 0.00,
        paymentMethod: 'upi',
        saleDate: DateTime.now().subtract(const Duration(hours: 5)),
        createdBy: 'user-1',
        status: 'completed',
      ),
    ];
  }

  List<Sale> get _filteredSales {
    return _sales.where((sale) {
      final matchesSearch = sale.saleNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (sale.customerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      final matchesDate = _selectedDate == null ||
          (sale.saleDate.year == _selectedDate!.year &&
           sale.saleDate.month == _selectedDate!.month &&
           sale.saleDate.day == _selectedDate!.day);
      
      return matchesSearch && matchesDate;
    }).toList();
  }

  double get _totalSales {
    return _filteredSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _checkActiveSession() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && AppConstants.enableSupabase) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        
        final existingSession = await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .select()
            .eq('user_id', user.id)
            .eq('date', today)
            .eq('status', 'opened');
            
        setState(() {
          _hasActiveSession = existingSession.isNotEmpty;
        });
      } else {
        setState(() {
          _hasActiveSession = false;
        });
      }
    } catch (e) {
      print('Debug: Error checking active session: $e');
      setState(() {
        _hasActiveSession = false;
      });
    }
  }

  Future<void> _showStartSaleDialog() async {
    final TextEditingController balanceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Sale Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your starting wallet balance:'),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Starting Balance (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (balanceController.text.isNotEmpty) {
                final balanceText = balanceController.text.trim();
                final balance = double.tryParse(balanceText);
                if (balance != null) {
                  await _saveStartBalance(balance);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a balance amount')),
                );
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEndSaleDialog() async {
    final TextEditingController balanceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Sale Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your ending wallet balance:'),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Ending Balance (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (balanceController.text.isNotEmpty) {
                final balanceText = balanceController.text.trim();
                final balance = double.tryParse(balanceText);
                if (balance != null) {
                  Navigator.of(context).pop();
                  await _processSessionEnd(balance);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a balance amount')),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Process session end with discrepancy validation
  Future<void> _processSessionEnd(double closingBalance) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || !AppConstants.enableSupabase) {
        await _saveEndBalance(closingBalance);
        return;
      }

      // Get current session info
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from(AppConstants.walletBalanceTable)
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .eq('status', 'opened')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active session found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final record = response.first;
      final openingBalance = record['opening_balance'] as double;
      final sessionId = record['id'];

      // Calculate cash discrepancy
      final salesResponse = await Supabase.instance.client
          .from(AppConstants.salesTable)
          .select('total_amount')
          .eq('created_by', user.id)
          .gte('sale_date', record['created_at'])
          .lte('sale_date', DateTime.now().toIso8601String());

      final totalSales = (salesResponse as List).fold<double>(0.0, (sum, sale) {
        final amount = sale['total_amount'];
        return sum + (amount is num ? amount.toDouble() : 0.0);
      });

      final expectedClosingBalance = openingBalance + totalSales;
      final cashDifference = closingBalance - expectedClosingBalance;
      final hasCashDiscrepancy = cashDifference.abs() >= 0.01;

      // Get actual stock counts from user input
      final actualStockCounts = await _showStockCountingDialog();
      if (actualStockCounts == null) {
        // User cancelled stock counting
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock counting is required to end session'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create end stock snapshot with actual counted stock
      try {
        await _createEndSnapshotWithActualCounts(
          sessionId: sessionId,
          userId: user.id,
          actualCounts: actualStockCounts,
        );
      } catch (e) {
        print('Warning: Could not create end stock snapshot: $e');
      }

      // Get session start time for enhanced verification
      String? sessionStartTime;
      try {
        // Session data is stored in wallet_balances table, not sales_sessions
        sessionStartTime = record['created_at']; // We already have this from the record above
        print('Debug: Session start time from wallet_balances: $sessionStartTime');
      } catch (e) {
        print('Warning: Could not get session start time: $e');
      }

      // Check for stock discrepancies using enhanced movement calculation
      Map<String, dynamic> stockSummary = {};
      bool hasStockDiscrepancy = false;
      
      try {
        // Use our enhanced verification that considers all movements
        if (sessionStartTime != null) {
          print('Debug: Using ENHANCED verification with sessionStartTime: $sessionStartTime');
          stockSummary = await _getEnhancedVerificationSummary(sessionId, sessionStartTime, actualStockCounts);
          print('Debug: Enhanced verification result: $stockSummary');
        } else {
          print('Debug: Using OLD verification (no sessionStartTime)');
          // Fallback to old method if we can't get session start time
          stockSummary = await StockSnapshotService.getVerificationSummary(sessionId);
          print('Debug: Old verification result: $stockSummary');
        }
        hasStockDiscrepancy = stockSummary['has_snapshots'] == true && 
                             stockSummary['discrepancy_count'] > 0;
        print('Debug: hasStockDiscrepancy: $hasStockDiscrepancy, discrepancy_count: ${stockSummary['discrepancy_count']}');
      } catch (e) {
        print('Warning: Could not get enhanced verification summary: $e');
        // Fallback to old method
        try {
          stockSummary = await StockSnapshotService.getVerificationSummary(sessionId);
          hasStockDiscrepancy = stockSummary['has_snapshots'] == true && 
                               stockSummary['discrepancy_count'] > 0;
        } catch (e2) {
          print('Warning: Could not get stock verification summary: $e2');
        }
      }

      // If there are discrepancies, require a reason
      if (hasCashDiscrepancy || hasStockDiscrepancy) {
        final reason = await _showDiscrepancyReasonDialog(
          cashDifference: cashDifference,
          hasCashDiscrepancy: hasCashDiscrepancy,
          hasStockDiscrepancy: hasStockDiscrepancy,
          stockSummary: stockSummary,
          totalSales: totalSales,
        );

        if (reason == null) {
          // User cancelled - don't close session
          return;
        }

        // Save end balance with reason
        await _saveEndBalanceWithReason(closingBalance, reason);
      } else {
        // No discrepancies - proceed normally
        await _saveEndBalance(closingBalance, stockSummary);
      }
    } catch (e) {
      print('Error processing session end: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show stock counting dialog to get actual product counts
  Future<Map<String, double>?> _showStockCountingDialog() async {
    try {
      // Get current session info
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final sessionResponse = await Supabase.instance.client
          .from(AppConstants.walletBalanceTable)
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .eq('status', 'opened')
          .order('created_at', ascending: false)
          .limit(1);

      if (sessionResponse.isEmpty) {
        throw Exception('No active session found');
      }

      final sessionRecord = sessionResponse.first;
      final sessionId = sessionRecord['id'];
      final sessionStartTime = sessionRecord['created_at'];

      // Get all active products with calculated expected quantities
      final productsWithExpected = await _getProductsWithExpectedQuantities(sessionId, sessionStartTime);

      if (productsWithExpected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No products found for stock counting'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return {};
      }

      // Create controllers for each product with expected quantities
      final Map<String, TextEditingController> controllers = {};
      
      for (final productData in productsWithExpected) {
        final product = productData['product'] as Product;
        final expectedQuantity = productData['expected_quantity'] as double;
        
        controllers[product.id] = TextEditingController(
          text: expectedQuantity.toString(),
        );
      }

      return await showDialog<Map<String, double>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _StockCountingDialog(
          productsWithExpected: productsWithExpected,
          controllers: controllers,
        ),
      ).then((result) {
        // Dispose controllers
        for (final controller in controllers.values) {
          controller.dispose();
        }
        return result;
      });

    } catch (e) {
      print('Error showing stock counting dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products for counting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Get products with expected quantities after considering all movements since session start
  Future<List<Map<String, dynamic>>> _getProductsWithExpectedQuantities(String sessionId, String sessionStartTime) async {
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

      // Get session start snapshot to know the starting quantities
      final startSnapshotResponse = await Supabase.instance.client
          .from(AppConstants.stockSnapshotsTable)
          .select('id')
          .eq('session_id', sessionId)
          .eq('snapshot_type', 'session_start')
          .limit(1);

      Map<String, double> startingQuantities = {};
      
      if (startSnapshotResponse.isNotEmpty) {
        final startSnapshotId = startSnapshotResponse.first['id'];
        
        // Get starting quantities from snapshot
        final snapshotItemsResponse = await Supabase.instance.client
            .from(AppConstants.stockSnapshotItemsTable)
            .select('product_id, quantity_recorded')
            .eq('snapshot_id', startSnapshotId);
            
        for (final item in snapshotItemsResponse) {
          startingQuantities[item['product_id']] = (item['quantity_recorded'] as num).toDouble();
        }
      } else {
        // Fallback to current product stock quantities if no start snapshot
        for (final product in products) {
          startingQuantities[product.id] = product.stockQuantity.toDouble();
        }
      }

      // Calculate movements since session start for each product
      final List<Map<String, dynamic>> productsWithExpected = [];
      
      for (final product in products) {
        final startingQuantity = startingQuantities[product.id] ?? product.stockQuantity.toDouble();
        final movements = await _calculateProductMovementsSinceSession(product.id, sessionStartTime);
        final expectedQuantity = startingQuantity + movements;
        
        print('Debug: Product ${product.name} - Starting: $startingQuantity, Movements: $movements, Expected: $expectedQuantity');
        
        productsWithExpected.add({
          'product': product,
          'starting_quantity': startingQuantity,
          'movements': movements,
          'expected_quantity': expectedQuantity,
        });
      }

      return productsWithExpected;
      
    } catch (e) {
      print('Error getting products with expected quantities: $e');
      throw Exception('Failed to calculate expected quantities: $e');
    }
  }

  /// Calculate net inventory movements for a product since session start
  Future<double> _calculateProductMovementsSinceSession(String productId, String sessionStartTime) async {
    try {
      double netMovement = 0.0;
      print('Debug: Calculating movements for product $productId since $sessionStartTime');

      // 1. Sales (negative movement - items sold) - only completed and pending sales
      final salesResponse = await Supabase.instance.client
          .from(AppConstants.saleItemsTable)
          .select('quantity, sales!inner(sale_date, status)')
          .eq('product_id', productId)
          .gte('sales.sale_date', sessionStartTime);

      print('Debug: Sales response: $salesResponse');
      for (final saleItem in salesResponse) {
        final sales = saleItem['sales'];
        final status = sales['status'] as String;
        if (status == 'completed' || status == 'pending') {
          final quantity = (saleItem['quantity'] as num).toDouble();
          netMovement -= quantity; // Subtract sold items
          print('Debug: Sale - Product $productId, quantity: $quantity, status: $status, netMovement now: $netMovement');
        }
      }

      // 2. Refunds (positive movement - items returned to inventory)
      final refundsResponse = await Supabase.instance.client
          .from(AppConstants.saleItemsTable)
          .select('quantity, sales!inner(sale_date, status)')
          .eq('product_id', productId)
          .gte('sales.sale_date', sessionStartTime)
          .eq('sales.status', 'refunded');

      print('Debug: Refunds response: $refundsResponse');
      for (final refundItem in refundsResponse) {
        final quantity = (refundItem['quantity'] as num).toDouble();
        netMovement += quantity; // Add refunded items back
        print('Debug: Refund - Product $productId, quantity: $quantity, netMovement now: $netMovement');
      }

      // 3. Inventory movements (restocks, adjustments)
      if (await _tableExists(AppConstants.inventoryMovementsTable)) {
        final movementsResponse = await Supabase.instance.client
            .from(AppConstants.inventoryMovementsTable)
            .select('movement_type, quantity')
            .eq('product_id', productId)
            .gte('created_at', sessionStartTime);

        print('Debug: Inventory movements response: $movementsResponse');
        for (final movement in movementsResponse) {
          final movementType = movement['movement_type'] as String;
          final quantity = (movement['quantity'] as num).toDouble();
          
          print('Debug: Inventory movement - Product $productId, type: $movementType, quantity: $quantity');
          
          // Add positive movements (restocks, adjustments up)
          // Subtract negative movements (waste, damage, adjustments down)
          if (['in', 'refill', 'return'].contains(movementType)) {
            netMovement += quantity.abs();
            print('Debug: Added positive movement: +$quantity, netMovement now: $netMovement');
          } else if (['out', 'sale', 'adjustment'].contains(movementType)) {
            // For adjustments, we need to check if it's positive or negative
            if (movementType == 'adjustment') {
              // Assume adjustment can be positive or negative based on quantity sign
              netMovement += quantity; // Keep the sign as is for adjustments
              print('Debug: Added adjustment: ${quantity >= 0 ? '+' : ''}$quantity, netMovement now: $netMovement');
            } else {
              netMovement -= quantity.abs();
              print('Debug: Subtracted negative movement: -$quantity, netMovement now: $netMovement');
            }
          }
        }
      }

      print('Debug: Final netMovement for product $productId: $netMovement');
      return netMovement;
      
    } catch (e) {
      print('Error calculating product movements for $productId: $e');
      return 0.0; // Return 0 if calculation fails
    }
  }

  /// Helper method to check if a table exists
  Future<bool> _tableExists(String tableName) async {
    try {
      await Supabase.instance.client
          .from(tableName)
          .select('*')
          .limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enhanced verification summary that considers all inventory movements
  Future<Map<String, dynamic>> _getEnhancedVerificationSummary(
    String sessionId, 
    String sessionStartTime, 
    Map<String, double> actualCounts
  ) async {
    try {
      // Get all active products with expected quantities
      final productsWithExpected = await _getProductsWithExpectedQuantities(sessionId, sessionStartTime);
      
      if (productsWithExpected.isEmpty) {
        return {
          'has_snapshots': false,
          'message': 'No products found for verification',
        };
      }

      int accurateCount = 0;
      int discrepancyCount = 0;
      double totalVarianceValue = 0.0;
      double startTotalValue = 0.0;
      double endTotalValue = 0.0;
      List<Map<String, dynamic>> discrepancyDetails = [];

      // Compare expected vs actual for each product
      for (final productData in productsWithExpected) {
        final product = productData['product'] as Product;
        final expectedQuantity = productData['expected_quantity'] as double;
        final startingQuantity = productData['starting_quantity'] as double;
        final actualQuantity = actualCounts[product.id] ?? expectedQuantity;
        final movements = productData['movements'] as double;
        
        final variance = actualQuantity - expectedQuantity;
        final isAccurate = variance.abs() <= 0.01; // Allow small rounding differences
        
        print('Debug: ${product.name} verification - Expected: $expectedQuantity, Actual: $actualQuantity, Variance: $variance, IsAccurate: $isAccurate');
        print('Debug: ActualCounts for ${product.name} (${product.id}): ${actualCounts[product.id]}');
        print('Debug: Detailed breakdown - Starting: $startingQuantity, Movements: $movements, Expected: $expectedQuantity, User Input: $actualQuantity');
        
        if (isAccurate) {
          accurateCount++;
          print('Debug: ${product.name} marked as ACCURATE');
        } else {
          discrepancyCount++;
          print('Debug: DISCREPANCY FOUND for ${product.name} - Starting: $startingQuantity, Movements: $movements, Expected: $expectedQuantity, Actual: $actualQuantity, Variance: $variance');
          // Add detailed discrepancy information
          discrepancyDetails.add({
            'product_id': product.id,
            'product_name': product.name,
            'starting_quantity': startingQuantity,
            'expected_quantity': expectedQuantity,
            'actual_quantity': actualQuantity,
            'variance': variance,
            'movements_since_session': movements,
            'variance_value': variance.abs() * product.price,
            'unit_price': product.price,
          });
        }
        
        totalVarianceValue += variance.abs() * product.price;
        startTotalValue += startingQuantity * product.price;
        endTotalValue += actualQuantity * product.price;
      }

      final totalProducts = productsWithExpected.length;
      final accuracyPercentage = totalProducts > 0 ? (accurateCount / totalProducts * 100) : 0.0;

      final result = {
        'has_snapshots': true,
        'total_products': totalProducts,
        'accurate_count': accurateCount,
        'discrepancy_count': discrepancyCount,
        'accuracy_percentage': accuracyPercentage,
        'total_variance_value': totalVarianceValue,
        'start_total_value': startTotalValue,
        'end_total_value': endTotalValue,
        'value_difference': endTotalValue - startTotalValue,
        'discrepancy_details': discrepancyDetails, // Include detailed discrepancy information
      };

      print('Debug: ENHANCED VERIFICATION RESULT: $result');
      print('Debug: Enhanced verification found $discrepancyCount discrepancies out of $totalProducts products');
      
      return result;
      
    } catch (e) {
      print('Error getting enhanced verification summary: $e');
      throw Exception('Failed to calculate enhanced verification summary: $e');
    }
  }

  /// Create end snapshot with actual counted stock
  Future<void> _createEndSnapshotWithActualCounts({
    required String sessionId,
    required String userId,
    required Map<String, double> actualCounts,
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

      // Calculate totals using actual counts
      int totalProductsCount = products.length;
      double totalStockValue = 0.0;
      final snapshotItems = <Map<String, dynamic>>[];

      for (final product in products) {
        final actualQuantity = actualCounts[product.id] ?? product.stockQuantity.toDouble();
        final itemValue = actualQuantity * product.price;
        totalStockValue += itemValue;

        final snapshotItem = {
          'id': uuid.v4(),
          'snapshot_id': snapshotId,
          'product_id': product.id,
          'product_name': product.name,
          'category': product.category,
          'unit': product.unit,
          'quantity_recorded': actualQuantity,
          'unit_price': product.price,
          'total_value': itemValue,
          'created_at': now.toIso8601String(),
        };

        snapshotItems.add(snapshotItem);
      }

      // Create the main snapshot record
      final snapshot = {
        'id': snapshotId,
        'session_id': sessionId,
        'user_id': userId,
        'snapshot_type': 'session_end',
        'snapshot_date': now.toIso8601String(),
        'total_products_count': totalProductsCount,
        'total_stock_value': totalStockValue,
        'created_at': now.toIso8601String(),
      };

      // Insert snapshot into database
      await Supabase.instance.client
          .from(AppConstants.stockSnapshotsTable)
          .insert(snapshot);

      // Insert all snapshot items in batch
      await Supabase.instance.client
          .from(AppConstants.stockSnapshotItemsTable)
          .insert(snapshotItems);

      print('End stock snapshot created with actual counts: ${snapshotItems.length} products, total value: ₹${totalStockValue.toStringAsFixed(2)}');

    } catch (e) {
      print('Error creating end stock snapshot with actual counts: $e');
      throw Exception('Failed to create end stock snapshot: $e');
    }
  }

  /// Show dialog to collect reason for discrepancies
  Future<String?> _showDiscrepancyReasonDialog({
    required double cashDifference,
    required bool hasCashDiscrepancy,
    required bool hasStockDiscrepancy,
    required Map<String, dynamic> stockSummary,
    required double totalSales,
  }) async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Discrepancies Found'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The following discrepancies were detected:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Cash discrepancy
              if (hasCashDiscrepancy) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'Cash Discrepancy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Sales: ₹${totalSales.toStringAsFixed(2)}'),
                      Text(
                        cashDifference > 0 
                            ? 'Extra: ₹${cashDifference.toStringAsFixed(2)}'
                            : 'Short: ₹${cashDifference.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cashDifference > 0 ? Colors.blue : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Stock discrepancy
              if (hasStockDiscrepancy) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Stock Discrepancy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Products: ${stockSummary['total_products'] ?? 0}'),
                      Text(
                        'Discrepancies: ${stockSummary['discrepancy_count'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Accuracy: ${(stockSummary['accuracy_percentage'] ?? 0.0).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.red.shade700,
                        ),
                      ),
                      // Show detailed discrepancy information
                      if (stockSummary['discrepancy_details'] != null && 
                          (stockSummary['discrepancy_details'] as List).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Products with discrepancies:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                            child: Column(
                              children: (stockSummary['discrepancy_details'] as List)
                                  .map<Widget>((detail) => Container(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.2),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              detail['product_name'] ?? 'Unknown Product',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red.shade800,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Expected: ${(detail['expected_quantity'] ?? 0.0).toStringAsFixed(1)}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                                Text(
                                                  'Actual: ${(detail['actual_quantity'] ?? 0.0).toStringAsFixed(1)}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                                Text(
                                                  'Diff: ${(detail['variance'] ?? 0.0) >= 0 ? '+' : ''}${(detail['variance'] ?? 0.0).toStringAsFixed(1)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if ((detail['movements_since_session'] ?? 0.0).abs() > 0.01) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Movements: ${(detail['movements_since_session'] ?? 0.0) >= 0 ? '+' : ''}${(detail['movements_since_session'] ?? 0.0).toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              Text(
                'Please provide a reason for these discrepancies:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for discrepancies',
                  hintText: 'e.g., Counting error, damaged products, customer refund, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for the discrepancies'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  /// Save end balance with discrepancy reason
  Future<void> _saveEndBalanceWithReason(double balance, String reason) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || !AppConstants.enableSupabase) return;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from(AppConstants.walletBalanceTable)
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .eq('status', 'opened')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final record = response.first;
        final sessionId = record['id'];
        
        // Update session with reason
        await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .update({
              'closing_balance': balance,
              'status': 'closed',
              'notes': reason,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', sessionId);

        if (mounted) {
          setState(() {
            _hasActiveSession = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Session ended with noted discrepancies'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'View Details',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StockVerificationPage(sessionId: sessionId),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving end balance with reason: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testWalletBalanceTable() async {
    try {
      print('Debug: Testing wallet_balances table accessibility...');
      
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('Debug: No authenticated user');
        return;
      }
      
      // Test if we can read from the table
      final readTest = await Supabase.instance.client
          .from(AppConstants.walletBalanceTable)
          .select('*')
          .limit(1);
      print('Debug: Read test successful: $readTest');
      
      // Test if user exists in users table
      final userTest = await Supabase.instance.client
          .from(AppConstants.usersTable)
          .select('id, email, name, role')
          .eq('id', user.id);
      print('Debug: User in users table: $userTest');
      
    } catch (e) {
      print('Debug: Wallet balance table test failed: $e');
    }
  }

  Future<void> _saveStartBalance(double balance) async {
    // Run test first
    await _testWalletBalanceTable();
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      print('Debug: Current user: ${user?.id}');
      print('Debug: User email: ${user?.email}');
      print('Debug: Supabase enabled: ${AppConstants.enableSupabase}');
      print('Debug: Wallet table name: ${AppConstants.walletBalanceTable}');
      
      if (user != null && AppConstants.enableSupabase) {
        // First, verify the user exists in the users table
        try {
          final userRecord = await Supabase.instance.client
              .from(AppConstants.usersTable)
              .select('id, name, role')
              .eq('id', user.id)
              .single();
          print('Debug: User record found: $userRecord');
        } catch (userError) {
          print('Debug: User not found in users table: $userError');
          // Try to create the user record manually
          try {
            await Supabase.instance.client
                .from(AppConstants.usersTable)
                .insert({
                  'id': user.id,
                  'email': user.email ?? '',
                  'name': user.email?.split('@').first ?? 'User',
                  'role': 'staff',
                });
            print('Debug: User record created manually');
          } catch (createError) {
            print('Debug: Failed to create user record: $createError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User setup error: $createError'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
        
        final today = DateTime.now().toIso8601String().substring(0, 10);
        print('Debug: Today date: $today');
        
        // Check if there's already ANY session for today (opened or closed)
        final existingSession = await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .select()
            .eq('user_id', user.id)
            .eq('date', today)
            .order('created_at', ascending: false)
            .limit(1);
            
        print('Debug: Existing sessions: $existingSession');
        
        if (existingSession.isNotEmpty) {
          final session = existingSession.first;
          final status = session['status'];
          
          if (status == 'opened') {
            if (mounted) {
              setState(() {
                _hasActiveSession = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You already have an active session for today')),
              );
            }
            return;
          } else if (status == 'closed') {
            // Previous session is closed, but we can't create a new record for the same day
            // Instead, reopen the existing session with new opening balance
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reopening session for today. Previous session: Opening ₹${session['opening_balance']}, Closing ₹${session['closing_balance']}'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            
            // Update the existing record to reopen it
            final updateResponse = await Supabase.instance.client
                .from(AppConstants.walletBalanceTable)
                .update({
                  'opening_balance': balance,
                  'closing_balance': null,
                  'status': 'opened',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', session['id'])
                .select();
                
            print('Debug: Reopened session: $updateResponse');
            
            if (mounted) {
              setState(() {
                _hasActiveSession = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sale session reopened successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return; // Don't create a new record, we've updated the existing one
          }
        }
        
        final data = {
          'user_id': user.id,
          'opening_balance': balance,
          'closing_balance': null,
          'date': today,
          'status': 'opened',
        };
        print('Debug: Inserting data: $data');
        
        final response = await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .insert(data)
            .select();
            
        print('Debug: Insert response: $response');
        
        // Create stock snapshot at session start
        if (response.isNotEmpty) {
          final sessionId = response.first['id'];
          try {
            await StockSnapshotService.createSessionStartSnapshot(
              sessionId: sessionId,
              userId: user.id,
            );
            print('Debug: Stock snapshot created for session start');
          } catch (snapshotError) {
            print('Warning: Could not create stock snapshot: $snapshotError');
            // Continue even if snapshot fails - don't block session start
          }
        }
        
        if (mounted) {
          setState(() {
            _hasActiveSession = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale session started with stock verification'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('Debug: User is null or Supabase disabled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication required to start session')),
          );
        }
      }
    } catch (e) {
      print('Debug: Error starting sale session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting sale session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveEndBalance(double balance, [Map<String, dynamic>? stockSummary]) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      print('Debug: Ending session for user: ${user?.id}');
      
      if (user != null && AppConstants.enableSupabase) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        print('Debug: Looking for open session on date: $today');
        
        // Get today's wallet balance record
        final response = await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .select()
            .eq('user_id', user.id)
            .eq('date', today)
            .eq('status', 'opened')
            .order('created_at', ascending: false)
            .limit(1);

        print('Debug: Found open sessions: $response');

        if (response.isNotEmpty) {
          final record = response.first;
          final sessionId = record['id'];
          
          // Update the record with closing balance and status
          await Supabase.instance.client
              .from(AppConstants.walletBalanceTable)
              .update({
                'closing_balance': balance,
                'status': 'closed',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', sessionId);

          print('Debug: Session closed successfully');
          
          if (mounted) {
            setState(() {
              _hasActiveSession = false;
            });
            
            _showStockVerificationDialog(sessionId, 'Session ended successfully!', Colors.green, stockSummary);
          }
        } else {
          print('Debug: No active session found');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active sale session found for today'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        print('Debug: User is null or Supabase disabled');
      }
    } catch (e) {
      print('Debug: Error ending sale session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending sale session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'refunded':
        return Colors.orange;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'upi':
        return Icons.payment;
      default:
        return Icons.payments;
    }
  }

  void _showSaleActionsDialog(Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale ${sale.saleNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${sale.customerName ?? 'Walk-in'}'),
            Text('Amount: ₹${sale.totalAmount.toStringAsFixed(2)}'),
            Text('Status: ${sale.status.toUpperCase()}'),
            Text('Date: ${_formatDate(sale.saleDate)} at ${_formatTime(sale.saleDate)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SalesHistoryPage(saleId: sale.id),
                ),
              );
            },
            child: const Text('View History'),
          ),
          if (sale.status == 'completed') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditSalePage(sale: sale),
                  ),
                ).then((_) => _loadSales());
              },
              child: const Text('Edit Sale'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCancelSaleDialog(sale);
              },
              child: const Text('Cancel Sale'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showRefundSaleDialog(sale);
              },
              child: const Text('Refund Sale'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCancelSaleDialog(Sale sale) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Sale ${sale.saleNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to cancel this sale?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              reasonController.dispose();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for cancellation'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _cancelSale(sale, reasonController.text.trim());
              reasonController.dispose();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Cancel Sale'),
          ),
        ],
      ),
    );
  }

  void _showRefundSaleDialog(Sale sale) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Refund Sale ${sale.saleNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to refund this sale?'),
            const SizedBox(height: 8),
            Text('Amount: ₹${sale.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for refund',
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              reasonController.dispose();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for refund'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _refundSale(sale, reasonController.text.trim());
              reasonController.dispose();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Refund Sale'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSale(Sale sale, String reason) async {
    try {
      final uuid = const Uuid();
      final now = DateTime.now();
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (AppConstants.enableSupabase && currentUser != null) {
        // Update sale status
        await Supabase.instance.client
            .from(AppConstants.salesTable)
            .update({
              'status': 'cancelled',
            })
            .eq('id', sale.id);

        // Create sales history record
        final historyRecord = SalesHistory(
          id: uuid.v4(),
          saleId: sale.id,
          changeType: SalesChangeType.cancelled,
          fieldChanged: 'status',
          oldValue: {'status': sale.status},
          newValue: {'status': 'cancelled'},
          reason: reason,
          changedBy: currentUser.id,
          changedAt: now,
          metadata: {
            'original_amount': sale.totalAmount,
            'payment_method': sale.paymentMethod,
          },
        );

        await Supabase.instance.client
            .from(AppConstants.salesHistoryTable)
            .insert(historyRecord.toJson());

        // Restore inventory (add back the sold items)
        // Note: This would require getting sale items and updating product stock
        // For now, we'll just update the sale status
        
        _loadSales(); // Refresh the sales list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sale ${sale.saleNumber} cancelled successfully'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling sale: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _refundSale(Sale sale, String reason) async {
    try {
      final uuid = const Uuid();
      final now = DateTime.now();
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (AppConstants.enableSupabase && currentUser != null) {
        // Update sale status
        await Supabase.instance.client
            .from(AppConstants.salesTable)
            .update({
              'status': 'refunded',
            })
            .eq('id', sale.id);

        // Create sales history record
        final historyRecord = SalesHistory(
          id: uuid.v4(),
          saleId: sale.id,
          changeType: SalesChangeType.refunded,
          fieldChanged: 'status',
          oldValue: {'status': sale.status},
          newValue: {'status': 'refunded'},
          reason: reason,
          changedBy: currentUser.id,
          changedAt: now,
          metadata: {
            'refund_amount': sale.totalAmount,
            'original_payment_method': sale.paymentMethod,
          },
        );

        await Supabase.instance.client
            .from(AppConstants.salesHistoryTable)
            .insert(historyRecord.toJson());

        // Restore inventory (add back the sold items)
        // Note: This would require getting sale items and updating product stock
        
        _loadSales(); // Refresh the sales list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sale ${sale.saleNumber} refunded successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refunding sale: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sales Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_hasActiveSession)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _showStartSaleDialog,
              tooltip: 'Start Sale Session',
            ),
          if (_hasActiveSession)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _showEndSaleDialog,
              tooltip: 'End Sale Session',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search sales...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Date Filter
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDate != null 
                              ? 'Date: ${_formatDate(_selectedDate!)}'
                              : 'Filter by Date',
                        ),
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateFilter,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear date filter',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Sales Summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Sales',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '₹${_totalSales.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${_filteredSales.length}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sales List
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingWidget())
                : _filteredSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sales found',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start by creating your first sale',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSales,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSales.length,
                          itemBuilder: (context, index) {
                            final sale = _filteredSales[index];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(sale.status),
                                  child: Icon(
                                    _getPaymentIcon(sale.paymentMethod),
                                    color: Colors.white,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      sale.saleNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(sale.status).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sale.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(sale.status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (sale.customerName != null)
                                      Text('Customer: ${sale.customerName}'),
                                    Text('${_formatDate(sale.saleDate)} at ${_formatTime(sale.saleDate)}'),
                                    Text('Payment: ${sale.paymentMethod.toUpperCase()}'),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${sale.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (sale.discountAmount > 0)
                                      Text(
                                        'Disc: ₹${sale.discountAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () => _showSaleActionsDialog(sale),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddSalePage(),
            ),
          ).then((_) => _loadSales());
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Shows stock verification dialog after session end
  Future<void> _showStockVerificationDialog(
    String sessionId, 
    String cashMessage, 
    Color cashColor, 
    [Map<String, dynamic>? enhancedStockSummary]
  ) async {
    try {
      // Use enhanced verification results if provided, otherwise fallback to old method
      Map<String, dynamic> summary;
      if (enhancedStockSummary != null) {
        summary = enhancedStockSummary;
        print('Debug: Using ENHANCED summary in dialog: $summary');
      } else {
        summary = await StockSnapshotService.getVerificationSummary(sessionId);
        print('Debug: Using OLD summary in dialog: $summary');
      }
      
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment_turned_in, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Session Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cash reconciliation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cashColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cashColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: cashColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cashMessage,
                        style: TextStyle(
                          color: cashColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Stock verification summary
              if (summary['has_snapshots'] == true) ...[
                Text(
                  'Stock Verification:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(Icons.inventory, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('Total Products: ${summary['total_products']}'),
                  ],
                ),
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: summary['accurate_count'] == summary['total_products'] 
                          ? Colors.green 
                          : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Accurate: ${summary['accurate_count']}/${summary['total_products']} (${summary['accuracy_percentage'].toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: summary['accurate_count'] == summary['total_products'] 
                            ? Colors.green 
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                if (summary['discrepancy_count'] > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Discrepancies: ${summary['discrepancy_count']}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary['message'] ?? 'Stock verification not available',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (summary['has_snapshots'] == true)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StockVerificationPage(sessionId: sessionId),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('View Details'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cashMessage),
            backgroundColor: cashColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

/// Stock counting dialog widget
class _StockCountingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> productsWithExpected;
  final Map<String, TextEditingController> controllers;

  const _StockCountingDialog({
    required this.productsWithExpected,
    required this.controllers,
  });

  @override
  State<_StockCountingDialog> createState() => _StockCountingDialogState();
}

class _StockCountingDialogState extends State<_StockCountingDialog> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    // Add listeners to all controllers for real-time updates
    for (final controller in widget.controllers.values) {
      controller.addListener(() {
        setState(() {}); // Rebuild to show difference indicators
      });
    }
  }
  
  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return widget.productsWithExpected;
    
    return widget.productsWithExpected.where((productData) {
      final product = productData['product'] as Product;
      return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             product.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.inventory_2, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text('Stock Count'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Text(
              'Please count and enter the actual quantity for each product:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Products list
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final productData = _filteredProducts[index];
                    final product = productData['product'] as Product;
                    final expectedQuantity = productData['expected_quantity'] as double;
                    final startingQuantity = productData['starting_quantity'] as double;
                    final movements = productData['movements'] as double;
                    final controller = widget.controllers[product.id]!;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        product.category,
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 100,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Count',
                                      suffixText: product.unit,
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Movement summary and expected quantity
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Start: ${startingQuantity.toStringAsFixed(1)} ${product.unit}',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      'Movements: ${movements >= 0 ? '+' : ''}${movements.toStringAsFixed(1)} ${product.unit}',
                                      style: TextStyle(
                                        color: movements >= 0 ? Colors.green : Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Expected: ${expectedQuantity.toStringAsFixed(1)} ${product.unit}',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Price: ₹${product.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Show difference indicator
                            Builder(
                              builder: (context) {
                                final currentValue = double.tryParse(controller.text) ?? expectedQuantity;
                                final difference = currentValue - expectedQuantity;
                                
                                if (difference.abs() < 0.01) {
                                  return const SizedBox.shrink();
                                }
                                
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: difference > 0 ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: difference > 0 ? Colors.blue.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    difference > 0 
                                        ? '+${difference.toStringAsFixed(1)} ${product.unit} (Extra)'
                                        : '${difference.toStringAsFixed(1)} ${product.unit} (Short)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: difference > 0 ? Colors.blue.shade700 : Colors.orange.shade700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final Map<String, double> counts = {};
            for (final productData in widget.productsWithExpected) {
              final product = productData['product'] as Product;
              final expectedQuantity = productData['expected_quantity'] as double;
              final controller = widget.controllers[product.id];
              if (controller != null) {
                final value = double.tryParse(controller.text) ?? expectedQuantity;
                counts[product.id] = value;
              }
            }
            Navigator.of(context).pop(counts);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm Counts'),
        ),
      ],
    );
  }
}
