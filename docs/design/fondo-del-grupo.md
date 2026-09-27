# Fondo del grupo

Referencias consultadas el 27 de septiembre de 2026:

- [Monzo Pots](https://monzo.com/features/pots): separar el dinero destinado a gastos comunes y facilitar la previsión de cuotas.
- [Revolut Pockets](https://www.revolut.com/blog/post/meet-pockets-the-next-evolution-of-vaults/): distinguir ahorro compartido y gastos recurrentes.
- [Revolut Group Bills](https://help.revolut.com/help/transfers/group-bills/question-group-bills/): mantener un historial explícito de gastos de grupo.

## Aplicación al diseño

Saldo destacado en una tarjeta verde oscuro, con contraste alto y cobertura orientativa de cuotas del local. La cobertura usa la cuota configurada y el saldo actual: no descuenta gastos futuros ni implica que los meses estén pagados.

Actividad mensual organizada en ingresos y gastos registrados, aportación prevista de conciertos y reparto estimado por integrante. La fecha del resumen siempre corresponde al mes actual; el selector de año del local afecta exclusivamente a su historial.

Tres vistas para evitar una página de paneles acumulados: movimientos, local de ensayo y análisis. Contenido centrado en pantallas grandes; resumen apilado en pantallas estrechas y métricas adaptadas al espacio y al tamaño del texto.

Los filtros permiten buscar, seleccionar tipo, categoría y mes, y limpiar todos los criterios. Se diferencia un historial vacío de una búsqueda sin resultados. El campo de búsqueda conserva su texto al cambiar de vista.

El control de visibilidad indica expresamente que oculta los importes del resumen; incluye también su cobertura calculada. No es un modo de privacidad global.

## Verificación

Pruebas de disposición en 320, 390, 768, 1024 y 1440 píxeles, texto ampliado al doble, importes grandes, saldo negativo, cuota cero y ocultación de importes. Se conservan las pruebas de importes y reparto de conciertos.

La vista previa opcional de `fund_overview_test.dart` usa datos ficticios y se activa con `FUND_PREVIEW=true`. `FUND_FONT_DIR` permite cargar las fuentes locales de Flutter para la captura; la vista previa usa Roboto, mientras que la aplicación conserva su tema Inter.
