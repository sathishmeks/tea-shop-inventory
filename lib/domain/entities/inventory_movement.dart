import 'package:equatable/equatable.dart';

class InventoryMovement extends Equatable {
  final String id;
  final String productId;
  final String movementType; // 'in', 'out', 'adjustment', 'refill', 'sale', 'return'
  final double quantity;
  final String? referenceId;
  final String? referenceType; // 'sale', 'purchase', 'adjustment', 'refill'
  final String? notes;
  final DateTime createdAt;
  final String createdBy;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    this.referenceId,
    this.referenceType,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    return InventoryMovement(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      movementType: json['movement_type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'movement_type': movementType,
      'quantity': quantity,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Helper methods for different movement types
  static InventoryMovement createSaleMovement({
    required String id,
    required String productId,
    required double quantity,
    required String saleId,
    required String createdBy,
    String? notes,
  }) {
    return InventoryMovement(
      id: id,
      productId: productId,
      movementType: 'out',
      quantity: -quantity, // Negative for outgoing
      referenceId: saleId,
      referenceType: 'sale',
      notes: notes,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  static InventoryMovement createRefillMovement({
    required String id,
    required String productId,
    required double quantity,
    required String createdBy,
    String? notes,
  }) {
    return InventoryMovement(
      id: id,
      productId: productId,
      movementType: 'refill',
      quantity: quantity, // Positive for incoming
      referenceType: 'refill',
      notes: notes,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  static InventoryMovement createAdjustmentMovement({
    required String id,
    required String productId,
    required double quantity,
    required String createdBy,
    String? notes,
  }) {
    return InventoryMovement(
      id: id,
      productId: productId,
      movementType: 'adjustment',
      quantity: quantity,
      referenceType: 'adjustment',
      notes: notes,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        movementType,
        quantity,
        referenceId,
        referenceType,
        notes,
        createdAt,
        createdBy,
      ];
}
