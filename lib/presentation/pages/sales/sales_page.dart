import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/sale.dart';
import '../../widgets/loading_widget.dart';
import 'add_sale_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSales();
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
                  await _saveEndBalance(balance);
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
            child: const Text('End'),
          ),
        ],
      ),
    );
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
        
        // Check if there's already an open session for today
        final existingSession = await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .select()
            .eq('user_id', user.id)
            .eq('date', today)
            .eq('status', 'opened');
            
        print('Debug: Existing sessions: $existingSession');
        
        if (existingSession.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You already have an active session for today')),
            );
          }
          return;
        }
        
        final data = {
          'user_id': user.id,
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
        // Ensure user exists in public.users
        try {
          final existingUserCheck = await Supabase.instance.client
              .from(AppConstants.usersTable)
              .select('id')
              .eq('id', user.id);
          print('Debug: Existing user check: $existingUserCheck');
          if (existingUserCheck.isEmpty) {
            print('Debug: Creating user in public.users table');
            await Supabase.instance.client
                .from(AppConstants.usersTable)
                .insert({
                  'id': user.id,
                  'email': user.email ?? '',
                  'name': user.email?.split('@')[0] ?? 'Staff Member',
                  'role': 'staff',
                });
            print('Debug: User created successfully');
          } else {
            print('Debug: User already exists in public.users');
          }
        } catch (userError) {
          print('Debug: Error checking/creating user: $userError');
        }
        final today = DateTime.now().toIso8601String().substring(0, 10);
        print('Debug: Today date: $today');
        // Check if there's already an open session for today
        final existingSession = await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .select()
            .eq('user_id', user.id)
            .eq('date', today)
            .eq('status', 'opened');
        print('Debug: Existing sessions: $existingSession');
        if (existingSession.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You already have an active session for today'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        final data = {
          'user_id': user.id,
          'opening_balance': balance,
          'closing_balance': null,
          'date': today,
          'status': 'opened',
        };
        print('Debug: Inserting wallet balance data: $data');
        final response = await Supabase.instance.client
            .from(AppConstants.walletBalanceTable)
            .insert(data)
            .select();
        print('Debug: Insert response: $response');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale session started successfully'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sales Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _showStartSaleDialog,
            tooltip: 'Start Sale Session',
          ),
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
                                onTap: () {
                                  // TODO: Navigate to sale details
                                },
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
}
