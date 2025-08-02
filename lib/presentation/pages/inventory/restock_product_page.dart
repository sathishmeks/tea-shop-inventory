import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/stock_audit.dart';
import '../../widgets/loading_widget.dart';
import 'stock_history_page.dart';

class RestockProductPage extends StatefulWidget {
  final Product product;

  const RestockProductPage({
    super.key,
    required this.product,
  });

  @override
  State<RestockProductPage> createState() => _RestockProductPageState();
}

class _RestockProductPageState extends State<RestockProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _restockQuantityController = TextEditingController();
  final _supplierController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedReason = 'Low Stock Replenishment';
  
  final List<String> _restockReasons = [
    'Low Stock Replenishment',
    'New Stock Arrival',
    'Emergency Restock',
    'Seasonal Stock Up',
    'Bulk Purchase',
    'Supplier Delivery',
    'Stock Adjustment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _supplierController.text = widget.product.supplier ?? '';
  }

  @override
  void dispose() {
    _restockQuantityController.dispose();
    _supplierController.dispose();
    _invoiceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRestock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final restockQuantity = int.parse(_restockQuantityController.text);
      final newStockQuantity = widget.product.stockQuantity + restockQuantity;

      if (AppConstants.enableSupabase) {
        try {
          // Create stock audit record
          final stockAudit = StockAudit(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            productId: widget.product.id,
            productName: widget.product.name,
            movementType: StockMovementType.restock,
            quantityBefore: widget.product.stockQuantity,
            quantityChange: restockQuantity,
            quantityAfter: newStockQuantity,
            reason: _selectedReason,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            supplier: _supplierController.text.isEmpty ? null : _supplierController.text,
            invoiceNumber: _invoiceNumberController.text.isEmpty ? null : _invoiceNumberController.text,
            createdAt: DateTime.now(),
            createdBy: 'current_user', // TODO: Get from auth
          );

          // Try to insert audit record (skip if table doesn't exist)
          try {
            await Supabase.instance.client
                .from('stock_audits')
                .insert(stockAudit.toJson());
          } catch (auditError) {
            // Log audit error but continue with stock update
            print('Warning: Could not save stock audit - table may not exist: $auditError');
          }

          // Update product stock quantity
          await Supabase.instance.client
              .from('products')
              .update({
                'stock_quantity': newStockQuantity,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', widget.product.id);
        } catch (e) {
          rethrow; // Re-throw the error for main error handling
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully restocked ${widget.product.name}. '
              'Added $restockQuantity ${widget.product.unit}. '
              'New stock: $newStockQuantity ${widget.product.unit}',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restocking product: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Restock Product'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: Navigate to stock history page
              _showStockHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Product Name:', widget.product.name),
                            _buildInfoRow('Category:', widget.product.category),
                            _buildInfoRow('Current Stock:', '${widget.product.stockQuantity} ${widget.product.unit}'),
                            _buildInfoRow('Minimum Stock:', '${widget.product.minimumStock} ${widget.product.unit}'),
                            _buildInfoRow('Stock Status:', widget.product.stockStatus),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.product.isLowStock 
                                    ? AppTheme.errorColor.withOpacity(0.1)
                                    : AppTheme.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: widget.product.isLowStock 
                                      ? AppTheme.errorColor
                                      : AppTheme.successColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    widget.product.isLowStock 
                                        ? Icons.warning
                                        : Icons.check_circle,
                                    color: widget.product.isLowStock 
                                        ? AppTheme.errorColor
                                        : AppTheme.successColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.product.isLowStock
                                          ? 'This product needs restocking!'
                                          : 'Stock levels are adequate',
                                      style: TextStyle(
                                        color: widget.product.isLowStock 
                                            ? AppTheme.errorColor
                                            : AppTheme.successColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Restock Form
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restock Details',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Restock Quantity
                            TextFormField(
                              controller: _restockQuantityController,
                              decoration: InputDecoration(
                                labelText: 'Restock Quantity *',
                                suffixText: widget.product.unit,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.add_box),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter restock quantity';
                                }
                                final quantity = int.tryParse(value);
                                if (quantity == null || quantity <= 0) {
                                  return 'Please enter a valid quantity';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Reason for Restock
                            DropdownButtonFormField<String>(
                              value: _selectedReason,
                              decoration: const InputDecoration(
                                labelText: 'Reason for Restock *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                              items: _restockReasons.map((reason) {
                                return DropdownMenuItem(
                                  value: reason,
                                  child: Text(reason),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedReason = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Supplier
                            TextFormField(
                              controller: _supplierController,
                              decoration: const InputDecoration(
                                labelText: 'Supplier',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Invoice Number
                            TextFormField(
                              controller: _invoiceNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Invoice/Reference Number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.receipt),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Notes
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Additional Notes',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.note),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRestock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Confirm Restock',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showStockHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockHistoryPage(
          productId: widget.product.id,
          productName: widget.product.name,
        ),
      ),
    );
  }
}
