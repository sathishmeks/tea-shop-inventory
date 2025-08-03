import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/sale.dart';
import '../../widgets/loading_widget.dart';
import 'sales_session_report_page.dart';

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
    _loadReports(); // This will now call _getCurrentUser() first
  }

  Future<void> _getCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    print('DEBUG: Current user: ${user?.id}');
    print('DEBUG: Supabase enabled: ${AppConstants.enableSupabase}');
    
    if (user != null) {
      if (AppConstants.enableSupabase) {
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
          print('DEBUG: User role from DB: ${_currentUserRole}');
        } catch (e) {
          print('DEBUG: Error getting user role: $e');
          setState(() {
            _currentUserRole = AppConstants.roleStaff;
            _currentUserId = user.id;
          });
        }
      } else {
        // Even if Supabase is disabled, set the user ID
        setState(() {
          _currentUserRole = AppConstants.roleStaff;
          _currentUserId = user.id;
        });
      }
    } else {
      print('DEBUG: No authenticated user found');
      setState(() {
        _currentUserRole = AppConstants.roleStaff;
        _currentUserId = null;
      });
    }
    
    print('DEBUG: Final _currentUserId: $_currentUserId');
    print('DEBUG: Final _currentUserRole: $_currentUserRole');
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    
    // Ensure user is loaded first
    await _getCurrentUser();
    
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
    print('DEBUG: Loading sales report - _currentUserId: $_currentUserId');
    if (!AppConstants.enableSupabase || _currentUserId == null) {
      throw Exception('Supabase is disabled or user not authenticated');
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
      print('Error loading sales report: $e');
      throw Exception('Failed to load sales report: $e');
    }
  }

  Future<void> _loadInventoryReport() async {
    if (!AppConstants.enableSupabase) {
      throw Exception('Supabase is disabled');
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
      print('Error loading inventory report: $e');
      throw Exception('Failed to load inventory report: $e');
    }
  }

  Future<void> _loadWalletBalanceReport() async {
    print('DEBUG: Loading wallet balance report - _currentUserId: $_currentUserId');
    if (!AppConstants.enableSupabase || _currentUserId == null) {
      throw Exception('Supabase is disabled or user not authenticated');
    }

    try {
      // First get wallet balances without joining users table
      var walletQuery = Supabase.instance.client
          .from(AppConstants.walletBalanceTable)
          .select('*')
          .gte('date', _selectedStartDate.toIso8601String().substring(0, 10))
          .lte('date', _selectedEndDate.toIso8601String().substring(0, 10))
          .order('date', ascending: false);

      final walletResponse = await walletQuery;
      List<Map<String, dynamic>> allBalances = List<Map<String, dynamic>>.from(walletResponse);

      // Filter by user role
      List<Map<String, dynamic>> filteredBalances;
      if (_currentUserRole == AppConstants.roleStaff) {
        filteredBalances = allBalances.where((balance) => balance['user_id'] == _currentUserId).toList();
      } else {
        filteredBalances = allBalances;
      }

      // For each wallet balance session, calculate the total sales for that session period
      for (int i = 0; i < filteredBalances.length; i++) {
        final balance = filteredBalances[i];
        final sessionUserId = balance['user_id'] as String;
        final sessionStartTime = balance['created_at'] as String;
        final sessionEndTime = balance['updated_at'] as String?;
        
        try {
          // Get sales for this specific session period (between session start and end times)
          var salesQuery = Supabase.instance.client
              .from(AppConstants.salesTable)
              .select('total_amount')
              .eq('created_by', sessionUserId)
              .gte('sale_date', sessionStartTime);
          
          // If session is closed, limit to session end time, otherwise use current time
          if (sessionEndTime != null && balance['status'] == 'closed') {
            salesQuery = salesQuery.lte('sale_date', sessionEndTime);
          }

          final salesResponse = await salesQuery;
          final salesList = List<Map<String, dynamic>>.from(salesResponse);
          
          // Calculate total sales for that session
          final totalSales = salesList.fold<double>(0.0, (sum, sale) {
            final amount = sale['total_amount'];
            if (amount is num) {
              return sum + amount.toDouble();
            }
            return sum;
          });
          
          // Add total sales to the balance record
          filteredBalances[i] = {...balance, 'total_sales': totalSales};
          
          print('Debug: Session ${balance['id']}: Start: $sessionStartTime, End: $sessionEndTime, Sales: $totalSales');
        } catch (salesError) {
          print('Warning: Could not fetch sales for session ${balance['id']}: $salesError');
          // Add zero sales if we can't fetch them
          filteredBalances[i] = {...balance, 'total_sales': 0.0};
        }
      }

      // If admin, get user names separately
      if (_currentUserRole == AppConstants.roleAdmin && filteredBalances.isNotEmpty) {
        try {
          // Get unique user IDs
          final userIds = filteredBalances.map((balance) => balance['user_id']).toSet().toList();
          
          // Fetch user names one by one (safer approach)
          final usersMap = <String, String>{};
          for (final userId in userIds) {
            try {
              final userResponse = await Supabase.instance.client
                  .from(AppConstants.usersTable)
                  .select('id, name')
                  .eq('id', userId)
                  .single();
              usersMap[userId] = userResponse['name'] ?? 'Unknown';
            } catch (e) {
              usersMap[userId] = 'User ${userId.substring(0, 8)}';
            }
          }
          
          // Add user names to wallet balance records
          _walletBalanceReport = filteredBalances.map((balance) {
            final userMap = {'name': usersMap[balance['user_id']] ?? 'Unknown'};
            return {...balance, 'users': userMap};
          }).toList();
        } catch (userError) {
          print('Warning: Could not fetch user names: $userError');
          // Fallback: use wallet balances without user names
          _walletBalanceReport = filteredBalances.map((balance) {
            final userMap = {'name': 'User ${balance['user_id']?.substring(0, 8) ?? 'Unknown'}'};
            return {...balance, 'users': userMap};
          }).toList();
        }
      } else {
        // For staff, we don't need user names since it's only their own data
        _walletBalanceReport = filteredBalances;
      }
    } catch (e) {
      print('Error loading wallet balance report: $e');
      throw Exception('Failed to load wallet balance report: $e');
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

                  // Sales Session Report
                  _buildSalesSessionReportSection(),
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
                  final totalSales = balance['total_sales'] as double? ?? 0.0;
                  
                  // Calculate expected closing balance: opening balance + total sales
                  final expectedClosingBalance = openingBalance + totalSales;
                  
                  // Calculate difference: actual closing - expected closing
                  final difference = closingBalance != null ? closingBalance - expectedClosingBalance : 0.0;
                  
                  final status = balance['status'] as String;
                  final date = DateTime.parse(balance['date']);
                  String userName = 'You';
                  if (_currentUserRole == AppConstants.roleAdmin) {
                    final users = balance['users'] as Map<String, dynamic>?;
                    userName = users?['name'] ?? 'Unknown';
                  }
                  
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
                        Text('Sales: ₹${totalSales.toStringAsFixed(2)}'),
                        Text('Expected: ₹${expectedClosingBalance.toStringAsFixed(2)}'),
                        if (closingBalance != null) ...[
                          Text('Actual Closing: ₹${closingBalance.toStringAsFixed(2)}'),
                          Text(
                            'Difference: ₹${difference.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: difference.abs() < 0.01 ? AppTheme.successColor : 
                                     difference > 0 ? Colors.blue : AppTheme.errorColor,
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

  Widget _buildSalesSessionReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales Session Reports',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              if (_walletBalanceReport.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.description, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Click on any session to view detailed report',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _walletBalanceReport.length > 5 ? 5 : _walletBalanceReport.length,
                  itemBuilder: (context, index) {
                    final session = _walletBalanceReport[index];
                    final sessionDate = DateTime.parse(session['date']);
                    final totalSales = (session['total_sales'] as num?)?.toDouble() ?? 0.0;
                    final openingBalance = (session['opening_balance'] as num?)?.toDouble() ?? 0.0;
                    final closingBalance = (session['closing_balance'] as num?)?.toDouble() ?? 0.0;
                    final status = session['status'] ?? 'unknown';
                    final userName = session['user_name'] ?? 'Unknown User';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: status == 'closed' ? AppTheme.successColor : AppTheme.warningColor,
                        child: Icon(
                          status == 'closed' ? Icons.check : Icons.access_time,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        '${sessionDate.day}/${sessionDate.month}/${sessionDate.year} - $userName',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sales: ₹${totalSales.toStringAsFixed(2)}'),
                          Text('Cash: ₹${openingBalance.toStringAsFixed(2)} → ₹${closingBalance.toStringAsFixed(2)}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
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
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.primaryColor),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesSessionReportPage(
                              sessionId: session['id'],
                              sessionDate: sessionDate,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                if (_walletBalanceReport.length > 5)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Showing 5 of ${_walletBalanceReport.length} sessions',
                      style: TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.description, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'No session reports available',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete some sales sessions to generate reports',
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
