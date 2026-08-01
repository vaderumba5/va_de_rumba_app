import 'package:flutter/material.dart';

/// Identidad visual reutilizable de Va de Rumba.
///
/// La variante compacta centra el monograma para superficies reducidas, como
/// la barra lateral o el favicon; la normal conserva el logotipo completo.
class Logo extends StatelessWidget {
  const Logo({
    super.key,
    this.width = 160,
    this.compact = false,
    this.showWordmark = false,
    this.borderRadius = 14,
  });

  static const assetPath = 'assets/images/va_de_rumba_logo.png';

  final double width;
  final bool compact;
  final bool showWordmark;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: width, child: Image.asset(assetPath, fit: BoxFit.contain)),
          if (showWordmark) ...[
            const SizedBox(height: 14),
            Text(
              'VA DE RUMBA',
              style: TextStyle(
                fontSize: width * .13,
                fontWeight: FontWeight.w900,
                letterSpacing: width * .025,
                color: const Color(0xFF29252E),
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      width: width,
      height: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF101014),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFF4A4754)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -.12),
      ),
    );
  }
}
