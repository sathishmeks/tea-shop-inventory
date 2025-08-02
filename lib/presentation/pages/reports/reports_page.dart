import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/sale.dart';
import '../../widgets/loading_widget.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = false;
  String? _currentUserRole;
  String? _currentUserId;
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();
  List<Sale> _salesReport = [];
  Map<String, dynamic> _inventoryReport = {};
  Map<String, dynamic> _summaryData = {};
  List<Map<String, dynamic>> _walletBalanceReport = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadReports();
  }

  Future<void> _getCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && AppConstants.enableSupabase) {
      try {
        final response = await Supabase.instance.client
            .from(AppConstants.usersTable)
            .select('role')
            .eq('id', user.id)
            .single();
        
        setState(() {
          _currentUserRole = response['role'] ?? AppConstants.roleStaff;
          _currentUserId = user.id;
        });
      } catch (e) {
        setState(() {
          _currentUserRole = AppConstants.roleStaff;
          _currentUserId = user.id;
        });
      }
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadSalesReport(),
        _loadInventoryReport(),
        _loadWalletBalanceReport(),
      ]);
      _calculateSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadSalesReport() async {
    if (!AppConstants.enableSupabase || _currentUserId == null) {
      _salesReport = _getMockSalesReport();
      return;
    }

    try {
      var query = Supabase.instance.client
          .from(AppConstants.salesTable)
          .select()
          .gte('sale_date', _selectedStartDate.toIso8601String())
          .lte('sale_date', _selectedEndDate.toIso8601String())
          .order('sale_date', ascending: false);

      final response = await query;
      
      List<Sale> allSales = (response as List)
          .map((json) => Sale.fromJson(json))
          .toList();

      // Filter by user role in code instead of query
      if (_currentUserRole == AppConstants.roleStaff && _currentUserId != null) {
        _salesReport = allSales.where((sale) => sale.createdBy == _currentUserId).toList();
      } else {
        _salesReport = allSales;
      }
    } catch (e) {
      _salesReport = _getMockSalesReport();
    }
  }

  Future<void> _loadInventoryReport() async {
    if (!AppConstants.enableSupabase) {
      _inventoryReport = _getMockInventoryReport();
      return;
    }

    try {
      // Get low stock items
      final lowStockResponse = await Supabase.instance.client
          .from(AppConstants.productsTable)
          .select()
          .lt('stock_quantity', AppConstants.lowStockThreshold);

      // Get inventory movements
      var movementsQuery = Supabase.instance.client
          .from('inventory_movements')
          .select('*, products!inner(name)')
          .gte('created_at', _selectedStartDate.toIso8601String())
          .lte('created_at', _selectedEndDate.toIso8601String())
          .order('created_at', ascending: false);

      final movementsResponse = await movementsQuery;
      
      // Filter by user role in code instead of query
      List<dynamic> allMovements = movementsResponse as List;
      List<dynamic> filteredMovements;
      
      if (_currentUserRole == AppConstants.roleStaff && _currentUserId != null) {
        filteredMovements = allMovements.where((movement) => movement['created_by'] == _currentUserId).toList();
      } else {
        filteredMovements = allMovements;
      }

      // Separate additions (in) and removals (out) for staff view
      List<dynamic> staffAdditions = [];
      List<dynamic> staffRemovals = [];
      
      if (_currentUserRole == AppConstants.roleStaff) {
        staffAdditions = filteredMovements.where((movement) => 
          movement['movement_type'] == 'purchase' || 
          movement['movement_type'] == 'adjustment' && movement['quantity'] > 0
        ).toList();
        
        staffRemovals = filteredMovements.where((movement) => 
          movement['movement_type'] == 'sale' || 
          movement['movement_type'] == 'damage' ||
          (movement['movement_type'] == 'adjustment' && movement['quantity'] < 0)
        ).toList();
      }

      _inventoryReport = {
        'low_stock_items': lowStockResponse,
        'movements': filteredMovements,
        'staff_additions': staffAdditions,
        'staff_removals': staffRemovals,
      };
    } catch (e) {
      _inventoryReport = _getMockInventoryReport();
    }
  }

  Future<void> _loadWalletBalanceReport() async {
    if (!AppConstants.enableSupabase || _currentUserId == null) {
      _walletBalanceReport = [];
      return;
    }

    try {
      var walletQuery = Supabase.instance.client
          .from(AppConstants.walletBalanceTable)
          .select('*, users!inner(name)')
          .gte('date', _selectedStartDate.toIso8601String().substring(0, 10))
          .lte('date', _selectedEndDate.toIso8601String().substring(0, 10))
          .order('date', ascending: false);

      final response = await walletQuery;
      List<Map<String, dynamic>> allBalances = List<Map<String, dynamic>>.from(response);

      // Filter by user role in code instead of query
      if (_currentUserRole == AppConstants.roleStaff) {
        _walletBalanceReport = allBalances.where((balance) => balance['user_id'] == _currentUserId).toList();
      } else {
        _walletBalanceReport = allBalances;
      }
    } catch (e) {
      _walletBalanceReport = [];
    }
  }

  void _calculateSummary() {
    final totalSales = _salesReport.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final salesCount = _salesReport.length;
    final avgSale = salesCount > 0 ? totalSales / salesCount : 0.0;
    
    final completedSales = _salesReport.where((sale) => sale.status == 'completed').length;
    final pendingSales = _salesReport.where((sale) => sale.status == 'pending').length;
    final cancelledSales = _salesReport.where((sale) => sale.status == 'cancelled').length;

    _summaryData = {
      'total_sales': totalSales,
      'sales_count': salesCount,
      'average_sale': avgSale,
      'completed_sales': completedSales,
      'pending_sales': pendingSales,
      'cancelled_sales': cancelledSales,
      'low_stock_count': (_inventoryReport['low_stock_items'] as List?)?.length ?? 0,
      'inventory_movements': (_inventoryReport['movements'] as List?)?.length ?? 0,
    };
  }

  List<Sale> _getMockSalesReport() {
    return [
      Sale(
        id: '1',
        saleNumber: 'S001',
        totalAmount: 150.00,
        status: 'completed',
        paymentMethod: 'cash',
        saleDate: DateTime.now().subtract(const Duration(days: 1)),
        createdBy: _currentUserId ?? 'user-1',
      ),
      Sale(
        id: '2',
        saleNumber: 'S002',
        totalAmount: 250.00,
        status: 'completed',
        paymentMethod: 'upi',
        saleDate: DateTime.now().subtract(const Duration(days: 2)),
        createdBy: _currentUserId ?? 'user-1',
      ),
    ];
  }

  Map<String, dynamic> _getMockInventoryReport() {
    return {
      'low_stock_items': [
        {'name': 'Earl Grey Tea', 'stock_quantity': 5, 'minimum_stock': 10},
        {'name': 'Green Tea', 'stock_quantity': 8, 'minimum_stock': 10},
      ],
      'movements': [
        {
          'type': 'sale',
          'quantity': -2,
          'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'products': {'name': 'Earl Grey Tea'},
        },
        {
          'type': 'restock',
          'quantity': 20,
          'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
          'products': {'name': 'Green Tea'},
        },
      ],
    };
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_currentUserRole == AppConstants.roleAdmin ? 'All Reports' : 'My Reports'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
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
                  // Date Range Display
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Report Period: ${_formatDate(_selectedStartDate)} - ${_formatDate(_selectedEndDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Cards
                  _buildSummarySection(),
                  const SizedBox(height: 16),

                  // Sales Report
                  _buildSalesReportSection(),
                  const SizedBox(height: 16),

                  // Inventory Report
                  if (_currentUserRole == AppConstants.roleAdmin) ...[
                    _buildInventoryReportSection(),
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildStaffInventorySection(),
                    const SizedBox(height: 16),
                  ],

                  // Wallet Balance Report
                  _buildWalletBalanceSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Sales',
                '₹${_summaryData['total_sales']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.monetization_on,
                AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                'Sales Count',
                '${_summaryData['sales_count'] ?? 0}',
                Icons.receipt,
                AppTheme.infoColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Average Sale',
                '₹${_summaryData['average_sale']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.trending_up,
                AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                'Low Stock Items',
                '${_summaryData['low_stock_count'] ?? 0}',
                Icons.warning,
                AppTheme.errorColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales Report',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // Status breakdown
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusCount('Completed', _summaryData['completed_sales'] ?? 0, AppTheme.successColor),
                    _buildStatusCount('Pending', _summaryData['pending_sales'] ?? 0, AppTheme.warningColor),
                    _buildStatusCount('Cancelled', _summaryData['cancelled_sales'] ?? 0, AppTheme.errorColor),
                  ],
                ),
              ),
              const Divider(),
              // Recent sales list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _salesReport.length > 5 ? 5 : _salesReport.length,
                itemBuilder: (context, index) {
                  final sale = _salesReport[index];
                  return ListTile(
                    leading: Icon(
                      _getPaymentIcon(sale.paymentMethod),
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(sale.saleNumber),
                    subtitle: Text(_formatDateTime(sale.saleDate)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${sale.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(sale.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            sale.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_salesReport.length > 5)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Showing 5 of ${_salesReport.length} sales',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryReportSection() {
    final lowStockItems = _inventoryReport['low_stock_items'] as List? ?? [];
    final movements = _inventoryReport['movements'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory Report (Admin View)',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        
        // Low Stock Items
        if (lowStockItems.isNotEmpty) ...[
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: AppTheme.errorColor),
                      const SizedBox(width: 8),
                      Text(
                        'Low Stock Items',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
                ...lowStockItems.map((item) => ListTile(
                  leading: Icon(Icons.inventory, color: AppTheme.errorColor),
                  title: Text(item['name'] ?? ''),
                  subtitle: Text('Current: ${item['stock_quantity']} | Min: ${item['minimum_stock']}'),
                  trailing: Text(
                    'Low Stock',
                    style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Recent Inventory Movements
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Recent Inventory Movements',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...movements.take(5).map((movement) => ListTile(
                leading: Icon(
                  movement['type'] == 'sale' ? Icons.remove : Icons.add,
                  color: movement['type'] == 'sale' ? AppTheme.errorColor : AppTheme.successColor,
                ),
                title: Text(movement['products']['name'] ?? ''),
                subtitle: Text(_formatDateTime(DateTime.parse(movement['created_at']))),
                trailing: Text(
                  '${movement['quantity'] > 0 ? '+' : ''}${movement['quantity']}',
                  style: TextStyle(
                    color: movement['quantity'] > 0 ? AppTheme.successColor : AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )),
              if (movements.length > 5)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Showing 5 of ${movements.length} movements',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffInventorySection() {
    final staffAdditions = _inventoryReport['staff_additions'] as List? ?? [];
    final staffRemovals = _inventoryReport['staff_removals'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Inventory Activities',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        
        // Staff Additions
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.add_circle, color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    Text(
                      'Items Added (${staffAdditions.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (staffAdditions.isNotEmpty) ...[
                ...staffAdditions.take(3).map((addition) => ListTile(
                  leading: Icon(Icons.inventory_2, color: AppTheme.successColor),
                  title: Text(addition['products']['name'] ?? ''),
                  subtitle: Text(_formatDateTime(DateTime.parse(addition['created_at']))),
                  trailing: Text(
                    '+${addition['quantity']}',
                    style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold),
                  ),
                )),
                if (staffAdditions.length > 3)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Showing 3 of ${staffAdditions.length} additions',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No inventory additions in this period'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Staff Removals
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.remove_circle, color: AppTheme.errorColor),
                    const SizedBox(width: 8),
                    Text(
                      'Items Removed (${staffRemovals.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (staffRemovals.isNotEmpty) ...[
                ...staffRemovals.take(3).map((removal) => ListTile(
                  leading: Icon(Icons.inventory, color: AppTheme.errorColor),
                  title: Text(removal['products']['name'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDateTime(DateTime.parse(removal['created_at']))),
                      Text(
                        'Type: ${removal['movement_type']}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${removal['quantity']}',
                    style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                  ),
                )),
                if (staffRemovals.length > 3)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Showing 3 of ${staffRemovals.length} removals',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No inventory removals in this period'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWalletBalanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentUserRole == AppConstants.roleAdmin ? 'All Wallet Balances' : 'My Wallet Balance Sessions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_walletBalanceReport.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Balance Sessions (${_walletBalanceReport.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                ...(_walletBalanceReport.take(5).map((balance) {
                  final openingBalance = balance['opening_balance'] as double;
                  final closingBalance = balance['closing_balance'] as double?;
                  final difference = closingBalance != null ? closingBalance - openingBalance : 0.0;
                  final status = balance['status'] as String;
                  final date = DateTime.parse(balance['date']);
                  final userName = _currentUserRole == AppConstants.roleAdmin 
                      ? balance['users']['name'] ?? 'Unknown' 
                      : 'You';
                  
                  return ListTile(
                    leading: Icon(
                      status == 'closed' ? Icons.check_circle : Icons.pending,
                      color: status == 'closed' ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                    title: Text('${_formatDate(date)} - $userName'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Opening: ₹${openingBalance.toStringAsFixed(2)}'),
                        if (closingBalance != null) ...[
                          Text('Closing: ₹${closingBalance.toStringAsFixed(2)}'),
                          Text(
                            'Difference: ₹${difference.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: difference >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Session still open',
                            style: TextStyle(color: AppTheme.warningColor),
                          ),
                        ],
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'closed' ? AppTheme.successColor : AppTheme.warningColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                })),
                if (_walletBalanceReport.length > 5)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Showing 5 of ${_walletBalanceReport.length} sessions',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.account_balance_wallet, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'No wallet balance sessions found',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a sale session to track wallet balances',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
