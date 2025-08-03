import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/loading_widget.dart';

class SalesSessionReportPage extends StatefulWidget {
  final String sessionId;
  final DateTime? sessionDate;

  const SalesSessionReportPage({
    super.key,
    required this.sessionId,
    this.sessionDate,
  });

  @override
  State<SalesSessionReportPage> createState() => _SalesSessionReportPageState();
}

class _SalesSessionReportPageState extends State<SalesSessionReportPage> {
  bool _isLoading = true;
  Map<String, dynamic> _sessionData = {};
  List<Map<String, dynamic>> _initialStock = [];
  List<Map<String, dynamic>> _stockMovements = [];
  List<Map<String, dynamic>> _salesItems = [];
  List<Map<String, dynamic>> _finalStock = [];
  Map<String, dynamic> _sessionSummary = {};

  @override
  void initState() {
    super.initState();
    _loadSessionReport();
  }

  Future<void> _loadSessionReport() async {
    setState(() => _isLoading = true);

    try {
      // First load session data since other methods depend on it
      await _loadSessionData();
      
      // Then load everything else
      await Future.wait([
        _loadInitialStock(),
        _loadStockMovements(),
        _loadSalesItems(),
        _loadFinalStock(),
      ]);

      _calculateSessionSummary();
    } catch (e) {
      print('Error loading session report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadSessionData() async {
    if (!AppConstants.enableSupabase) return;

    try {
      print('DEBUG: Loading session data for ID: ${widget.sessionId}');
      // First get the wallet balance session data
      final response = await Supabase.instance.client
          .from(AppConstants.walletBalanceTable)
          .select('*')
          .eq('id', widget.sessionId)
          .single();

      _sessionData = response;
      print('DEBUG: Session data loaded: ${_sessionData.toString()}');
      print('DEBUG: Session created_at: ${_sessionData['created_at']}');
      print('DEBUG: Session updated_at: ${_sessionData['updated_at']}');
      print('DEBUG: Session user_id: ${_sessionData['user_id']}');
      print('DEBUG: Session status: ${_sessionData['status']}');

      // Get user information separately if user_id exists
      if (_sessionData['user_id'] != null) {
        try {
          final userResponse = await Supabase.instance.client
              .from(AppConstants.usersTable)
              .select('name, email')
              .eq('id', _sessionData['user_id'])
              .single();
          
          _sessionData['users'] = userResponse;
          print('DEBUG: User data loaded: ${userResponse.toString()}');
        } catch (userError) {
          print('Warning: Could not fetch user data: $userError');
          _sessionData['users'] = {'name': 'Unknown User', 'email': ''};
        }
      } else {
        _sessionData['users'] = {'name': 'Unknown User', 'email': ''};
      }
    } catch (e) {
      print('Error loading session data: $e');
      // Set default session data if loading fails
      _sessionData = {
        'id': widget.sessionId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'user_id': 'unknown',
        'opening_balance': 0.0,
        'closing_balance': 0.0,
        'status': 'unknown',
        'users': {'name': 'Unknown User', 'email': ''}
      };
    }
  }

  Future<void> _loadInitialStock() async {
    if (!AppConstants.enableSupabase) return;

    // Get session start snapshot
    final snapshotResponse = await Supabase.instance.client
        .from(AppConstants.stockSnapshotsTable)
        .select('id')
        .eq('session_id', widget.sessionId)
        .eq('snapshot_type', 'session_start')
        .limit(1);

    if (snapshotResponse.isNotEmpty) {
      final snapshotId = snapshotResponse.first['id'];

      final itemsResponse = await Supabase.instance.client
          .from(AppConstants.stockSnapshotItemsTable)
          .select('*')
          .eq('snapshot_id', snapshotId)
          .order('product_name');

      _initialStock = List<Map<String, dynamic>>.from(itemsResponse);
    }
  }

  Future<void> _loadStockMovements() async {
    if (!AppConstants.enableSupabase) return;

    final sessionStartTime = _sessionData['created_at'];
    final sessionEndTime = _sessionData['updated_at'] ?? DateTime.now().toIso8601String();

    print('DEBUG: Loading stock movements for session ${widget.sessionId}');
    print('DEBUG: Session start time: $sessionStartTime');
    print('DEBUG: Session end time: $sessionEndTime');
    
    // Add timezone information
    final now = DateTime.now();
    final utcNow = now.toUtc();
    print('DEBUG: Current local time: $now');
    print('DEBUG: Current UTC time: $utcNow');
    print('DEBUG: Timezone offset: ${now.timeZoneOffset}');

    // Only proceed if we have valid session times
    if (sessionStartTime == null) {
      print('DEBUG: No session start time found');
      _stockMovements = [];
      return;
    }

    // Parse session times and apply timezone buffer
    final sessionStart = DateTime.parse(sessionStartTime);
    final sessionEnd = DateTime.parse(sessionEndTime);
    
    // Create timezone-aware search window
    // Add the timezone offset to account for local time vs UTC time discrepancies
    final timezoneOffset = DateTime.now().timeZoneOffset;
    final searchStartTime = sessionStart.subtract(timezoneOffset);
    final searchEndTime = sessionEnd.add(timezoneOffset);
    
    print('DEBUG: Original session window: $sessionStart to $sessionEnd');
    print('DEBUG: Expanded search window: $searchStartTime to $searchEndTime');

    // Get inventory movements during session
    try {
      // First, let's check all inventory movements without time filter
      final allMovementsResponse = await Supabase.instance.client
          .from(AppConstants.inventoryMovementsTable)
          .select('*, products!inner(name, category, unit)')
          .order('created_at', ascending: false)
          .limit(10);

      print('DEBUG: Recent inventory movements: ${allMovementsResponse.length}');
      for (final movement in allMovementsResponse) {
        print('DEBUG: Movement - Product: ${movement['products']?['name']}, Type: ${movement['movement_type']}, Qty: ${movement['quantity']}, Time: ${movement['created_at']}');
      }

      // Now get movements during expanded session window
      final movementsResponse = await Supabase.instance.client
          .from(AppConstants.inventoryMovementsTable)
          .select('*, products!inner(name, category, unit)')
          .gte('created_at', searchStartTime.toIso8601String())
          .lte('created_at', searchEndTime.toIso8601String())
          .order('created_at');

      print('DEBUG: Movements during expanded session window: ${movementsResponse.length}');
      _stockMovements = List<Map<String, dynamic>>.from(movementsResponse);
    } catch (e) {
      print('Inventory movements table not available: $e');
      _stockMovements = [];
    }
  }

  Future<void> _loadSalesItems() async {
    if (!AppConstants.enableSupabase) return;

    final sessionStartTime = _sessionData['created_at'];
    final sessionEndTime = _sessionData['updated_at'] ?? DateTime.now().toIso8601String();
    final userId = _sessionData['user_id'];

    print('DEBUG: Loading sales for session ${widget.sessionId}');
    print('DEBUG: Session start time: $sessionStartTime');
    print('DEBUG: Session end time: $sessionEndTime');
    print('DEBUG: User ID: $userId');

    // Only proceed if we have valid session data
    if (sessionStartTime == null || userId == null) {
      print('DEBUG: Missing session data - sessionStartTime: $sessionStartTime, userId: $userId');
      _salesItems = [];
      return;
    }

    // Parse session times and apply timezone buffer
    final sessionStart = DateTime.parse(sessionStartTime);
    final sessionEnd = DateTime.parse(sessionEndTime);
    
    // Create timezone-aware search window
    final timezoneOffset = DateTime.now().timeZoneOffset;
    final searchStartTime = sessionStart.subtract(timezoneOffset);
    final searchEndTime = sessionEnd.add(timezoneOffset);
    
    print('DEBUG: Expanded sales search window: $searchStartTime to $searchEndTime');

    try {
      // First, let's check all recent sales for this user
      final allSalesResponse = await Supabase.instance.client
          .from(AppConstants.salesTable)
          .select()
          .eq('created_by', userId)
          .order('sale_date', ascending: false)
          .limit(10);

      print('DEBUG: Recent sales by user: ${allSalesResponse.length}');
      for (final sale in allSalesResponse) {
        print('DEBUG: Sale - ID: ${sale['id']}, Date: ${sale['sale_date']}, Amount: ${sale['total_amount']}, Status: ${sale['status']}');
      }

      // Get all sales during expanded session window
      final salesResponse = await Supabase.instance.client
          .from(AppConstants.salesTable)
          .select()
          .eq('created_by', userId)
          .gte('sale_date', searchStartTime.toIso8601String())
          .lte('sale_date', searchEndTime.toIso8601String())
          .order('sale_date');

      print('DEBUG: Sales during expanded session window: ${salesResponse.length}');
      final sales = List<Map<String, dynamic>>.from(salesResponse);

      // Get sale items for each sale
      List<Map<String, dynamic>> allSaleItems = [];
      for (final sale in sales) {
        print('DEBUG: Processing sale ${sale['id']}');
        final saleItemsResponse = await Supabase.instance.client
            .from(AppConstants.saleItemsTable)
            .select('*, products!inner(name, category, unit, price)')
            .eq('sale_id', sale['id']);

        print('DEBUG: Sale items for sale ${sale['id']}: ${saleItemsResponse.length}');
        for (final item in saleItemsResponse) {
          allSaleItems.add({
            ...item,
            'sale_number': sale['sale_number'],
            'sale_date': sale['sale_date'],
            'sale_status': sale['status'],
            'customer_name': sale['customer_name'],
            'payment_method': sale['payment_method'],
          });
        }
      }

      print('DEBUG: Total sale items: ${allSaleItems.length}');
      _salesItems = allSaleItems;
    } catch (e) {
      print('Error loading sales items: $e');
      _salesItems = [];
    }
  }

  Future<void> _loadFinalStock() async {
    if (!AppConstants.enableSupabase) return;

    // Get session end snapshot
    final snapshotResponse = await Supabase.instance.client
        .from(AppConstants.stockSnapshotsTable)
        .select('id')
        .eq('session_id', widget.sessionId)
        .eq('snapshot_type', 'session_end')
        .limit(1);

    if (snapshotResponse.isNotEmpty) {
      final snapshotId = snapshotResponse.first['id'];

      final itemsResponse = await Supabase.instance.client
          .from(AppConstants.stockSnapshotItemsTable)
          .select('*')
          .eq('snapshot_id', snapshotId)
          .order('product_name');

      _finalStock = List<Map<String, dynamic>>.from(itemsResponse);
    }
  }

  void _calculateSessionSummary() {
    // Calculate totals from sales
    double totalSales = 0;
    int totalItemsSold = 0;
    Map<String, int> productSales = {};

    for (final item in _salesItems) {
      if (item['sale_status'] == 'completed') {
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        totalSales += quantity * price;
        totalItemsSold += quantity;

        final productName = item['products']?['name'] ?? 'Unknown Product';
        productSales[productName] = (productSales[productName] ?? 0) + quantity;
      }
    }

    // Calculate stock movements summary
    Map<String, int> movementsSummary = {};
    for (final movement in _stockMovements) {
      final type = movement['movement_type'] ?? 'unknown';
      final quantity = (movement['quantity'] as num?)?.toInt() ?? 0;
      movementsSummary[type] = (movementsSummary[type] ?? 0) + quantity;
    }

    // Calculate cash flow with null safety
    final openingBalance = (_sessionData['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final closingBalance = (_sessionData['closing_balance'] as num?)?.toDouble() ?? 0.0;
    final cashDifference = closingBalance - openingBalance;
    final expectedClosing = openingBalance + totalSales;
    final cashVariance = cashDifference - totalSales;

    _sessionSummary = {
      'total_sales': totalSales,
      'total_items_sold': totalItemsSold,
      'product_sales': productSales,
      'movements_summary': movementsSummary,
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'cash_difference': cashDifference,
      'expected_closing': expectedClosing,
      'cash_variance': cashVariance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sales Session Report'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessionReport,
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
                  _buildSessionHeader(),
                  const SizedBox(height: 20),
                  _buildSessionSummaryCard(),
                  const SizedBox(height: 20),
                  _buildInitialStockSection(),
                  const SizedBox(height: 20),
                  _buildStockMovementsSection(),
                  const SizedBox(height: 20),
                  _buildSalesItemsSection(),
                  const SizedBox(height: 20),
                  _buildFinalStockSection(),
                  const SizedBox(height: 20),
                  _buildStockComparisonSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionHeader() {
    final sessionDate = DateTime.parse(_sessionData['created_at'] ?? DateTime.now().toIso8601String());
    final sessionEndTime = _sessionData['updated_at'] != null 
        ? DateTime.parse(_sessionData['updated_at']) 
        : null;
    final userName = _sessionData['users']?['name'] ?? 'Unknown User';
    final userEmail = _sessionData['users']?['email'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Session Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Session ID:', '${widget.sessionId.substring(0, 8)}...'),
            _buildInfoRow('Date:', '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}'),
            _buildInfoRow('Start Time:', '${sessionDate.hour.toString().padLeft(2, '0')}:${sessionDate.minute.toString().padLeft(2, '0')} (${sessionDate.isUtc ? 'UTC' : 'Local'})'),
            if (sessionEndTime != null)
              _buildInfoRow('End Time:', '${sessionEndTime.hour.toString().padLeft(2, '0')}:${sessionEndTime.minute.toString().padLeft(2, '0')} (${sessionEndTime.isUtc ? 'UTC' : 'Local'})'),
            _buildInfoRow('Duration:', sessionEndTime != null 
                ? '${sessionEndTime.difference(sessionDate).inMinutes} minutes'
                : 'Active'),
            _buildInfoRow('User:', userName),
            if (userEmail.isNotEmpty) _buildInfoRow('Email:', userEmail),
            _buildInfoRow('Status:', _sessionData['status'] == 'opened' ? 'Active' : 'Closed'),
            
            // Add timezone warning if there might be issues
            if (sessionDate.isUtc && DateTime.now().timeZoneOffset.inHours != 0)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Note: Times shown in UTC. Your local time is ${DateTime.now().timeZoneOffset.inHours > 0 ? '+' : ''}${DateTime.now().timeZoneOffset.inHours} hours from UTC.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Session Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    '₹${_sessionSummary['total_sales']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.currency_rupee,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Items Sold',
                    '${_sessionSummary['total_items_sold'] ?? 0}',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Opening Cash',
                    '₹${_sessionSummary['opening_balance']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.account_balance_wallet,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Closing Cash',
                    '₹${_sessionSummary['closing_balance']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.account_balance,
                    _getCashVarianceColor(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialStockSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Initial Stock (Session Start)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_initialStock.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('No initial stock snapshot available'),
                  ],
                ),
              )
            else
              _buildStockTable(_initialStock, 'quantity_recorded'),
          ],
        ),
      ),
    );
  }

  Widget _buildStockMovementsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Stock Movements During Session',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_stockMovements.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('No stock movements during this session'),
                  ],
                ),
              )
            else
              _buildMovementsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.point_of_sale, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Sales Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_salesItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('No sales during this session'),
                  ],
                ),
              )
            else
              _buildSalesTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalStockSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Final Stock (Session End)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_finalStock.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('No final stock snapshot available'),
                  ],
                ),
              )
            else
              _buildStockTable(_finalStock, 'quantity_recorded'),
          ],
        ),
      ),
    );
  }

  Widget _buildStockComparisonSection() {
    if (_initialStock.isEmpty || _finalStock.isEmpty) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Stock Comparison & Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildComparisonTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTable(List<Map<String, dynamic>> stockData, String quantityField) {
    return Table(
      border: TableBorder.all(color: Colors.grey.withOpacity(0.3)),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1)),
          children: [
            _buildTableHeader('Product'),
            _buildTableHeader('Qty'),
            _buildTableHeader('Price'),
            _buildTableHeader('Value'),
          ],
        ),
        ...stockData.map((item) {
          final quantity = (item[quantityField] as num).toDouble();
          final price = (item['unit_price'] as num).toDouble();
          final value = quantity * price;

          return TableRow(
            children: [
              _buildTableCell(item['product_name'] ?? ''),
              _buildTableCell(quantity.toString()),
              _buildTableCell('₹${price.toStringAsFixed(2)}'),
              _buildTableCell('₹${value.toStringAsFixed(2)}'),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMovementsTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.withOpacity(0.3)),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1)),
          children: [
            _buildTableHeader('Product'),
            _buildTableHeader('Type'),
            _buildTableHeader('Qty'),
            _buildTableHeader('Time'),
          ],
        ),
        ..._stockMovements.map((movement) {
          final time = DateTime.parse(movement['created_at']);
          final type = movement['movement_type'] ?? '';
          final quantity = (movement['quantity'] as num).toInt();
          final productName = movement['products']?['name'] ?? 'Unknown';

          return TableRow(
            children: [
              _buildTableCell(productName),
              _buildTableCell(_formatMovementType(type)),
              _buildTableCell(
                '${type == 'refill' || type == 'in' ? '+' : ''}$quantity',
                color: type == 'refill' || type == 'in' ? Colors.green : Colors.red,
              ),
              _buildTableCell('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSalesTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.withOpacity(0.3)),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1)),
          children: [
            _buildTableHeader('Product'),
            _buildTableHeader('Qty'),
            _buildTableHeader('Price'),
            _buildTableHeader('Total'),
            _buildTableHeader('Status'),
          ],
        ),
        ..._salesItems.map((item) {
          final quantity = (item['quantity'] as num).toInt();
          final price = (item['unit_price'] as num).toDouble();
          final total = quantity * price;
          final status = item['sale_status'] ?? '';
          final productName = item['products']?['name'] ?? 'Unknown';

          return TableRow(
            children: [
              _buildTableCell(productName),
              _buildTableCell(quantity.toString()),
              _buildTableCell('₹${price.toStringAsFixed(2)}'),
              _buildTableCell('₹${total.toStringAsFixed(2)}'),
              _buildTableCell(
                status.toUpperCase(),
                color: _getStatusColor(status),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildComparisonTable() {
    // Create a map for easier comparison
    Map<String, Map<String, dynamic>> comparison = {};
    
    for (final initial in _initialStock) {
      final productId = initial['product_id'];
      comparison[productId] = {
        'product_name': initial['product_name'],
        'initial_qty': (initial['quantity_recorded'] as num).toDouble(),
        'final_qty': 0.0,
        'unit_price': (initial['unit_price'] as num).toDouble(),
      };
    }

    for (final final_ in _finalStock) {
      final productId = final_['product_id'];
      if (comparison.containsKey(productId)) {
        comparison[productId]!['final_qty'] = (final_['quantity_recorded'] as num).toDouble();
      }
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.withOpacity(0.3)),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1)),
          children: [
            _buildTableHeader('Product'),
            _buildTableHeader('Initial'),
            _buildTableHeader('Final'),
            _buildTableHeader('Change'),
            _buildTableHeader('Status'),
          ],
        ),
        ...comparison.values.map((item) {
          final initialQty = item['initial_qty'] as double;
          final finalQty = item['final_qty'] as double;
          final change = finalQty - initialQty;
          final isAccurate = change.abs() <= 0.01;

          return TableRow(
            children: [
              _buildTableCell(item['product_name']),
              _buildTableCell(initialQty.toString()),
              _buildTableCell(finalQty.toString()),
              _buildTableCell(
                '${change >= 0 ? '+' : ''}${change.toString()}',
                color: change > 0 ? Colors.green : (change < 0 ? Colors.red : Colors.grey),
              ),
              _buildTableCell(
                isAccurate ? 'OK' : 'DIFF',
                color: isAccurate ? Colors.green : Colors.red,
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontWeight: color != null ? FontWeight.w500 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMovementType(String type) {
    switch (type.toLowerCase()) {
      case 'refill':
        return 'Refill';
      case 'in':
        return 'Stock In';
      case 'out':
        return 'Stock Out';
      case 'adjustment':
        return 'Adjustment';
      default:
        return type.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getCashVarianceColor() {
    final variance = _sessionSummary['cash_variance'];
    if (variance == null) return Colors.grey;
    
    final varianceValue = (variance as num).toDouble();
    return varianceValue.abs() <= 0.01 ? Colors.green : Colors.red;
  }
}
