import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/stock_audit.dart';
import '../../widgets/loading_widget.dart';

class StockHistoryPage extends StatefulWidget {
  final String? productId;
  final String? productName;

  const StockHistoryPage({
    super.key,
    this.productId,
    this.productName,
  });

  @override
  State<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends State<StockHistoryPage> {
  List<StockAudit> _stockAudits = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  
  final List<String> _filters = [
    'All',
    'Restock',
    'Sale',
    'Adjustment',
    'Waste',
    'Return',
  ];

  @override
  void initState() {
    super.initState();
    _loadStockHistory();
  }

  Future<void> _loadStockHistory() async {
    setState(() => _isLoading = true);
    
    try {
      if (AppConstants.enableSupabase) {
        if (widget.productId != null) {
          final response = await Supabase.instance.client
              .from('stock_audits')
              .select()
              .eq('product_id', widget.productId!)
              .order('created_at', ascending: false);

          _stockAudits = (response as List)
              .map((json) => StockAudit.fromJson(json))
              .toList();
        } else {
          final response = await Supabase.instance.client
              .from('stock_audits')
              .select()
              .order('created_at', ascending: false);

          _stockAudits = (response as List)
              .map((json) => StockAudit.fromJson(json))
              .toList();
        }
      } else {
        // Mock data for offline mode
        _stockAudits = _getMockStockAudits();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stock history: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  List<StockAudit> _getMockStockAudits() {
    return [
      StockAudit(
        id: '1',
        productId: '1',
        productName: 'Earl Grey Tea',
        movementType: StockMovementType.restock,
        quantityBefore: 10,
        quantityChange: 50,
        quantityAfter: 60,
        reason: 'Low Stock Replenishment',
        notes: 'Emergency restock due to high demand',
        costPerUnit: 180.0,
        totalCost: 9000.0,
        supplier: 'Premium Tea Suppliers',
        invoiceNumber: 'INV-2024-001',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        createdBy: 'admin',
      ),
      StockAudit(
        id: '2',
        productId: '1',
        productName: 'Earl Grey Tea',
        movementType: StockMovementType.sale,
        quantityBefore: 60,
        quantityChange: -5,
        quantityAfter: 55,
        reason: 'Customer Purchase',
        notes: 'Sale to regular customer',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        createdBy: 'staff',
      ),
    ];
  }

  List<StockAudit> get _filteredAudits {
    if (_selectedFilter == 'All') return _stockAudits;
    
    return _stockAudits.where((audit) {
      switch (_selectedFilter) {
        case 'Restock':
          return audit.movementType == StockMovementType.restock;
        case 'Sale':
          return audit.movementType == StockMovementType.sale;
        case 'Adjustment':
          return audit.movementType == StockMovementType.adjustment;
        case 'Waste':
          return audit.movementType == StockMovementType.waste;
        case 'Return':
          return audit.movementType == StockMovementType.return_;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.productName != null 
            ? '${widget.productName} - Stock History'
            : 'Stock History'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStockHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: isSelected ? AppTheme.primaryColor : null,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Stock History List
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingWidget())
                : _filteredAudits.isEmpty
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
                              'No stock movements found',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Stock movements will appear here as they occur',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadStockHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAudits.length,
                          itemBuilder: (context, index) {
                            final audit = _filteredAudits[index];
                            return _buildAuditCard(audit);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(StockAudit audit) {
    final isPositive = audit.quantityChange > 0;
    final movementColor = isPositive ? AppTheme.successColor : AppTheme.errorColor;
    
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
                CircleAvatar(
                  backgroundColor: movementColor.withOpacity(0.1),
                  child: Icon(
                    _getMovementIcon(audit.movementType),
                    color: movementColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audit.movementTypeDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.productId == null)
                        Text(
                          audit.productName,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isPositive ? '+' : ''}${audit.quantityChange}',
                      style: TextStyle(
                        color: movementColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${audit.quantityBefore} → ${audit.quantityAfter}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Details
            Text(
              'Reason: ${audit.reason}',
              style: const TextStyle(fontSize: 14),
            ),
            
            if (audit.notes != null && audit.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Notes: ${audit.notes}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            
            if (audit.costPerUnit != null) ...[
              const SizedBox(height: 4),
              Text(
                'Cost: ₹${audit.costPerUnit!.toStringAsFixed(2)} per unit',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            
            if (audit.totalCost != null) ...[
              const SizedBox(height: 4),
              Text(
                'Total Cost: ₹${audit.totalCost!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            
            if (audit.supplier != null) ...[
              const SizedBox(height: 4),
              Text(
                'Supplier: ${audit.supplier}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            
            if (audit.invoiceNumber != null) ...[
              const SizedBox(height: 4),
              Text(
                'Invoice: ${audit.invoiceNumber}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'By: ${audit.createdBy}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  _formatDateTime(audit.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMovementIcon(StockMovementType type) {
    switch (type) {
      case StockMovementType.restock:
        return Icons.add_box;
      case StockMovementType.sale:
        return Icons.point_of_sale;
      case StockMovementType.adjustment:
        return Icons.tune;
      case StockMovementType.waste:
        return Icons.delete_outline;
      case StockMovementType.return_:
        return Icons.keyboard_return;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
