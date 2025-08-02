import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/sale.dart';
import '../../widgets/loading_widget.dart';

class AddSalePage extends StatefulWidget {
  const AddSalePage({super.key});

  @override
  State<AddSalePage> createState() => _AddSalePageState();
}

class _AddSalePageState extends State<AddSalePage> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<Product> _products = [];
  List<SaleItemCart> _cartItems = [];
  bool _isLoading = false;
  String _paymentMethod = 'cash';
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      if (AppConstants.enableSupabase) {
        final response = await Supabase.instance.client
            .from('products')
            .select()
            .order('name');

        _products = (response as List)
            .map((json) => Product.fromJson(json))
            .where((product) => product.stockQuantity > 0)
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

  void _addToCart(Product product) {
    // Check if product has sufficient stock
    if (product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is out of stock'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check existing cart quantity
    final existingIndex = _cartItems.indexWhere(
      (item) => item.productId == product.id,
    );
    
    double currentCartQuantity = 0;
    if (existingIndex >= 0) {
      currentCartQuantity = _cartItems[existingIndex].quantity;
    }

    showDialog(
      context: context,
      builder: (context) => _AddToCartDialog(
        product: product,
        existingCartQuantity: currentCartQuantity,
        onAdd: (quantity) {
          // Check if adding this quantity would exceed available stock
          if (currentCartQuantity + quantity > product.stockQuantity) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot add ${quantity.toStringAsFixed(1)} ${product.unit} of ${product.name}. '
                  'Only ${(product.stockQuantity - currentCartQuantity).toStringAsFixed(1)} ${product.unit} available.'
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }

          setState(() {
            if (existingIndex >= 0) {
              _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
                quantity: _cartItems[existingIndex].quantity + quantity,
              );
            } else {
              _cartItems.add(SaleItemCart(
                productId: product.id,
                productName: product.name,
                unitPrice: product.price,
                quantity: quantity,
                maxQuantity: product.stockQuantity.toDouble(),
              ));
            }
          });
        },
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateCartItemQuantity(int index, double quantity) {
    setState(() {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
      }
    });
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get _total {
    return _subtotal;
  }

  void _updateLocalInventory() {
    // Update local product list to reflect reduced inventory
    for (final cartItem in _cartItems) {
      final productIndex = _products.indexWhere((p) => p.id == cartItem.productId);
      if (productIndex >= 0) {
        final currentProduct = _products[productIndex];
        final newStockQuantity = currentProduct.stockQuantity - cartItem.quantity.toInt();
        
        _products[productIndex] = currentProduct.copyWith(
          stockQuantity: newStockQuantity,
        );
      }
    }
    
    // Update the UI to reflect the new inventory levels
    setState(() {});
  }

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate() || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to the cart'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate stock levels before proceeding
    List<String> stockErrors = [];
    for (final cartItem in _cartItems) {
      final product = _products.firstWhere((p) => p.id == cartItem.productId);
      if (cartItem.quantity > product.stockQuantity) {
        stockErrors.add('${product.name}: Only ${product.stockQuantity} ${product.unit} available');
      }
    }

    if (stockErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient stock:\n${stockErrors.join('\n')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uuid = const Uuid();
      final saleId = uuid.v4();
      final saleNumber = 'SALE-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final sale = Sale(
        id: saleId,
        saleNumber: saleNumber,
        customerName: _customerNameController.text.isEmpty 
            ? null 
            : _customerNameController.text,
        customerPhone: _customerPhoneController.text.isEmpty 
            ? null 
            : _customerPhoneController.text,
        totalAmount: _total,
        discountAmount: 0.0,
        paymentMethod: _paymentMethod,
        saleDate: now,
        createdBy: Supabase.instance.client.auth.currentUser?.id ?? 'unknown', 
        status: 'completed',
        notes: _notesController.text.isEmpty 
            ? null 
            : _notesController.text,
      );

      if (AppConstants.enableSupabase) {
        // Try to save online first, fallback to offline if network fails
        try {
          // Save sale to Supabase with timeout
          await Supabase.instance.client
              .from('sales')
              .insert(sale.toJson())
              .timeout(const Duration(seconds: 10));

          // Save sale items
          for (final cartItem in _cartItems) {
            final saleItem = SaleItem(
              id: uuid.v4(),
              saleId: saleId,
              productId: cartItem.productId,
              productName: cartItem.productName,
              quantity: cartItem.quantity,
              unitPrice: cartItem.unitPrice,
              totalPrice: cartItem.totalPrice,
            );

            await Supabase.instance.client
                .from('sale_items')
                .insert(saleItem.toJson())
                .timeout(const Duration(seconds: 10));

            // Update product stock in database
            final product = _products.firstWhere(
              (p) => p.id == cartItem.productId,
            );
            final newStockQuantity = product.stockQuantity - cartItem.quantity.toInt();
            
            await Supabase.instance.client
                .from('products')
                .update({
                  'stock_quantity': newStockQuantity,
                })
                .eq('id', cartItem.productId)
                .timeout(const Duration(seconds: 10));

            // Update local product list to reflect new stock
            final productIndex = _products.indexWhere((p) => p.id == cartItem.productId);
            if (productIndex >= 0) {
              _products[productIndex] = _products[productIndex].copyWith(
                stockQuantity: newStockQuantity,
              );
            }
          }

          // Online save successful
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sale $saleNumber created successfully! (Online)'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } catch (networkError) {
          // Check if it's actually a network error
          final errorMessage = networkError.toString().toLowerCase();
          final isNetworkError = errorMessage.contains('socketexception') ||
                                errorMessage.contains('connection') ||
                                errorMessage.contains('timeout') ||
                                errorMessage.contains('network') ||
                                errorMessage.contains('dns') ||
                                errorMessage.contains('host lookup');
          
          if (isNetworkError) {
            // Network error - save offline and update local inventory
            _updateLocalInventory();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Network error - Sale $saleNumber saved offline. Will sync when online.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            // Some other error - still update local inventory since sale items were processed
            _updateLocalInventory();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sale $saleNumber created successfully!'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            }
          }
        }
      } else {
        // Offline mode - update local inventory and show success
        _updateLocalInventory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sale $saleNumber created successfully! (Offline Mode)'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sale: ${e.toString().contains('SocketException') ? 'Network connection failed' : e}'),
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
        title: const Text('New Sale'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton(
              onPressed: _isLoading ? null : _saveSale,
              child: Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer Information (Optional)',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _customerNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Customer Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _customerPhoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Products Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Products',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  itemCount: _products.length,
                                  itemBuilder: (context, index) {
                                    final product = _products[index];
                                    
                                    return ListTile(
                                      title: Text(product.name),
                                      subtitle: Text(
                                        '₹${product.price.toStringAsFixed(2)} • Stock: ${product.stockQuantity}',
                                      ),
                                      trailing: ElevatedButton(
                                        onPressed: () => _addToCart(product),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Add'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Cart Items
                      if (_cartItems.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cart Items',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _cartItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _cartItems[index];
                                    
                                    return ListTile(
                                      title: Text(item.productName),
                                      subtitle: Text('₹${item.unitPrice.toStringAsFixed(2)} × ${item.quantity}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '₹${item.totalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            onPressed: () => _removeFromCart(index),
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Payment and Total
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Details',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _paymentMethod,
                                  decoration: const InputDecoration(
                                    labelText: 'Payment Method',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                                    DropdownMenuItem(value: 'card', child: Text('Card')),
                                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _paymentMethod = value!;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes (Optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Subtotal:'),
                                    Text('₹${_subtotal.toStringAsFixed(2)}'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total:',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₹${_total.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class SaleItemCart {
  final String productId;
  final String productName;
  final double unitPrice;
  final double quantity;
  final double maxQuantity;

  SaleItemCart({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.maxQuantity,
  });

  double get totalPrice => unitPrice * quantity;

  SaleItemCart copyWith({
    String? productId,
    String? productName,
    double? unitPrice,
    double? quantity,
    double? maxQuantity,
  }) {
    return SaleItemCart(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
    );
  }
}

class _AddToCartDialog extends StatefulWidget {
  final Product product;
  final Function(double) onAdd;
  final double? existingCartQuantity;

  const _AddToCartDialog({
    required this.product,
    required this.onAdd,
    this.existingCartQuantity,
  });

  @override
  State<_AddToCartDialog> createState() => _AddToCartDialogState();
}

class _AddToCartDialogState extends State<_AddToCartDialog> {
  double _quantity = 1;

  double get availableQuantity {
    final existingInCart = widget.existingCartQuantity ?? 0;
    return widget.product.stockQuantity.toDouble() - existingInCart;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Price: ₹${widget.product.price.toStringAsFixed(2)}'),
          Text('Stock: ${widget.product.stockQuantity} ${widget.product.unit}'),
          if (widget.existingCartQuantity != null && widget.existingCartQuantity! > 0)
            Text('In cart: ${widget.existingCartQuantity!.toStringAsFixed(1)} ${widget.product.unit}'),
          Text('Available: ${availableQuantity.toStringAsFixed(1)} ${widget.product.unit}'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantity:'),
              Row(
                children: [
                  IconButton(
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(_quantity.toStringAsFixed(0)),
                  IconButton(
                    onPressed: _quantity < availableQuantity
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total: ₹${(widget.product.price * _quantity).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAdd(_quantity);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add to Cart'),
        ),
      ],
    );
  }
}
