import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sales_history.dart';
import '../../widgets/loading_widget.dart';
import 'sales_history_page.dart';

class EditSalePage extends StatefulWidget {
  final Sale sale;

  const EditSalePage({
    super.key,
    required this.sale,
  });

  @override
  State<EditSalePage> createState() => _EditSalePageState();
}

class _EditSalePageState extends State<EditSalePage> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _reasonController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingItems = true;
  String _paymentMethod = 'cash';
  String _status = 'completed';
  List<SaleItem> _saleItems = [];
  bool _itemsModified = false;
  
  final List<String> _paymentMethods = ['cash', 'card', 'upi'];
  final List<String> _statusOptions = ['completed', 'pending', 'cancelled', 'refunded'];

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadSaleItems();
  }

  void _initializeFields() {
    _customerNameController.text = widget.sale.customerName ?? '';
    _customerPhoneController.text = widget.sale.customerPhone ?? '';
    _notesController.text = widget.sale.notes ?? '';
    _paymentMethod = widget.sale.paymentMethod;
    _status = widget.sale.status;
  }

  Future<void> _loadSaleItems() async {
    setState(() => _isLoadingItems = true);
    
    try {
      if (AppConstants.enableSupabase) {
        final response = await Supabase.instance.client
            .from('sale_items')
            .select('''
              *,
              products!inner(name)
            ''')
            .eq('sale_id', widget.sale.id);

        final items = (response as List)
            .map((json) {
              // Ensure product name is available
              final productName = json['products']?['name'] ?? 
                                 json['product_name'] ?? 
                                 'Unknown Product';
              
              // Create a new map with the product name
              final updatedJson = Map<String, dynamic>.from(json);
              updatedJson['product_name'] = productName;
              
              return SaleItem.fromJson(updatedJson);
            })
            .toList();

        setState(() {
          _saleItems = items;
          _isLoadingItems = false;
        });
      } else {
        // Mock data for offline mode
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _saleItems = widget.sale.items ?? [
            SaleItem(
              id: '1',
              saleId: widget.sale.id,
              productId: 'prod_1',
              productName: 'Earl Grey Tea',
              quantity: 2.0,
              unitPrice: 150.0,
              totalPrice: 300.0,
              notes: 'Premium quality',
            ),
            SaleItem(
              id: '2',
              saleId: widget.sale.id,
              productId: 'prod_2',
              productName: 'Green Tea',
              quantity: 1.0,
              unitPrice: 120.0,
              totalPrice: 120.0,
            ),
            SaleItem(
              id: '3',
              saleId: widget.sale.id,
              productId: 'prod_3',
              productName: 'Masala Chai',
              quantity: 3.0,
              unitPrice: 80.0,
              totalPrice: 240.0,
              notes: 'Special blend',
            ),
          ];
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingItems = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sale items: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) {
      _showRemoveItemDialog(index);
      return;
    }

    setState(() {
      final item = _saleItems[index];
      final newTotalPrice = newQuantity * item.unitPrice;
      
      _saleItems[index] = item.copyWith(
        quantity: newQuantity,
        totalPrice: newTotalPrice,
      );
      _itemsModified = true;
    });
  }

  void _showRemoveItemDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Are you sure you want to remove "${_saleItems[index].productName}" from this sale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeItem(index);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _saleItems.removeAt(index);
      _itemsModified = true;
    });
  }

  double get _calculatedTotal {
    return _saleItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _updateSale() async {
    if (!_formKey.currentState!.validate()) return;

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for this change'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final oldSale = widget.sale;
      final now = DateTime.now();
      final uuid = const Uuid();

      // Create updated sale object
      final updatedSale = oldSale.copyWith(
        customerName: _customerNameController.text.isEmpty ? null : _customerNameController.text,
        customerPhone: _customerPhoneController.text.isEmpty ? null : _customerPhoneController.text,
        paymentMethod: _paymentMethod,
        status: _status,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        totalAmount: _itemsModified ? _calculatedTotal : oldSale.totalAmount,
      );

      if (AppConstants.enableSupabase) {
        // Update the sale - only send fields that should be updated
        await Supabase.instance.client
            .from('sales')
            .update({
              'customer_name': updatedSale.customerName,
              'customer_phone': updatedSale.customerPhone,
              'payment_method': updatedSale.paymentMethod,
              'status': updatedSale.status,
              'notes': updatedSale.notes,
              'total_amount': updatedSale.totalAmount,
            })
            .eq('id', widget.sale.id);

        // Update sale items if modified
        if (_itemsModified) {
          for (final item in _saleItems) {
            await Supabase.instance.client
                .from('sale_items')
                .update({
                  'quantity': item.quantity,
                  'total_price': item.totalPrice,
                })
                .eq('id', item.id);
          }
        }

        // Create audit history record
        final changedFields = _getChangedFieldsDescription(oldSale, updatedSale);
        final historyRecord = SalesHistory(
          id: uuid.v4(),
          saleId: widget.sale.id,
          changeType: SalesChangeType.updated,
          fieldChanged: changedFields,
          oldValue: {
            'customer_name': oldSale.customerName,
            'customer_phone': oldSale.customerPhone,
            'payment_method': oldSale.paymentMethod,
            'status': oldSale.status,
            'notes': oldSale.notes,
            'total_amount': oldSale.totalAmount,
          },
          newValue: {
            'customer_name': updatedSale.customerName,
            'customer_phone': updatedSale.customerPhone,
            'payment_method': updatedSale.paymentMethod,
            'status': updatedSale.status,
            'notes': updatedSale.notes,
            'total_amount': updatedSale.totalAmount,
          },
          reason: _reasonController.text,
          changedBy: Supabase.instance.client.auth.currentUser?.id ?? 'unknown',
          changedAt: now,
          metadata: _itemsModified ? {
            'items_count': _saleItems.length,
            'total_quantity': _saleItems.fold<double>(0, (sum, item) => sum + item.quantity),
          } : null,
        );

        // Try to save history record
        try {
          await Supabase.instance.client
              .from(AppConstants.salesHistoryTable)
              .insert(historyRecord.toJson());
        } catch (historyError) {
          print('Warning: Could not save sales history: $historyError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale ${widget.sale.saleNumber} updated successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sale: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  String _getChangedFieldsDescription(Sale oldSale, Sale newSale) {
    List<String> changedFields = [];
    
    if (oldSale.customerName != newSale.customerName) {
      changedFields.add('customer_name');
    }
    if (oldSale.customerPhone != newSale.customerPhone) {
      changedFields.add('customer_phone');
    }
    if (oldSale.paymentMethod != newSale.paymentMethod) {
      changedFields.add('payment_method');
    }
    if (oldSale.status != newSale.status) {
      changedFields.add('status');
    }
    if (oldSale.notes != newSale.notes) {
      changedFields.add('notes');
    }
    if (oldSale.totalAmount != newSale.totalAmount) {
      changedFields.add('total_amount');
    }
    if (_itemsModified) {
      changedFields.add('sale_items');
    }
    
    return changedFields.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Edit Sale ${widget.sale.saleNumber}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SalesHistoryPage(saleId: widget.sale.id),
                ),
              );
            },
            tooltip: 'View Sale History',
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
                    // Sale Info Card (Read-only)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sale Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Sale Number:', widget.sale.saleNumber),
                            _buildInfoRow('Date:', widget.sale.saleDate.toString().split('.')[0]),
                            _buildInfoRow('Total Amount:', '₹${widget.sale.totalAmount.toStringAsFixed(2)}'),
                            _buildInfoRow('Created By:', widget.sale.createdBy),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sale Items Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sale Items',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            if (_isLoadingItems)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_saleItems.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'No items found for this sale',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: [
                                  // Items Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Product',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Quantity',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Unit Price',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Total',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Items List
                                  ...List.generate(_saleItems.length, (index) {
                                    final item = _saleItems[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(6),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productName.isNotEmpty 
                                                      ? item.productName 
                                                      : 'Product #${index + 1}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                if (item.notes != null && item.notes!.isNotEmpty)
                                                  Text(
                                                    item.notes!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // Decrease quantity button
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Colors.red.shade200),
                                                  ),
                                                  child: InkWell(
                                                    onTap: () => _updateItemQuantity(index, item.quantity - 1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Icon(
                                                        Icons.remove,
                                                        color: Colors.red.shade700,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                                                  ),
                                                  child: Text(
                                                    '${item.quantity}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryColor,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                // Increase quantity button
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Colors.green.shade200),
                                                  ),
                                                  child: InkWell(
                                                    onTap: () => _updateItemQuantity(index, item.quantity + 1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Icon(
                                                        Icons.add,
                                                        color: Colors.green.shade700,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '₹${item.unitPrice.toStringAsFixed(2)}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '₹${item.totalPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  
                                  // Items Summary
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _itemsModified 
                                          ? Colors.orange.shade50
                                          : AppTheme.primaryColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _itemsModified 
                                            ? Colors.orange.shade300
                                            : AppTheme.primaryColor.withOpacity(0.2)
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total Items: ${_saleItems.length}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Total Quantity: ${_saleItems.fold<double>(0, (sum, item) => sum + item.quantity)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_itemsModified) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: Colors.orange.shade700,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Items Modified',
                                                    style: TextStyle(
                                                      color: Colors.orange.shade700,
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                'New Total: ₹${_calculatedTotal.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Editable Fields
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editable Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Customer Name
                            TextFormField(
                              controller: _customerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Customer Phone
                            TextFormField(
                              controller: _customerPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Phone',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            
                            // Payment Method
                            DropdownButtonFormField<String>(
                              value: _paymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'Payment Method',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.payment),
                              ),
                              items: _paymentMethods.map((method) {
                                return DropdownMenuItem(
                                  value: method,
                                  child: Text(method.toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _paymentMethod = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Status
                            DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.flag),
                              ),
                              items: _statusOptions.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(status.toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _status = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Notes
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.note),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Reason for Change (Required)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reason for Change *',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please provide a detailed reason for editing this completed sale. This will be recorded in the audit history.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _reasonController,
                              decoration: const InputDecoration(
                                labelText: 'Reason for editing this sale',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.edit_note),
                                hintText: 'e.g., Customer requested phone number update, Payment method correction, etc.',
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Reason is required for audit purposes';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateSale,
                        icon: const Icon(Icons.save),
                        label: const Text('UPDATE SALE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
      padding: const EdgeInsets.only(bottom: 8),
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
}
