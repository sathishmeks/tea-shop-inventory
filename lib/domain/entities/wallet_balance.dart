import 'package:hive/hive.dart';

@HiveType(typeId: 6)
class WalletBalance extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final double openingBalance;

  @HiveField(4)
  final double? closingBalance;

  @HiveField(5)
  final String status; // 'opened', 'closed'

  @HiveField(6)
  final String? notes;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime? updatedAt;

  WalletBalance({
    required this.id,
    required this.userId,
    required this.date,
    required this.openingBalance,
    this.closingBalance,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      openingBalance: (json['opening_balance'] as num).toDouble(),
      closingBalance: json['closing_balance'] != null 
          ? (json['closing_balance'] as num).toDouble() 
          : null,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0], // Date only
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  WalletBalance copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? openingBalance,
    double? closingBalance,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletBalance(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get difference => (closingBalance ?? 0.0) - openingBalance;

  bool get isBalanced => closingBalance != null && (difference.abs() < 0.01);

  @override
  String toString() {
    return 'WalletBalance(id: $id, userId: $userId, date: $date, '
           'opening: $openingBalance, closing: $closingBalance, status: $status)';
  }
}
