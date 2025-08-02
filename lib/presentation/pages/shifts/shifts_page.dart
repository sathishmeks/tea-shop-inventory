import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/shift.dart';
import '../../widgets/loading_widget.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  List<Shift> _shifts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';
  Shift? _activeShift;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    
    try {
      if (AppConstants.enableSupabase) {
        final response = await Supabase.instance.client
            .from('shifts')
            .select()
            .order('start_time', ascending: false);

        _shifts = (response as List)
            .map((json) => Shift.fromJson(json))
            .toList();
            
        // Find active shift
        _activeShift = _shifts.firstWhere(
          (shift) => shift.status == 'active',
          orElse: () => Shift(
            id: '',
            userId: '',
            userName: '',
            startTime: DateTime.now(),
          ),
        );
        
        if (_activeShift?.id.isEmpty ?? true) {
          _activeShift = null;
        }
      } else {
        // Mock data for offline mode
        await Future.delayed(const Duration(seconds: 1));
        _shifts = _getMockShifts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading shifts: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  List<Shift> _getMockShifts() {
    return [
      Shift(
        id: '1',
        userId: 'user-1',
        userName: 'John Doe',
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        status: 'active',
        totalSales: 2500.0,
        totalTransactions: 15,
      ),
      Shift(
        id: '2',
        userId: 'user-1',
        userName: 'John Doe',
        startTime: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
        endTime: DateTime.now().subtract(const Duration(days: 1)),
        status: 'completed',
        totalSales: 5200.0,
        totalTransactions: 32,
      ),
    ];
  }

  List<Shift> get _filteredShifts {
    return _shifts.where((shift) {
      final matchesSearch = shift.userName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'all' || shift.status == _statusFilter;
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _startShift() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _StartShiftDialog(),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      
      try {
        final uuid = const Uuid();
        final now = DateTime.now();
        
        final shift = Shift(
          id: uuid.v4(),
          userId: 'user-1', // TODO: Get from auth
          userName: 'Current User', // TODO: Get from auth
          startTime: now,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        );

        if (AppConstants.enableSupabase) {
          await Supabase.instance.client
              .from('shifts')
              .insert(shift.toJson());
        }

        await _loadShifts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Shift started successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting shift: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endShift(Shift shift) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EndShiftDialog(shift: shift),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      
      try {
        final now = DateTime.now();
        
        if (AppConstants.enableSupabase) {
          await Supabase.instance.client
              .from('shifts')
              .update({
                'end_time': now.toIso8601String(),
                'status': 'completed',
                'updated_at': now.toIso8601String(),
              })
              .eq('id', shift.id);
        }

        await _loadShifts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Shift ended successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending shift: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
      
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.successColor;
      case 'completed':
        return AppTheme.primaryColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Shift Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShifts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Shift Card
          if (_activeShift != null)
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                color: AppTheme.successColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active Shift',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _endShift(_activeShift!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('End Shift'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Employee: ${_activeShift!.userName}'),
                      Text('Started: ${_formatDate(_activeShift!.startTime)} at ${_formatTime(_activeShift!.startTime)}'),
                      Text('Duration: ${_activeShift!.formattedDuration}'),
                      if (_activeShift!.totalSales != null)
                        Text('Sales: ₹${_activeShift!.totalSales!.toStringAsFixed(2)}'),
                      if (_activeShift!.totalTransactions != null)
                        Text('Transactions: ${_activeShift!.totalTransactions}'),
                    ],
                  ),
                ),
              ),
            ),
          
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search shifts...',
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
                Row(
                  children: [
                    const Text('Status: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Shifts List
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingWidget())
                : _filteredShifts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No shifts found',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _activeShift == null 
                                  ? 'Start your first shift'
                                  : 'No shifts match your filter',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadShifts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredShifts.length,
                          itemBuilder: (context, index) {
                            final shift = _filteredShifts[index];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(shift.status),
                                  child: Icon(
                                    shift.status == 'active' 
                                        ? Icons.play_arrow
                                        : shift.status == 'completed'
                                            ? Icons.check
                                            : Icons.cancel,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      shift.userName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(shift.status).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        shift.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(shift.status),
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
                                    Text('Started: ${_formatDate(shift.startTime)} at ${_formatTime(shift.startTime)}'),
                                    if (shift.endTime != null)
                                      Text('Ended: ${_formatDate(shift.endTime!)} at ${_formatTime(shift.endTime!)}'),
                                    Text('Duration: ${shift.formattedDuration}'),
                                    if (shift.totalSales != null)
                                      Text('Sales: ₹${shift.totalSales!.toStringAsFixed(2)}'),
                                  ],
                                ),
                                trailing: shift.status == 'active'
                                    ? TextButton(
                                        onPressed: () => _endShift(shift),
                                        child: const Text('End'),
                                      )
                                    : null,
                                onTap: () {
                                  // TODO: Navigate to shift details
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _activeShift == null
          ? FloatingActionButton(
              onPressed: _startShift,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.play_arrow, color: Colors.white),
            )
          : null,
    );
  }
}

class _StartShiftDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Shift'),
      content: const Text('Are you sure you want to start a new shift?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Start Shift'),
        ),
      ],
    );
  }
}

class _EndShiftDialog extends StatefulWidget {
  final Shift shift;

  const _EndShiftDialog({required this.shift});

  @override
  State<_EndShiftDialog> createState() => _EndShiftDialogState();
}

class _EndShiftDialogState extends State<_EndShiftDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End Shift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('End shift for ${widget.shift.userName}?'),
          Text('Duration: ${widget.shift.formattedDuration}'),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('End Shift'),
        ),
      ],
    );
  }
}
