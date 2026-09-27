import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/fund_constants.dart';
import '../models/rehearsal_room_payment.dart';
import '../models/concert.dart';

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
    this.notes,
    this.concertId,
    this.concertName,
    this.createdBy,
    this.createdByName,
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
  final String? notes;
  final String? concertId;
  final String? concertName;
  final String? createdBy;
  final String? createdByName;
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
      notes: data['notes'] as String?,
      concertId: data['concertId'] as String?,
      concertName: data['concertName'] as String?,
      createdBy: data['createdBy'] as String?,
      createdByName: data['createdByName'] as String?,
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
  CollectionReference<Map<String, dynamic>> get _concerts =>
      _firestore.collection('concerts');

  Stream<double> watchAvailableAmount() => _fund.snapshots().map(
        (snapshot) =>
            (snapshot.data()?['availableAmount'] as num?)?.toDouble() ?? 0,
      );

  Stream<double> watchRehearsalRoomFee() => _fund.snapshots().map(
        (snapshot) =>
            (snapshot.data()?['rehearsalRoomMonthlyPayment'] as num?)
                ?.toDouble() ??
            rehearsalRoomMonthlyPayment,
      );

  Stream<int> watchDistributionMemberCount() => _fund.snapshots().map(
        (snapshot) =>
            (snapshot.data()?['distributionMemberCount'] as num?)?.toInt() ?? 5,
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

  Future<void> refresh(int year) async {
    await Future.wait([
      _fund.get(const GetOptions(source: Source.server)),
      _movements.get(const GetOptions(source: Source.server)),
      _roomPayments
          .where('year', isEqualTo: year)
          .get(const GetOptions(source: Source.server)),
    ]);
  }

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

  Future<void> addManualMovement({
    required bool isIncome,
    required double amount,
    required String description,
    required String category,
    required DateTime effectiveDate,
    String notes = '',
    String concertId = '',
    String concertName = '',
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError.value(description, 'description');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay ningún usuario autenticado.');
    final movementRef = _movements.doc();
    final signedAmount = isIncome ? amount : -amount;
    await _firestore.runTransaction((transaction) async {
      _updateBalance(transaction, signedAmount);
      transaction.set(movementRef, {
        'type': isIncome ? 'manual_income' : 'manual_expense',
        'amount': signedAmount,
        'description': description.trim(),
        'category': category,
        'notes': notes.trim(),
        'concertId': concertId,
        'concertName': concertName,
        'referenceId': movementRef.id,
        'effectiveDate': Timestamp.fromDate(effectiveDate),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByName': user.displayName ?? user.email ?? '',
        'isReversed': false,
      });
    });
  }

  Future<void> updateManualMovement({
    required FundMovement movement,
    required bool isIncome,
    required double amount,
    required String description,
    required String category,
    required DateTime effectiveDate,
    String notes = '',
    String concertId = '',
    String concertName = '',
  }) async {
    if (!movement.type.startsWith('manual_')) {
      throw StateError('Este movimiento automático no se puede editar.');
    }
    if (!amount.isFinite || amount <= 0 || description.trim().isEmpty) {
      throw ArgumentError('Datos de movimiento no válidos.');
    }
    final ref = _movements.doc(movement.id);
    final newAmount = isIncome ? amount : -amount;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('El movimiento ya no existe.');
      final oldAmount =
          (snapshot.data()?['amount'] as num?)?.toDouble() ?? movement.amount;
      _updateBalance(transaction, newAmount - oldAmount);
      transaction.update(ref, {
        'type': isIncome ? 'manual_income' : 'manual_expense',
        'amount': newAmount,
        'description': description.trim(),
        'category': category,
        'notes': notes.trim(),
        'concertId': concertId,
        'concertName': concertName,
        'effectiveDate': Timestamp.fromDate(effectiveDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteManualMovement(FundMovement movement) async {
    if (!movement.type.startsWith('manual_')) {
      throw StateError(
          'Los movimientos automáticos deben revertirse desde su origen.');
    }
    final ref = _movements.doc(movement.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('El movimiento ya no existe.');
      final amount = (snapshot.data()?['amount'] as num?)?.toDouble() ?? 0;
      _updateBalance(transaction, -amount);
      transaction.delete(ref);
    });
  }

  Future<void> setRehearsalRoomFee(double amount) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    await _fund.set({
      'rehearsalRoomMonthlyPayment': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDistributionMemberCount(int count) async {
    if (count < 1 || count > 50) throw ArgumentError.value(count, 'count');
    await _fund.set({
      'distributionMemberCount': count,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> confirmConcertDistribution(
    Concert concert, {
    required int memberCount,
  }) async {
    if (memberCount <= 0) throw ArgumentError.value(memberCount, 'memberCount');
    final cache = concert.price;
    if (cache == null || cache <= 0) {
      throw StateError('El concierto no tiene un caché válido.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay ningún usuario autenticado.');
    final movementRef = _movements.doc('concert_contribution_${concert.id}');
    final concertRef = _concerts.doc(concert.id);
    final contribution = concert.fundContribution.clamp(0, cache).toDouble();
    final distributable = (cache - contribution - concert.associatedExpenses)
        .clamp(0, double.infinity)
        .toDouble();
    await _firestore.runTransaction((transaction) async {
      final movementSnapshot = await transaction.get(movementRef);
      if (movementSnapshot.exists &&
          movementSnapshot.data()?['isReversed'] != true) {
        throw StateError('La aportación de este concierto ya está registrada.');
      }
      _updateBalance(transaction, contribution);
      transaction.set(movementRef, {
        'type': 'concert_contribution',
        'amount': contribution,
        'description':
            'Aportación concierto - ${concert.venueName.trim().isEmpty ? concert.place : concert.venueName}',
        'category': 'contribution',
        'referenceId': concert.id,
        'concertId': concert.id,
        'concertName': concert.venueName.trim().isEmpty
            ? concert.place
            : concert.venueName,
        'cache': cache,
        'associatedExpenses': concert.associatedExpenses,
        'distributable': distributable,
        'splitMemberCount': memberCount,
        'perMember': distributable / memberCount,
        'effectiveDate': Timestamp.fromDate(concert.date),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByName': user.displayName ?? user.email ?? '',
        'isReversed': false,
      });
      transaction.update(concertRef, {
        'paymentStatus': 'confirmed',
        'distributionStatus': 'confirmed',
        'splitMemberCount': memberCount,
        'updatedAt': FieldValue.serverTimestamp(),
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

  Future<void> payRehearsalRoom(
    int year,
    int month, {
    double? amount,
    DateTime? effectiveDate,
    String notes = '',
    String? description,
  }) async {
    final paymentId = _paymentId(year, month);
    final paymentRef = _roomPayments.doc(paymentId);
    final firstMovementRef = _movements.doc(paymentId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay ningún usuario autenticado.');

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

      final paymentAmount = amount ??
          (fundSnapshotValue(await transaction.get(_fund),
                  'rehearsalRoomMonthlyPayment') ??
              rehearsalRoomMonthlyPayment);
      _updateBalance(transaction, -paymentAmount);
      transaction.set(paymentRef, {
        'year': year,
        'month': month,
        'amount': paymentAmount,
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentDate': Timestamp.fromDate(effectiveDate ?? DateTime.now()),
        'movementId': movementRef.id,
        'paidBy': user.uid,
        'paidByName': user.displayName ?? user.email ?? '',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(movementRef, {
        'type': 'rehearsal_room_payment',
        'amount': -paymentAmount,
        'description': description?.trim().isNotEmpty == true
            ? description!.trim()
            : 'Pago local de ensayo - ${_monthName(month)} $year',
        'category': 'rehearsal_room',
        'notes': notes.trim(),
        'effectiveDate': Timestamp.fromDate(effectiveDate ?? DateTime.now()),
        'referenceId': paymentId,
        'year': year,
        'month': month,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByName': user.displayName ?? user.email ?? '',
        'isReversed': false,
      });
    });
  }

  double? fundSnapshotValue(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String field,
  ) =>
      (snapshot.data()?[field] as num?)?.toDouble();

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

      final paymentAmount =
          (paymentSnapshot.data()?['amount'] as num?)?.toDouble() ??
              rehearsalRoomMonthlyPayment;
      _updateBalance(transaction, paymentAmount);
      transaction.update(originalMovementRef, {
        'isReversed': true,
        'reversalMovementId': reversalMovementRef.id,
        'reversedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(reversalMovementRef, {
        'type': 'rehearsal_room_payment_reversal',
        'amount': paymentAmount,
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
