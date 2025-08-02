class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double? discountAmount;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountAmount,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] ?? '',
      saleId: json['sale_id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      notes: json['notes'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'discount_amount': discountAmount,
      // Don't include product_name, notes, created_at, updated_at as they don't exist in the sale_items table schema
    };
  }

  SaleItem copyWith({
    String? id,
    String? saleId,
    String? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    double? discountAmount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SaleItem(id: $id, productName: $productName, quantity: $quantity, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class Sale {
  final String id;
  final String saleNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double totalAmount;
  final double discountAmount;
  final double taxAmount;
  final String paymentMethod; // cash, card, upi, etc.
  final DateTime saleDate;
  final String createdBy;
  final String status; // pending, completed, cancelled, refunded
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SaleItem>? items;

  Sale({
    required this.id,
    required this.saleNumber,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    required this.paymentMethod,
    required this.saleDate,
    required this.createdBy,
    this.status = 'pending',
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] ?? '',
      saleNumber: json['sale_number'] ?? '',
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      customerEmail: json['customer_email'],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] ?? 'cash',
      saleDate: DateTime.parse(json['sale_date'] ?? DateTime.now().toIso8601String()),
      createdBy: json['created_by'] ?? '',
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_number': saleNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'payment_method': paymentMethod,
      'sale_date': saleDate.toIso8601String(),
      'created_by': createdBy,
      'status': status,
      'notes': notes,
      // Don't include created_at and updated_at as they don't exist in the database schema
    };
  }

  Sale copyWith({
    String? id,
    String? saleNumber,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    double? totalAmount,
    double? discountAmount,
    double? taxAmount,
    String? paymentMethod,
    DateTime? saleDate,
    String? createdBy,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      saleNumber: saleNumber ?? this.saleNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      saleDate: saleDate ?? this.saleDate,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  String toString() {
    return 'Sale(id: $id, saleNumber: $saleNumber, customerName: $customerName, totalAmount: $totalAmount, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sale && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
