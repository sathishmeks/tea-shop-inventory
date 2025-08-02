import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String category;
  final double price;
  final double? costPrice;
  final int stockQuantity;
  final int minimumStock;
  final String unit;
  final String? supplier;
  final String? barcode;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    this.costPrice,
    required this.stockQuantity,
    this.minimumStock = 10,
    this.unit = 'kg',
    this.supplier,
    this.barcode,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.isActive = true,
  });

  bool get isLowStock => stockQuantity <= minimumStock;
  bool get isCriticalStock => stockQuantity <= (minimumStock * 0.5);
  bool get isOutOfStock => stockQuantity <= 0;

  String get stockStatus {
    if (isOutOfStock) return 'Out of Stock';
    if (isCriticalStock) return 'Critical';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? price,
    double? costPrice,
    int? stockQuantity,
    int? minimumStock,
    String? unit,
    String? supplier,
    String? barcode,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minimumStock: minimumStock ?? this.minimumStock,
      unit: unit ?? this.unit,
      supplier: supplier ?? this.supplier,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      price: (json['price'] as num).toDouble(),
      costPrice: json['cost_price'] != null ? (json['cost_price'] as num).toDouble() : null,
      stockQuantity: json['stock_quantity'],
      minimumStock: json['minimum_stock'] ?? 10,
      unit: json['unit'] ?? 'kg',
      supplier: json['supplier'],
      barcode: json['barcode'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      createdBy: json['created_by'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'cost_price': costPrice,
      'stock_quantity': stockQuantity,
      'minimum_stock': minimumStock,
      'unit': unit,
      'supplier': supplier,
      'barcode': barcode,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'is_active': isActive,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        category,
        price,
        costPrice,
        stockQuantity,
        minimumStock,
        unit,
        supplier,
        barcode,
        imageUrl,
        createdAt,
        updatedAt,
        createdBy,
        isActive,
      ];
}
