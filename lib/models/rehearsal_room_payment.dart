import 'package:cloud_firestore/cloud_firestore.dart';

class RehearsalRoomPayment {
  const RehearsalRoomPayment({
    required this.year,
    required this.month,
    required this.amount,
    required this.isPaid,
    required this.movementId,
    required this.createdBy,
    this.paidAt,
  });

  final int year;
  final int month;
  final double amount;
  final bool isPaid;
  final DateTime? paidAt;
  final String movementId;
  final String? createdBy;

  String get id => '${year}_${month.toString().padLeft(2, '0')}';

  factory RehearsalRoomPayment.fromMap(Map<String, dynamic> map) {
    final status = map['status'] as String?;
    return RehearsalRoomPayment(
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (map['month'] as num?)?.toInt() ?? 1,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      isPaid: status == 'paid' || map['isPaid'] == true,
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      movementId: map['movementId'] as String? ?? '',
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'year': year,
        'month': month,
        'amount': amount,
        'status': isPaid ? 'paid' : 'pending',
        'movementId': movementId,
        'createdBy': createdBy,
      };
}
