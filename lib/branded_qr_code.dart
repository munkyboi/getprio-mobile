import 'package:flutter_svg/flutter_svg.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shared scanner-readable branding for ticket and authenticator QR codes.
class BrandedQrCode extends StatelessWidget {
  const BrandedQrCode({
    super.key,
    required this.data,
    this.maxSize = 220,
    this.qrKey,
    this.brandKey,
  });
  final String data;
  final double maxSize;
  final Key? qrKey;
  final Key? brandKey;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.maxWidth.clamp(0.0, maxSize);
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PrettyQrView.data(
                key: qrKey,
                data: data,
                errorCorrectLevel: QrErrorCorrectLevel.H,
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(color: Colors.black),
                  background: Colors.white,
                  quietZone: PrettyQrQuietZone.standard,
                ),
              ),
              IgnorePointer(
                child: Container(
                  key: brandKey,
                  width: size * .14,
                  height: size * .14,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SvgPicture.asset(
                    'assets/branding/logo.svg',
                    semanticsLabel: 'GetPrio',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
