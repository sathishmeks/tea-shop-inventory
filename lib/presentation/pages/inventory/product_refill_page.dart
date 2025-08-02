import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/stock_monitoring_service.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/inventory_movement.dart';
import '../../widgets/loading_widget.dart';

class ProductRefillPage extends StatefulWidget {
  final Product? preSelectedProduct;
  
  const ProductRefillPage({
    super.key,
    this.preSelectedProduct,
  });

  @override
  State<ProductRefillPage> createState() => _ProductRefillPageState();
}

class _ProductRefillPageState extends State<ProductRefillPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<Product> _products = [];
  Product? _selectedProduct;
  String? _selectedMovementType;
  bool _isLoading = false;
  bool _isSubmitting = false;
  
  // Available movement types with descriptions
  final Map<String, String> _movementTypes = {
    'refill': 'Refill',
    'in': 'Stock In',
    'adjustment': 'Adjustment',
    'return': 'Return',
  };
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
    
    // Set pre-selected product if provided
    if (widget.preSelectedProduct != null) {
      _selectedProduct = widget.preSelectedProduct;
    }
    
    // Set default movement type
    _selectedMovementType = 'refill';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      if (AppConstants.enableSupabase) {
        final response = await Supabase.instance.client
            .from(AppConstants.productsTable)
            .select()
            .eq('is_active', true)
            .order('name');

        _products = (response as List)
            .map((json) => Product.fromJson(json))
            .toList();
      } else {
        // Mock data for offline mode
        await Future.delayed(const Duration(seconds: 1));
        _products = _getMockProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  List<Product> _getMockProducts() {
    return [
      Product(
        id: '1',
        name: 'Earl Grey Tea',
        category: 'Black Tea',
        price: 250.0,
        costPrice: 150.0,
        stockQuantity: 50,
        unit: 'packet',
        description: 'Premium Earl Grey tea',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: '2',
        name: 'Green Tea',
        category: 'Green Tea',
        price: 200.0,
        costPrice: 120.0,
        stockQuantity: 30,
        unit: 'packet',
        description: 'Organic green tea',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Future<void> _submitRefill() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null || _selectedMovementType == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final quantity = double.parse(_quantityController.text);
      final uuid = const Uuid();
      
      if (AppConstants.enableSupabase) {
        // Create inventory movement record based on selected type
        InventoryMovement inventoryMovement;
        
        switch (_selectedMovementType!) {
          case 'refill':
            inventoryMovement = InventoryMovement.createRefillMovement(
              id: uuid.v4(),
              productId: _selectedProduct!.id,
              quantity: quantity,
              createdBy: user.id,
              notes: _notesController.text.isNotEmpty ? _notesController.text : null,
            );
            break;
          case 'adjustment':
            inventoryMovement = InventoryMovement.createAdjustmentMovement(
              id: uuid.v4(),
              productId: _selectedProduct!.id,
              quantity: quantity,
              createdBy: user.id,
              notes: _notesController.text.isNotEmpty ? _notesController.text : null,
            );
            break;
          default:
            // For 'in' and 'return' types, create manually
            inventoryMovement = InventoryMovement(
              id: uuid.v4(),
              productId: _selectedProduct!.id,
              movementType: _selectedMovementType!,
              quantity: quantity,
              referenceType: _selectedMovementType,
              notes: _notesController.text.isNotEmpty ? _notesController.text : null,
              createdAt: DateTime.now(),
              createdBy: user.id,
            );
        }

        print('Attempting to insert inventory movement: ${inventoryMovement.toJson()}');
        print('Movement type: "${inventoryMovement.movementType}"');
        print('Reference type: "${inventoryMovement.referenceType}"');

        try {
          // Insert inventory movement
          await Supabase.instance.client
              .from(AppConstants.inventoryMovementsTable)
              .insert(inventoryMovement.toJson());
          
          print('Inventory movement inserted successfully');
        } catch (inventoryError) {
          print('Error inserting inventory movement: $inventoryError');
          // Show warning but continue with stock update
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Warning: Could not log inventory movement. Stock will still be updated.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        // Update product stock quantity
        final newStockQuantity = _selectedProduct!.stockQuantity + quantity.toInt();
        await Supabase.instance.client
            .from(AppConstants.productsTable)
            .update({
              'stock_quantity': newStockQuantity,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _selectedProduct!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully processed ${_movementTypes[_selectedMovementType]?.toLowerCase()} for ${_selectedProduct!.name} with $quantity ${_selectedProduct!.unit}(s)',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          // Notify stock monitoring service about the update
          final newStockQuantity = _selectedProduct!.stockQuantity + quantity.toInt();
          await StockMonitoringService().onStockUpdated(
            _selectedProduct!.id,
            newStockQuantity,
            _selectedProduct!.minimumStock,
          );
          
          // Navigate back to previous page (typically inventory page)
          Navigator.of(context).pop();
        }
      } else {
        // Mock success for offline mode
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stock movement recorded successfully (offline mode)'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          // Navigate back to previous page (typically inventory page)
          Navigator.of(context).pop();
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing refill: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.preSelectedProduct != null 
              ? 'Inventory - ${widget.preSelectedProduct!.name}'
              : 'Inventory Movement'
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
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
                    // Info Card
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700]),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inventory Movement',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Record different types of inventory movements including refills, adjustments, returns, and general stock changes.',
                                    style: TextStyle(color: Colors.blue[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Movement Type Selection
                    Text(
                      'Movement Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedMovementType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select movement type',
                      ),
                      items: _movementTypes.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedMovementType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a movement type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Product Selection
                    Text(
                      'Select Product',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Product>(
                      value: _selectedProduct,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Choose a product to refill',
                      ),
                      items: _products.map((product) {
                        return DropdownMenuItem<Product>(
                          value: product,
                          child: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Product? value) {
                        setState(() {
                          _selectedProduct = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a product';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Current Stock Info
                    if (_selectedProduct != null) ...[
                      Card(
                        color: (_selectedProduct?.isLowStock ?? false)
                            ? Colors.orange[50] 
                            : Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                (_selectedProduct?.isLowStock ?? false)
                                    ? Icons.warning 
                                    : Icons.check_circle,
                                color: (_selectedProduct?.isLowStock ?? false)
                                    ? Colors.orange[700] 
                                    : Colors.green[700],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Current Stock Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: (_selectedProduct?.isLowStock ?? false)
                                            ? Colors.orange[700] 
                                            : Colors.green[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Stock: ${_selectedProduct?.stockQuantity ?? 0} ${_selectedProduct?.unit ?? 'units'}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Status: ${_selectedProduct?.stockStatus ?? 'Unknown'}',
                                      style: TextStyle(
                                        color: (_selectedProduct?.isLowStock ?? false)
                                            ? Colors.orange[600] 
                                            : Colors.green[600],
                                      ),
                                    ),
                                    Text(
                                      'Min: ${_selectedProduct?.minimumStock ?? 0} ${_selectedProduct?.unit ?? 'units'}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Refill Quantity
                    Text(
                      'Quantity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Quantity',
                        hintText: 'Enter quantity for movement',
                        suffixText: _selectedProduct?.unit,
                        helperText: _selectedMovementType == 'adjustment' 
                            ? 'Use positive for increase, negative for decrease'
                            : 'Positive quantity will increase stock',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        final quantity = double.tryParse(value);
                        if (quantity == null) {
                          return 'Please enter a valid number';
                        }
                        if (_selectedMovementType != 'adjustment' && quantity <= 0) {
                          return 'Please enter a positive quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Notes
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Notes (Optional)',
                        hintText: _selectedMovementType == 'refill' 
                            ? 'Enter supplier info, batch number, etc.'
                            : _selectedMovementType == 'adjustment'
                                ? 'Enter reason for adjustment'
                                : _selectedMovementType == 'return'
                                    ? 'Enter return reason'
                                    : 'Enter movement details',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRefill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Process ${_selectedMovementType == 'refill' ? 'Refill' : _selectedMovementType == 'adjustment' ? 'Adjustment' : _selectedMovementType == 'return' ? 'Return' : 'Movement'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
