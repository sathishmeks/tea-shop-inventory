import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/stock_snapshot_service.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sales_history.dart';
import '../../../domain/entities/stock_snapshot.dart';
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

      // Create end stock snapshot to check for stock discrepancies
      try {
        await StockSnapshotService.createSessionEndSnapshot(
          sessionId: sessionId,
          userId: user.id,
        );
      } catch (e) {
        print('Warning: Could not create end stock snapshot: $e');
      }

      // Check for stock discrepancies
      Map<String, dynamic> stockSummary = {};
      bool hasStockDiscrepancy = false;
      
      try {
        stockSummary = await StockSnapshotService.getVerificationSummary(sessionId);
        hasStockDiscrepancy = stockSummary['has_snapshots'] == true && 
                             stockSummary['discrepancy_count'] > 0;
      } catch (e) {
        print('Warning: Could not get stock verification summary: $e');
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
        await _saveEndBalance(closingBalance);
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

  Future<void> _saveEndBalance(double balance) async {
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
            
            _showStockVerificationDialog(sessionId, 'Session ended successfully!', Colors.green);
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
  Future<void> _showStockVerificationDialog(String sessionId, String cashMessage, Color cashColor) async {
    try {
      // Get verification summary
      final summary = await StockSnapshotService.getVerificationSummary(sessionId);
      
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
