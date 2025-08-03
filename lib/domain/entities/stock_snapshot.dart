import 'package:flutter/material.dart';

class StockSnapshot {
  final String id;
  final String sessionId;
  final String userId;
  final String snapshotType; // 'session_start' or 'session_end'
  final DateTime snapshotDate;
  final int totalProductsCount;
  final double totalStockValue;
  final DateTime createdAt;

  StockSnapshot({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.snapshotType,
    required this.snapshotDate,
    required this.totalProductsCount,
    required this.totalStockValue,
    required this.createdAt,
  });

  factory StockSnapshot.fromJson(Map<String, dynamic> json) {
    return StockSnapshot(
      id: json['id'] ?? '',
      sessionId: json['session_id'] ?? '',
      userId: json['user_id'] ?? '',
      snapshotType: json['snapshot_type'] ?? '',
      snapshotDate: json['snapshot_date'] != null 
          ? DateTime.parse(json['snapshot_date'])
          : DateTime.now(),
      totalProductsCount: json['total_products_count'] ?? 0,
      totalStockValue: (json['total_stock_value'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'snapshot_type': snapshotType,
      'snapshot_date': snapshotDate.toIso8601String(),
      'total_products_count': totalProductsCount,
      'total_stock_value': totalStockValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  StockSnapshot copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? snapshotType,
    DateTime? snapshotDate,
    int? totalProductsCount,
    double? totalStockValue,
    DateTime? createdAt,
  }) {
    return StockSnapshot(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      snapshotType: snapshotType ?? this.snapshotType,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      totalProductsCount: totalProductsCount ?? this.totalProductsCount,
      totalStockValue: totalStockValue ?? this.totalStockValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class StockSnapshotItem {
  final String id;
  final String snapshotId;
  final String productId;
  final String productName;
  final String? category;
  final String? unit;
  final double quantityRecorded;
  final double unitPrice;
  final double totalValue;
  final DateTime createdAt;

  StockSnapshotItem({
    required this.id,
    required this.snapshotId,
    required this.productId,
    required this.productName,
    this.category,
    this.unit,
    required this.quantityRecorded,
    required this.unitPrice,
    required this.totalValue,
    required this.createdAt,
  });

  factory StockSnapshotItem.fromJson(Map<String, dynamic> json) {
    return StockSnapshotItem(
      id: json['id'] ?? '',
      snapshotId: json['snapshot_id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      category: json['category'],
      unit: json['unit'],
      quantityRecorded: (json['quantity_recorded'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'snapshot_id': snapshotId,
      'product_id': productId,
      'product_name': productName,
      'category': category,
      'unit': unit,
      'quantity_recorded': quantityRecorded,
      'unit_price': unitPrice,
      'total_value': totalValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  StockSnapshotItem copyWith({
    String? id,
    String? snapshotId,
    String? productId,
    String? productName,
    String? category,
    String? unit,
    double? quantityRecorded,
    double? unitPrice,
    double? totalValue,
    DateTime? createdAt,
  }) {
    return StockSnapshotItem(
      id: id ?? this.id,
      snapshotId: snapshotId ?? this.snapshotId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      quantityRecorded: quantityRecorded ?? this.quantityRecorded,
      unitPrice: unitPrice ?? this.unitPrice,
      totalValue: totalValue ?? this.totalValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Helper class for stock verification results
class StockVerificationResult {
  final String productId;
  final String productName;
  final double startingQuantity;
  final double currentQuantity;
  final double soldQuantity;
  final double expectedQuantity;
  final double variance;
  final bool isAccurate;
  final String? discrepancyReason;

  StockVerificationResult({
    required this.productId,
    required this.productName,
    required this.startingQuantity,
    required this.currentQuantity,
    required this.soldQuantity,
    required this.expectedQuantity,
    required this.variance,
    required this.isAccurate,
    this.discrepancyReason,
  });

  bool get hasVariance => variance.abs() > 0.01; // Allow for small rounding differences

  String get statusText {
    if (isAccurate) return 'Accurate';
    if (variance > 0) return 'Excess Stock';
    return 'Stock Shortage';
  }

  Color get statusColor {
    if (isAccurate) return Colors.green;
    if (variance > 0) return Colors.blue;
    return Colors.red;
  }
}
