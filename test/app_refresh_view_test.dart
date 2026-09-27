import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:va_de_rumba/widgets/app_refresh_view.dart';

Widget _testApp(Future<void> Function() onRefresh, {int itemCount = 1}) {
  return MaterialApp(
    home: Scaffold(
      body: AppRefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (_, index) => SizedBox(
            height: 60,
            child: Text('Elemento $index'),
          ),
        ),
      ),
    ),
  );
}

Future<TestGesture> _startPull(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(200, 180));
  await gesture.moveBy(const Offset(0, 35));
  await tester.pump();
  return gesture;
}

void main() {
  testWidgets('muestra progreso y no refresca antes del umbral',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_testApp(() async {
      calls++;
    }));

    final gesture = await _startPull(tester);
    expect(find.text('Desliza para actualizar'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Desliza para actualizar'), findsNothing);
  });

  testWidgets('al superar el umbral refresca y muestra éxito', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_testApp(() async {
      calls++;
    }));

    final gesture = await _startPull(tester);
    await gesture.moveBy(const Offset(0, 250));
    await tester.pump();
    expect(find.text('Suelta para actualizar'), findsOneWidget);

    await gesture.up();
    for (var i = 0; i < 10 && calls == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(calls, 1);
    expect(find.text('Actualizado'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 750));
  });

  testWidgets('muestra error y conserva la pantalla', (tester) async {
    await tester.pumpWidget(_testApp(() async => throw StateError('network')));

    final gesture = await _startPull(tester);
    await gesture.moveBy(const Offset(0, 250));
    await gesture.up();
    for (var i = 0;
        i < 10 && find.text('No se pudo actualizar').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('No se pudo actualizar'), findsOneWidget);
    expect(find.text('Elemento 0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
  });

  testWidgets('impide dos actualizaciones simultáneas', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(_testApp(() {
      calls++;
      return completer.future;
    }));

    final gesture = await _startPull(tester);
    await gesture.moveBy(const Offset(0, 250));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);

    completer.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  });

  testWidgets('desplazarse hacia arriba no muestra el indicador',
      (tester) async {
    await tester.pumpWidget(_testApp(() async {}, itemCount: 30));

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pump();

    expect(find.text('Desliza para actualizar'), findsNothing);
    expect(find.text('Suelta para actualizar'), findsNothing);
    expect(find.text('Actualizando…'), findsNothing);
  });
}
