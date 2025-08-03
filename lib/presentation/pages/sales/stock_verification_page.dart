import 'package:flutter/material.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/stock_snapshot_service.dart';
import '../../../domain/entities/stock_snapshot.dart';
import '../../widgets/loading_widget.dart';

class StockVerificationPage extends StatefulWidget {
  final String sessionId;

  const StockVerificationPage({
    super.key,
    required this.sessionId,
  });

  @override
  State<StockVerificationPage> createState() => _StockVerificationPageState();
}

class _StockVerificationPageState extends State<StockVerificationPage> {
  List<StockVerificationResult> _verificationResults = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVerificationData();
  }

  Future<void> _loadVerificationData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get session snapshots to determine user ID
      final snapshots = await StockSnapshotService.getSessionSnapshots(widget.sessionId);
      if (snapshots.isEmpty) {
        throw Exception('No snapshots found for this session');
      }

      final userId = snapshots.first.userId;

      // Load verification results and summary
      final results = await StockSnapshotService.verifySessionStock(
        sessionId: widget.sessionId,
        userId: userId,
      );

      final summary = await StockSnapshotService.getVerificationSummary(widget.sessionId);

      setState(() {
        _verificationResults = results;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading verification data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Stock Verification'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerificationData,
            tooltip: 'Refresh',
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
                        onPressed: _loadVerificationData,
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
              : Column(
                  children: [
                    // Summary Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildSummarySection(),
                    ),
                    
                    // Results List
                    Expanded(
                      child: _verificationResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    size: 64,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Products to Verify',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No products were found for verification.',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _verificationResults.length,
                              itemBuilder: (context, index) {
                                final result = _verificationResults[index];
                                return _buildVerificationCard(result);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummarySection() {
    final accuracyPercent = (_summary['accuracy_percentage'] as double?) ?? 0.0;
    final totalProducts = _summary['total_products'] ?? 0;
    final accurateCount = _summary['accurate_count'] ?? 0;
    final discrepancyCount = _summary['discrepancy_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Verification Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Accuracy Overview
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                icon: Icons.inventory,
                label: 'Total Products',
                value: totalProducts.toString(),
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryItem(
                icon: Icons.check_circle,
                label: 'Accurate',
                value: '$accurateCount',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryItem(
                icon: Icons.warning,
                label: 'Discrepancies',
                value: '$discrepancyCount',
                color: discrepancyCount > 0 ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Accuracy Percentage
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overall Accuracy',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${accuracyPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accuracyPercent >= 95 ? Colors.green : 
                           accuracyPercent >= 80 ? Colors.orange : Colors.red,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: accuracyPercent / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                accuracyPercent >= 95 ? Colors.green : 
                accuracyPercent >= 80 ? Colors.orange : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
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
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(StockVerificationResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: result.statusColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: result.statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Stock Numbers
              Row(
                children: [
                  Expanded(
                    child: _buildStockItem(
                      'Starting',
                      result.startingQuantity,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStockItem(
                      'Sold',
                      result.soldQuantity,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStockItem(
                      'Expected',
                      result.expectedQuantity,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStockItem(
                      'Actual',
                      result.currentQuantity,
                      result.statusColor,
                    ),
                  ),
                ],
              ),
              
              // Variance if any
              if (result.hasVariance) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: result.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: result.statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        result.variance > 0 ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: result.statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Variance: ${result.variance > 0 ? '+' : ''}${result.variance.toStringAsFixed(2)} units',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: result.statusColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Discrepancy reason if any
              if (result.discrepancyReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.discrepancyReason!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockItem(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
