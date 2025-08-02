import 'package:equatable/equatable.dart';

enum SalesChangeType {
  created,
  updated,
  cancelled,
  refunded;

  String get displayName {
    switch (this) {
      case SalesChangeType.created:
        return 'Created';
      case SalesChangeType.updated:
        return 'Updated';
      case SalesChangeType.cancelled:
        return 'Cancelled';
      case SalesChangeType.refunded:
        return 'Refunded';
    }
  }
}

class SalesHistory extends Equatable {
  final String id;
  final String saleId;
  final SalesChangeType changeType;
  final String? fieldChanged;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? reason;
  final String changedBy;
  final DateTime changedAt;
  final Map<String, dynamic>? metadata;

  const SalesHistory({
    required this.id,
    required this.saleId,
    required this.changeType,
    this.fieldChanged,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.changedBy,
    required this.changedAt,
    this.metadata,
  });

  factory SalesHistory.fromJson(Map<String, dynamic> json) {
    return SalesHistory(
      id: json['id'] ?? '',
      saleId: json['sale_id'] ?? '',
      changeType: _parseChangeType(json['change_type']),
      fieldChanged: json['field_changed'],
      oldValue: json['old_value'] != null 
          ? Map<String, dynamic>.from(json['old_value'])
          : null,
      newValue: json['new_value'] != null 
          ? Map<String, dynamic>.from(json['new_value'])
          : null,
      reason: json['reason'],
      changedBy: json['changed_by'] ?? '',
      changedAt: DateTime.parse(json['changed_at'] ?? DateTime.now().toIso8601String()),
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_id': saleId,
      'change_type': changeType.name,
      'field_changed': fieldChanged,
      'old_value': oldValue,
      'new_value': newValue,
      'reason': reason,
      'changed_by': changedBy,
      'changed_at': changedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  static SalesChangeType _parseChangeType(String? type) {
    switch (type?.toLowerCase()) {
      case 'created':
        return SalesChangeType.created;
      case 'updated':
        return SalesChangeType.updated;
      case 'cancelled':
        return SalesChangeType.cancelled;
      case 'refunded':
        return SalesChangeType.refunded;
      default:
        return SalesChangeType.created;
    }
  }

  @override
  List<Object?> get props => [
        id,
        saleId,
        changeType,
        fieldChanged,
        oldValue,
        newValue,
        reason,
        changedBy,
        changedAt,
        metadata,
      ];

  @override
  String toString() {
    return 'SalesHistory(id: $id, saleId: $saleId, changeType: $changeType, changedBy: $changedBy, changedAt: $changedAt)';
  }
}
