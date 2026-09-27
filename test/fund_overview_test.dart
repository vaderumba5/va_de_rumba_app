import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:va_de_rumba/widgets/fund_overview.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  Widget overview(
          {bool hidden = false,
          double balance = 2450,
          double fee = 200,
          VoidCallback? onToggle}) =>
      FundOverview(
        balance: balance,
        income: 900,
        expenses: 240,
        monthlyFee: fee,
        previousMonthBalance: 400,
        concertContributions: 350,
        individualEstimate: 180,
        hidden: hidden,
        onToggleAmounts: onToggle ?? () {},
        month: DateTime(2026, 9),
      );

  Future<void> show(WidgetTester tester, Widget child,
      {double width = 1200, double scale = 1}) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'FundPreview'),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        )),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('Summary fits a $width px viewport', (tester) async {
      await show(tester, overview(), width: width);
      expect(tester.takeException(), isNull);
      expect(find.text('12 cuotas cubiertas del local'), findsOneWidget);
      expect(find.text('Previsión del mes'), findsOneWidget);
      expect(find.text('septiembre 2026'), findsOneWidget);
    });
  }

  testWidgets('Large text and amounts remain readable on mobile',
      (tester) async {
    await show(tester, overview(balance: 1234567.89), width: 320, scale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Privacy hides balances and derived coverage', (tester) async {
    var toggles = 0;
    await show(tester, overview(hidden: true, onToggle: () => toggles++));
    expect(find.textContaining('2.450'), findsNothing);
    expect(find.textContaining('12 cuotas'), findsNothing);
    expect(find.text('Previsión del local oculta'), findsOneWidget);
    await tester.tap(find.byTooltip('Mostrar importes del resumen'));
    expect(toggles, 1);
  });

  testWidgets('Negative balance never promises covered payments',
      (tester) async {
    await show(tester, overview(balance: -100));
    expect(find.text('0 cuotas cubiertas del local'), findsOneWidget);
    await show(tester, overview(fee: 0));
    expect(find.text('Cuota del local sin configurar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Optional local render for visual review, using explicitly fictional data.
  if (const bool.fromEnvironment('FUND_PREVIEW')) {
    testWidgets('Render fund overview for visual review', (tester) async {
      const fontDirectory = String.fromEnvironment('FUND_FONT_DIR');
      if (fontDirectory.isNotEmpty) {
        await tester.runAsync(() async {
          for (final font in {
            'FundPreview': 'Roboto-Regular.ttf',
            'MaterialIcons': 'MaterialIcons-Regular.otf'
          }.entries) {
            final loader = FontLoader(font.key)
              ..addFont(File('$fontDirectory/${font.value}')
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)));
            await loader.load();
          }
        });
      }
      final key = GlobalKey();
      await show(
          tester,
          RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFFF7F7F7),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fondo del grupo',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Vista de diseño · Datos de ejemplo'),
                      const SizedBox(height: 24),
                      overview(),
                    ]),
              ),
            ),
          ));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/fund-overview-preview.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
