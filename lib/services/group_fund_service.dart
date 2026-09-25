import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/fund_constants.dart';
import '../models/rehearsal_room_payment.dart';

class FundMovement {
  const FundMovement({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.referenceId,
    required this.isReversed,
    this.reason,
    this.effectiveDate,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String type;
  final String category;
  final String description;
  final String referenceId;
  final bool isReversed;
  final String? reason;
  final DateTime? effectiveDate;
  final DateTime? createdAt;

  factory FundMovement.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return FundMovement(
      id: snapshot.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: data['type'] as String? ?? 'other',
      category: data['category'] as String? ?? 'other',
      description: data['description'] as String? ?? 'Movimiento del Fondo',
      referenceId: data['referenceId'] as String? ?? '',
      isReversed: data['isReversed'] as bool? ?? false,
      reason: data['reason'] as String?,
      effectiveDate: (data['effectiveDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class GroupFundService {
  GroupFundService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _fund =>
      _firestore.collection('group_finances').doc('fund');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _fund.collection('movements');
  CollectionReference<Map<String, dynamic>> get _roomPayments =>
      _fund.collection('rehearsal_room_payments');

  Stream<double> watchAvailableAmount() => _fund.snapshots().map(
        (snapshot) =>
            (snapshot.data()?['availableAmount'] as num?)?.toDouble() ?? 0,
      );

  Stream<List<FundMovement>> watchMovements() => _movements
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(FundMovement.fromFirestore)
          .toList(growable: false));

  Stream<Map<int, RehearsalRoomPayment>> watchRoomPayments(int year) =>
      _roomPayments.where('year', isEqualTo: year).snapshots().map((snapshot) {
        final payments = <int, RehearsalRoomPayment>{};
        for (final document in snapshot.docs) {
          final payment = RehearsalRoomPayment.fromMap(document.data());
          if (payment.isPaid) payments[payment.month] = payment;
        }
        return payments;
      });

  Stream<RehearsalRoomPayment?> watchRoomPayment(int year, int month) =>
      _roomPayments.doc(_paymentId(year, month)).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        final payment = RehearsalRoomPayment.fromMap(snapshot.data()!);
        return payment.isPaid ? payment : null;
      });

  Future<void> addManualIncome({
    required double amount,
    required String description,
    required DateTime effectiveDate,
  }) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final user = FirebaseAuth.instance.currentUser;
    final movementRef = _movements.doc();

    await _firestore.runTransaction((transaction) async {
      _updateBalance(transaction, amount);
      transaction.set(movementRef, {
        'type': 'manual_income',
        'amount': amount,
        'description': description.trim().isEmpty
            ? 'Aportación manual'
            : description.trim(),
        'category': 'manual_income',
        'referenceId': movementRef.id,
        'effectiveDate': Timestamp.fromDate(effectiveDate),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'isReversed': false,
      });
    });
  }

  Future<void> adjustFund({
    required double realBalance,
    required String reason,
  }) async {
    if (!realBalance.isFinite || realBalance < 0) {
      throw ArgumentError.value(realBalance, 'realBalance');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No hay ningún usuario autenticado.');
    }
    final movementRef = _movements.doc();

    await _firestore.runTransaction((transaction) async {
      final fundSnapshot = await transaction.get(_fund);
      final currentBalance =
          (fundSnapshot.data()?['availableAmount'] as num?)?.toDouble() ?? 0;
      final difference = fundAdjustmentDifference(
        currentBalance: currentBalance,
        realBalance: realBalance,
      );
      if (difference.abs() < 0.005) {
        throw StateError('No hay ninguna diferencia que guardar.');
      }

      _updateBalance(transaction, difference);
      transaction.set(movementRef, {
        'type': 'adjustment',
        'amount': difference,
        'reason': normalizedReason,
        'description': 'Ajuste manual',
        'category': 'adjustment',
        'referenceId': movementRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'isReversed': false,
      });
    });
  }

  Future<void> payRehearsalRoom(int year, int month) async {
    final paymentId = _paymentId(year, month);
    final paymentRef = _roomPayments.doc(paymentId);
    final firstMovementRef = _movements.doc(paymentId);
    final user = FirebaseAuth.instance.currentUser;

    await _firestore.runTransaction((transaction) async {
      final paymentSnapshot = await transaction.get(paymentRef);
      final movementSnapshot = await transaction.get(firstMovementRef);
      final alreadyPaid = paymentSnapshot.exists &&
          (paymentSnapshot.data()?['status'] == 'paid' ||
              paymentSnapshot.data()?['isPaid'] == true);
      final movementIsActive = movementSnapshot.exists &&
          (movementSnapshot.data()?['isReversed'] as bool? ?? false) == false;
      if (alreadyPaid || movementIsActive) {
        throw StateError('El pago de este mes ya está registrado.');
      }

      // El primer pago usa el identificador determinista requerido. Si un pago
      // previo se deshizo, se conserva su histórico y se crea un nuevo intento.
      final movementRef =
          movementSnapshot.exists ? _movements.doc() : firstMovementRef;

      _updateBalance(transaction, -rehearsalRoomMonthlyPayment);
      transaction.set(paymentRef, {
        'year': year,
        'month': month,
        'amount': rehearsalRoomMonthlyPayment,
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'movementId': movementRef.id,
        'createdBy': user?.uid,
      });
      transaction.set(movementRef, {
        'type': 'rehearsal_room_payment',
        'amount': -rehearsalRoomMonthlyPayment,
        'description': 'Pago local de ensayo - ${_monthName(month)} $year',
        'category': 'rehearsal_room',
        'referenceId': paymentId,
        'year': year,
        'month': month,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'isReversed': false,
      });
    });
  }

  Future<void> undoRehearsalRoomPayment(int year, int month) async {
    final paymentId = _paymentId(year, month);
    final paymentRef = _roomPayments.doc(paymentId);
    final user = FirebaseAuth.instance.currentUser;

    await _firestore.runTransaction((transaction) async {
      final paymentSnapshot = await transaction.get(paymentRef);
      final isPaid =
          paymentSnapshot.exists && paymentSnapshot.data()?['status'] == 'paid';
      if (!isPaid) {
        throw StateError('El pago de este mes no está activo.');
      }
      final movementId = paymentSnapshot.data()?['movementId'] as String?;
      if (movementId == null || movementId.isEmpty) {
        throw StateError('No se ha encontrado el movimiento del pago.');
      }
      final originalMovementRef = _movements.doc(movementId);
      final reversalMovementRef = _movements.doc('${movementId}_reversal');
      final originalMovementSnapshot =
          await transaction.get(originalMovementRef);
      final reversalSnapshot = await transaction.get(reversalMovementRef);
      final isReversed = originalMovementSnapshot.data()?['isReversed'] == true;
      if (!originalMovementSnapshot.exists || isReversed) {
        throw StateError('El pago de este mes no está activo.');
      }
      if (reversalSnapshot.exists) {
        throw StateError('El pago ya fue deshecho.');
      }

      _updateBalance(transaction, rehearsalRoomMonthlyPayment);
      transaction.update(originalMovementRef, {
        'isReversed': true,
        'reversalMovementId': reversalMovementRef.id,
        'reversedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(reversalMovementRef, {
        'type': 'rehearsal_room_payment_reversal',
        'amount': rehearsalRoomMonthlyPayment,
        'description':
            'Reversión pago local de ensayo - ${_monthName(month)} $year',
        'category': 'rehearsal_room',
        'referenceId': paymentId,
        'originalMovementId': originalMovementRef.id,
        'year': year,
        'month': month,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'isReversed': false,
      });
      transaction.delete(paymentRef);
    });
  }

  void _updateBalance(Transaction transaction, double difference) {
    transaction.set(
      _fund,
      {
        'availableAmount': FieldValue.increment(difference),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String _paymentId(int year, int month) =>
      'rehearsal_room_${year}_${month.toString().padLeft(2, '0')}';

  String _monthName(int month) => const [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ][month - 1];
}
