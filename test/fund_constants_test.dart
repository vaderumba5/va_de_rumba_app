import 'package:flutter_test/flutter_test.dart';
import 'package:va_de_rumba/core/fund_constants.dart';

void main() {
  test('calcula un ajuste negativo sin alterar el saldo anterior', () {
    expect(
      fundAdjustmentDifference(
        currentBalance: 1240,
        realBalance: 1180,
      ),
      -60,
    );
  });

  test('calcula un ajuste positivo', () {
    expect(
      fundAdjustmentDifference(
        currentBalance: 100,
        realBalance: 125.50,
      ),
      25.50,
    );
  });

  test('acepta coma decimal y rechaza decimales inválidos', () {
    expect(parseFundAmount('1180,25'), 1180.25);
    expect(parseFundAmount('12,3,4'), isNull);
  });
}
