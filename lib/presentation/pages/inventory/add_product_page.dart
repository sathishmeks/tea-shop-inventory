import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validation_utils.dart';
import '../../../domain/entities/product.dart';
import '../../widgets/loading_widget.dart';

class AddProductPage extends StatefulWidget {
  final Product? product;

  const AddProductPage({super.key, this.product});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _supplierController = TextEditingController();
  final _barcodeController = TextEditingController();

  String _selectedCategory = 'Drinks';
  String _selectedUnit = 'bottle';
  bool _isLoading = false;

  final List<String> _categories = [
    'Drinks',
    'Snacks',
    'Black Tea',
    'Green Tea',
    'Herbal Tea',
    'Spiced Tea',
    'Oolong Tea',
    'White Tea',
    'Flavored Tea',
  ];

  final List<String> _units = ['bottle', 'cup', 'packet', 'piece', 'kg', 'g', 'boxes'];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toString();
    _costPriceController.text = product.costPrice?.toString() ?? '';
    _stockController.text = product.stockQuantity.toString();
    _minStockController.text = product.minimumStock.toString();
    _supplierController.text = product.supplier ?? '';
    _barcodeController.text = product.barcode ?? '';
    _selectedCategory = product.category;
    _selectedUnit = product.unit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _supplierController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'category': _selectedCategory,
        'price': double.parse(_priceController.text),
        'cost_price': _costPriceController.text.isEmpty 
            ? null 
            : double.parse(_costPriceController.text),
        'stock_quantity': int.parse(_stockController.text),
        'minimum_stock': int.parse(_minStockController.text),
        'unit': _selectedUnit,
        'supplier': _supplierController.text.trim().isEmpty 
            ? null 
            : _supplierController.text.trim(),
        'barcode': _barcodeController.text.trim().isEmpty 
            ? null 
            : _barcodeController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (AppConstants.enableSupabase) {
        if (widget.product != null) {
          // Update existing product
          await Supabase.instance.client
              .from('products')
              .update(productData)
              .eq('id', widget.product!.id);
        } else {
          // Create new product
          productData['created_by'] = Supabase.instance.client.auth.currentUser?.id;
          await Supabase.instance.client
              .from('products')
              .insert(productData);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product != null 
                  ? 'Product updated successfully' 
                  : 'Product added successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingWidget(color: Colors.white, size: 20),
            )
          else
            TextButton(
              onPressed: _saveProduct,
              child: Text(
                isEditing ? 'UPDATE' : 'SAVE',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'Enter product name',
                  prefixIcon: Icon(Icons.local_cafe),
                ),
                validator: (value) => ValidationUtils.validateRequired(value, 'Product Name'),
              ),
              
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter product description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 16),
              
              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Price and Cost Price Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Selling Price *',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: ValidationUtils.validatePrice,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Cost Price',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Stock and Min Stock Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Current Stock *',
                        hintText: '0',
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => ValidationUtils.validateRequired(value, 'Current Stock'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Stock',
                        hintText: '10',
                        prefixIcon: Icon(Icons.warning),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Unit
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit *',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: _units.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value!;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Supplier
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  hintText: 'Enter supplier name',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Barcode
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  hintText: 'Enter barcode',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const LoadingWidget(color: Colors.white, size: 20)
                    : Text(
                        isEditing ? 'Update Product' : 'Add Product',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
