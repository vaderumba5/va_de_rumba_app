import 'package:flutter_test/flutter_test.dart';

import 'package:va_de_rumba/app.dart';

void main() {
  test('La raíz actual de la aplicación está disponible', () {
    expect(const VaDeRumbaApp(), isNotNull);
  });
}
