import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sales_history.dart';
import '../../widgets/loading_widget.dart';
import 'add_sale_page.dart';
import 'edit_sale_page.dart';
import 'sales_history_page.dart';

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
        
        if (mounted) {
          setState(() {
            _hasActiveSession = true;
          });
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
          final openingBalance = record['opening_balance'] as double;
          print('Debug: Opening balance: $openingBalance, Closing balance: $balance');
          
          // Update the record with closing balance and status
          final updateResponse = await Supabase.instance.client
              .from(AppConstants.walletBalanceTable)
              .update({
                'closing_balance': balance,
                'status': 'closed',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', record['id'])
              .select();

          print('Debug: Update response: $updateResponse');

          // Calculate total sales for this session (between session start and end times)
          final sessionId = record['id'];
          final sessionStartTime = record['created_at'] as String;
          final sessionEndTime = record['updated_at'] as String;
          double totalSales = 0.0;
          
          try {
            final salesQuery = Supabase.instance.client
                .from(AppConstants.salesTable)
                .select('total_amount')
                .eq('created_by', user.id)
                .gte('sale_date', sessionStartTime)
                .lte('sale_date', sessionEndTime);

            final salesResponse = await salesQuery;
            final salesList = List<Map<String, dynamic>>.from(salesResponse);
            
            totalSales = salesList.fold<double>(0.0, (sum, sale) {
              final amount = sale['total_amount'];
              if (amount is num) {
                return sum + amount.toDouble();
              }
              return sum;
            });
            
            print('Debug: Session ID: $sessionId');
            print('Debug: Session start: $sessionStartTime');
            print('Debug: Session end: $sessionEndTime');
            print('Debug: Sales between session times: $totalSales');
          } catch (salesError) {
            print('Debug: Could not fetch session-specific sales total: $salesError');
            totalSales = 0.0;
          }

          // Calculate expected closing balance: opening balance + total sales
          final expectedClosingBalance = openingBalance + totalSales;
          
          // Calculate difference: actual closing - expected closing
          final difference = balance - expectedClosingBalance;
          
          print('Debug: Opening: $openingBalance, Sales: $totalSales, Expected: $expectedClosingBalance, Actual: $balance, Difference: $difference');
          
          if (mounted) {
            setState(() {
              _hasActiveSession = false;
            });
            
            String message;
            Color backgroundColor;
            
            if (difference.abs() < 0.01) {
              message = 'Session ended. Balances match perfectly! (Sales: ₹${totalSales.toStringAsFixed(2)})';
              backgroundColor = Colors.green;
            } else if (difference > 0) {
              message = 'Session ended. Extra cash: ₹${difference.toStringAsFixed(2)} (Sales: ₹${totalSales.toStringAsFixed(2)})';
              backgroundColor = Colors.blue;
            } else {
              message = 'Session ended. Short cash: ₹${difference.abs().toStringAsFixed(2)} (Sales: ₹${totalSales.toStringAsFixed(2)})';
              backgroundColor = Colors.orange;
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: backgroundColor,
                duration: const Duration(seconds: 5),
              ),
            );
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
}
