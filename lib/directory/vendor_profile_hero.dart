import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_theme.dart';
import '../theme_artwork.dart';
import '../queue/queue_models.dart';

class VendorProfileCover extends StatelessWidget {
  const VendorProfileCover({
    super.key,
    required this.vendor,
    required this.height,
  });

  final VendorSummary vendor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vendor.coverImageUrl;
    return SizedBox(
      key: const Key('vendor-profile-cover'),
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl == null)
            _vendorCoverFallback(context)
          else
            Image.network(
              imageUrl,
              fit: vendorBoxFit(vendor.coverImageFit, BoxFit.cover),
              semanticLabel: '${vendor.name} profile cover',
              errorBuilder: (context, error, stackTrace) =>
                  _vendorCoverFallback(context),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x75000000), Color(0x00000000)],
                stops: [0, 0.55],
              ),
            ),
          ),
          DecoratedBox(
            key: Key('profile-cover-surface-fade'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  GetPrioTheme.colors(context).paper,
                  GetPrioTheme.colors(context).paper.withValues(alpha: 0),
                ],
                stops: [0.0, 0.3],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vendorCoverFallback(BuildContext context) {
    return Container(
      color: GetPrioTheme.colors(context).paperAccent,
      padding: const EdgeInsets.fromLTRB(48, 64, 48, 36),
      child: Image(
        image: AssetImage(GetPrioArtwork.vendorCover(context)),
        fit: BoxFit.contain,
        semanticLabel: 'Illustration of a customer at a queue',
      ),
    );
  }
}

class VendorProfileLogo extends StatelessWidget {
  const VendorProfileLogo({
    super.key,
    required this.vendor,
    required this.size,
  });

  final VendorSummary vendor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vendor.logoUrl;
    return SizedBox(
      key: const Key('vendor-logo'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GetPrioTheme.colors(context).card,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(
              color: GetPrioTheme.colors(context).dark
                  ? GetPrioTheme.colors(context).line
                  : const Color(0xF2FFFFFF),
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x3D23180F),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipOval(
            child: imageUrl == null
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: SvgPicture.asset(
                      GetPrioArtwork.logo(context),
                      fit: BoxFit.contain,
                      semanticsLabel: 'GetPrio vendor logo placeholder',
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: vendorBoxFit(vendor.logoFit, BoxFit.cover),
                    semanticLabel: '${vendor.name} logo',
                    errorBuilder: (context, error, stackTrace) => Padding(
                      padding: const EdgeInsets.all(18),
                      child: SvgPicture.asset(
                        GetPrioArtwork.logo(context),
                        fit: BoxFit.contain,
                        semanticsLabel: 'GetPrio vendor logo placeholder',
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

BoxFit vendorBoxFit(String? value, BoxFit fallback) {
  return switch (value?.trim().toLowerCase()) {
    'contain' => BoxFit.contain,
    'fill' => BoxFit.fill,
    'fitwidth' || 'fit-width' => BoxFit.fitWidth,
    'fitheight' || 'fit-height' => BoxFit.fitHeight,
    'none' => BoxFit.none,
    'scaledown' || 'scale-down' => BoxFit.scaleDown,
    'cover' => BoxFit.cover,
    _ => fallback,
  };
}
