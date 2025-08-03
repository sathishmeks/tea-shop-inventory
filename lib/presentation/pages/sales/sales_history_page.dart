import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/sales_history.dart';
import '../../widgets/loading_widget.dart';

class SalesHistoryPage extends StatefulWidget {
  final String saleId;

  const SalesHistoryPage({
    super.key,
    required this.saleId,
  });

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  List<SalesHistory> _historyRecords = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    _loadSalesHistory();
  }

  Future<void> _loadSalesHistory() async {
    if (!AppConstants.enableSupabase) {
      setState(() {
        _historyRecords = [];
        _isLoading = false;
        _errorMessage = 'Sales history requires Supabase connection';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from(AppConstants.salesHistoryTable)
          .select()
          .eq('sale_id', widget.saleId)
          .order('changed_at', ascending: false);

      final historyList = (response as List)
          .map((item) => SalesHistory.fromJson(item))
          .toList();

      // Load user names for all unique user IDs
      await _loadUserNames(historyList);

      setState(() {
        _historyRecords = historyList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load sales history: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserNames(List<SalesHistory> historyList) async {
    try {
      // Get unique user IDs that we don't have cached yet
      final userIds = historyList
          .map((record) => record.changedBy)
          .where((userId) => userId.isNotEmpty && !_userNamesCache.containsKey(userId))
          .toSet()
          .toList();

      if (userIds.isEmpty) return;

      // Fetch user names one by one (safer approach)
      for (final userId in userIds) {
        try {
          final response = await Supabase.instance.client
              .from('users')
              .select('id, name, email')
              .eq('id', userId)
              .single();

          final name = response['name'] as String?;
          final email = response['email'] as String?;
          
          // Use name if available, otherwise use email prefix, otherwise use ID prefix
          _userNamesCache[userId] = name?.isNotEmpty == true 
              ? name!
              : email?.isNotEmpty == true 
                  ? email!.split('@').first
                  : 'User ${userId.substring(0, 8)}';
        } catch (e) {
          // If user not found or error, use fallback
          _userNamesCache[userId] = 'User ${userId.substring(0, 8)}';
        }
      }
    } catch (e) {
      print('Error loading user names: $e');
      // If there's an error, just use fallback names for all user IDs
      for (final record in historyList) {
        if (!_userNamesCache.containsKey(record.changedBy)) {
          _userNamesCache[record.changedBy] = 'User ${record.changedBy.substring(0, 8)}';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _userNamesCache.clear(); // Clear cache to refresh user names
              _loadSalesHistory();
            },
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSalesHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _historyRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No History Found',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This sale has no edit history yet.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Timeline Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timeline,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sales Activity Timeline',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Timeline List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _historyRecords.length,
                            itemBuilder: (context, index) {
                              final record = _historyRecords[index];
                              final isLast = index == _historyRecords.length - 1;
                              return _buildTimelineItem(record, isLast);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildTimelineItem(SalesHistory record, bool isLast) {
    final changeTypeColor = _getChangeTypeColor(record.changeType);
    final changeTypeIcon = _getChangeTypeIcon(record.changeType);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: changeTypeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: changeTypeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                changeTypeIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: changeTypeColor.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // Content card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: changeTypeColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with change type and time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: changeTypeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            record.changeType.displayName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(record.changedAt),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Field Changed
                    if (record.fieldChanged != null)
                      _buildDetailChip(
                        icon: Icons.edit_attributes,
                        label: 'Field Modified',
                        value: _formatFieldName(record.fieldChanged!),
                        color: Colors.blue,
                      ),
                    
                    // Changes
                    if (record.oldValue != null && record.newValue != null) ...[
                      const SizedBox(height: 8),
                      _buildEnhancedChangesSection(record.oldValue!, record.newValue!),
                    ],
                    
                    // Reason
                    if (record.reason != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailChip(
                        icon: Icons.comment,
                        label: 'Reason',
                        value: record.reason!,
                        color: Colors.orange,
                      ),
                    ],
                    
                    // Changed By
                    const SizedBox(height: 8),
                    _buildDetailChip(
                      icon: Icons.person,
                      label: 'Modified By',
                      value: _formatUserName(record.changedBy),
                      color: Colors.green,
                    ),
                    
                    // Metadata
                    if (record.metadata != null && record.metadata!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildMetadataSection(record.metadata!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: color,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedChangesSection(Map<String, dynamic> oldValue, Map<String, dynamic> newValue) {
    final changes = <Widget>[];
    
    // Compare all fields
    final allKeys = {...oldValue.keys, ...newValue.keys};
    
    for (final key in allKeys) {
      final oldVal = oldValue[key];
      final newVal = newValue[key];
      
      if (oldVal != newVal) {
        changes.add(_buildChangeItem(key, oldVal, newVal));
      }
    }
    
    if (changes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'No specific field changes recorded',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.compare_arrows, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 4),
            Text(
              'Changes Made:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...changes,
      ],
    );
  }

  Widget _buildChangeItem(String key, dynamic oldVal, dynamic newVal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field name
          Row(
            children: [
              Icon(Icons.label, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Text(
                _formatFieldName(key),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Before and After values
          Row(
            children: [
              // Old value
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.remove_circle, size: 12, color: Colors.red.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Before',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatValue(key, oldVal),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              
              // New value
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle, size: 12, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'After',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatValue(key, newVal),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(Map<String, dynamic> metadata) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Text(
                'Additional Information',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...metadata.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_formatFieldName(entry.key)}:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatValue(entry.key, entry.value),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : word)
        .join(' ');
  }

  String _formatValue(String fieldName, dynamic value) {
    if (value == null) return 'Not Set';
    
    // Format based on field type
    if (fieldName.toLowerCase().contains('price') || 
        fieldName.toLowerCase().contains('amount') ||
        fieldName.toLowerCase().contains('cost')) {
      final numValue = double.tryParse(value.toString());
      if (numValue != null) {
        return '₹${numValue.toStringAsFixed(2)}';
      }
    }
    
    if (fieldName.toLowerCase().contains('date') ||
        fieldName.toLowerCase().contains('time')) {
      final dateValue = DateTime.tryParse(value.toString());
      if (dateValue != null) {
        return _formatDateTime(dateValue);
      }
    }
    
    if (fieldName.toLowerCase().contains('phone')) {
      return value.toString().replaceAll(RegExp(r'(\d{3})(\d{3})(\d{4})'), '(\$1) \$2-\$3');
    }
    
    return value.toString();
  }

  String _formatUserName(String userId) {
    if (userId.isEmpty) return 'Unknown User';
    
    // Return cached user name if available
    if (_userNamesCache.containsKey(userId)) {
      return _userNamesCache[userId]!;
    }
    
    // Fallback to ID prefix if not in cache
    return 'User ${userId.substring(0, 8)}...';
  }

  Color _getChangeTypeColor(SalesChangeType changeType) {
    switch (changeType) {
      case SalesChangeType.created:
        return Colors.blue.shade600;
      case SalesChangeType.updated:
        return Colors.orange.shade600;
      case SalesChangeType.cancelled:
        return Colors.red.shade600;
      case SalesChangeType.refunded:
        return Colors.purple.shade600;
    }
  }

  IconData _getChangeTypeIcon(SalesChangeType changeType) {
    switch (changeType) {
      case SalesChangeType.created:
        return Icons.add_circle;
      case SalesChangeType.updated:
        return Icons.edit;
      case SalesChangeType.cancelled:
        return Icons.cancel;
      case SalesChangeType.refunded:
        return Icons.money_off;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dateTime.weekday - 1]} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
