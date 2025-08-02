import 'package:equatable/equatable.dart';

enum StockMovementType {
  restock,
  sale,
  adjustment,
  waste,
  return_,
}

class StockAudit extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final StockMovementType movementType;
  final int quantityBefore;
  final int quantityChange;
  final int quantityAfter;
  final String reason;
  final String? notes;
  final double? costPerUnit;
  final double? totalCost;
  final String? supplier;
  final String? invoiceNumber;
  final DateTime createdAt;
  final String createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;

  const StockAudit({
    required this.id,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantityBefore,
    required this.quantityChange,
    required this.quantityAfter,
    required this.reason,
    this.notes,
    this.costPerUnit,
    this.totalCost,
    this.supplier,
    this.invoiceNumber,
    required this.createdAt,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
  });

  bool get isApproved => approvedBy != null && approvedAt != null;
  
  String get movementTypeDisplayName {
    switch (movementType) {
      case StockMovementType.restock:
        return 'Restock';
      case StockMovementType.sale:
        return 'Sale';
      case StockMovementType.adjustment:
        return 'Adjustment';
      case StockMovementType.waste:
        return 'Waste/Loss';
      case StockMovementType.return_:
        return 'Return';
    }
  }

  factory StockAudit.fromJson(Map<String, dynamic> json) {
    return StockAudit(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      movementType: StockMovementType.values.firstWhere(
        (e) => e.name == json['movement_type'],
        orElse: () => StockMovementType.adjustment,
      ),
      quantityBefore: json['quantity_before'] as int,
      quantityChange: json['quantity_change'] as int,
      quantityAfter: json['quantity_after'] as int,
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
      costPerUnit: (json['cost_per_unit'] as num?)?.toDouble(),
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      supplier: json['supplier'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'movement_type': movementType.name,
      'quantity_before': quantityBefore,
      'quantity_change': quantityChange,
      'quantity_after': quantityAfter,
      'reason': reason,
      'notes': notes,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'supplier': supplier,
      'invoice_number': invoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }

  StockAudit copyWith({
    String? id,
    String? productId,
    String? productName,
    StockMovementType? movementType,
    int? quantityBefore,
    int? quantityChange,
    int? quantityAfter,
    String? reason,
    String? notes,
    double? costPerUnit,
    double? totalCost,
    String? supplier,
    String? invoiceNumber,
    DateTime? createdAt,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
  }) {
    return StockAudit(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      movementType: movementType ?? this.movementType,
      quantityBefore: quantityBefore ?? this.quantityBefore,
      quantityChange: quantityChange ?? this.quantityChange,
      quantityAfter: quantityAfter ?? this.quantityAfter,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      totalCost: totalCost ?? this.totalCost,
      supplier: supplier ?? this.supplier,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        movementType,
        quantityBefore,
        quantityChange,
        quantityAfter,
        reason,
        notes,
        costPerUnit,
        totalCost,
        supplier,
        invoiceNumber,
        createdAt,
        createdBy,
        approvedBy,
        approvedAt,
      ];
}
