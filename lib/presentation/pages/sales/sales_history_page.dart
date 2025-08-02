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
          .from('sales_history')
          .select()
          .eq('sale_id', widget.saleId)
          .order('changed_at', ascending: false);

      final historyList = (response as List)
          .map((item) => SalesHistory.fromJson(item))
          .toList();

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
            onPressed: _loadSalesHistory,
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _historyRecords.length,
                      itemBuilder: (context, index) {
                        final record = _historyRecords[index];
                        return _buildHistoryCard(record);
                      },
                    ),
    );
  }

  Widget _buildHistoryCard(SalesHistory record) {
    final changeTypeColor = _getChangeTypeColor(record.changeType);
    final changeTypeIcon = _getChangeTypeIcon(record.changeType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: changeTypeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: changeTypeColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        changeTypeIcon,
                        size: 16,
                        color: changeTypeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.changeType.displayName.toUpperCase(),
                        style: TextStyle(
                          color: changeTypeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(record.changedAt),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Field Changed
            if (record.fieldChanged != null)
              _buildInfoRow('Field Changed:', record.fieldChanged!),
            
            // Changes
            if (record.oldValue != null && record.newValue != null)
              _buildChangesSection(record.oldValue!, record.newValue!),
            
            // Reason
            if (record.reason != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Reason:', record.reason!),
            ],
            
            // Changed By
            const SizedBox(height: 8),
            _buildInfoRow('Changed By:', record.changedBy),
            
            // Metadata
            if (record.metadata != null && record.metadata!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Additional Info:', record.metadata.toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangesSection(Map<String, dynamic> oldValue, Map<String, dynamic> newValue) {
    final changes = <Widget>[];
    
    // Compare all fields
    final allKeys = {...oldValue.keys, ...newValue.keys};
    
    for (final key in allKeys) {
      final oldVal = oldValue[key]?.toString() ?? 'null';
      final newVal = newValue[key]?.toString() ?? 'null';
      
      if (oldVal != newVal) {
        changes.add(
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'From: $oldVal',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'To: $newVal',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }
    
    if (changes.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'No specific field changes recorded',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Changes:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        ...changes,
      ],
    );
  }

  Color _getChangeTypeColor(SalesChangeType changeType) {
    switch (changeType) {
      case SalesChangeType.created:
        return Colors.blue;
      case SalesChangeType.updated:
        return Colors.orange;
      case SalesChangeType.cancelled:
        return Colors.red;
      case SalesChangeType.refunded:
        return Colors.purple;
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
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
