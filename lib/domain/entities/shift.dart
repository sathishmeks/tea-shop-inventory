class Shift {
  final String id;
  final String userId;
  final String userName;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // active, completed, cancelled
  final double? totalSales;
  final int? totalTransactions;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Shift({
    required this.id,
    required this.userId,
    required this.userName,
    required this.startTime,
    this.endTime,
    this.status = 'active',
    this.totalSales,
    this.totalTransactions,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      startTime: DateTime.parse(json['start_time'] ?? DateTime.now().toIso8601String()),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time'])
          : null,
      status: json['status'] ?? 'active',
      totalSales: (json['total_sales'] as num?)?.toDouble(),
      totalTransactions: json['total_transactions'],
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
      'user_id': userId,
      'user_name': userName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
      'total_sales': totalSales,
      'total_transactions': totalTransactions,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    } else if (status == 'active') {
      return DateTime.now().difference(startTime);
    }
    return null;
  }

  String get formattedDuration {
    final dur = duration;
    if (dur == null) return 'N/A';
    
    final hours = dur.inHours;
    final minutes = dur.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Shift copyWith({
    String? id,
    String? userId,
    String? userName,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    double? totalSales,
    int? totalTransactions,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shift(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      totalSales: totalSales ?? this.totalSales,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Shift(id: $id, userName: $userName, status: $status, duration: $formattedDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Shift && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
