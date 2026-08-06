/// Importe fijo del pago mensual del local de ensayo.
const double rehearsalRoomMonthlyPayment = 70.0;

double? parseFundAmount(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  return double.tryParse(normalized);
}

double fundAdjustmentDifference({
  required double currentBalance,
  required double realBalance,
}) =>
    realBalance - currentBalance;
