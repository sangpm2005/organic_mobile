import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/theme/organic_theme.dart';

/// Reuses the same brand assets as the frontend's PaymentBrand component.
class PaymentBrand extends StatelessWidget {
  final String gateway;
  const PaymentBrand(this.gateway, {super.key});

  @override
  Widget build(BuildContext context) {
    final asset = const {
      'payos': 'vietqr.png',
      'paypal': 'paypal.png',
      'vnpay': 'vnpay.png',
      'stripe': 'stripe.svg',
    }[gateway];
    return ExcludeSemantics(
      child: Container(
        key: ValueKey('payment.brand.$gateway'),
        width: 72,
        height: 48,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: asset == null
            ? const Icon(Icons.payments_outlined, color: moss, size: 26)
            : asset.endsWith('.svg')
            ? SvgPicture.asset(
                'assets/images/payments/$asset',
                fit: BoxFit.contain,
              )
            : Image.asset('assets/images/payments/$asset', fit: BoxFit.contain),
      ),
    );
  }
}
