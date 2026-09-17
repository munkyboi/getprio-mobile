import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import 'onboarding_artwork.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onComplete,
    this.initialPage = 0,
  }) : assert(initialPage >= 0 && initialPage < 3);

  final Future<void> Function() onComplete;
  final int initialPage;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _controller;
  late int _page;
  bool _saving = false;
  String? _error;

  static const _slides = [
    (
      title: 'Your place in line,\njust one scan away',
      body: 'Scan the vendor’s QR code, review the queue, and join from your phone. Your next visit starts here.',
    ),
    (
      title: 'Less wondering,\nmore time for you',
      body: 'Keep your ticket close. See your place in the queue and follow the latest updates as you wait.',
    ),
    (
      title: 'A little heads-up,\nright on time',
      body: 'Get queue alerts so you’re ready when called. Open your ticket anytime for the latest status.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _next() async {
    if (_saving) return;
    if (_page < 2) {
      _goTo(_page + 1);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save your progress. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: GetPrioTheme.paper,
      ),
      child: Scaffold(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFAF7F2), Color(0xFFFFFDF9), Color(0xFFFBFAF8)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Semantics(
                        label: 'GetPrio',
                        image: true,
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/branding/logo.svg',
                                width: 42,
                                height: 42,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'GetPrio',
                                style: TextStyle(
                                  fontFamily: GetPrioTypography.uiFontFamily,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const Key('onboarding-pages'),
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (page) => setState(() {
                          _page = page;
                          _error = null;
                        }),
                        itemBuilder: (context, index) => LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 12),
                                      ExcludeSemantics(
                                        child: SizedBox(
                                          height: (constraints.maxHeight * .53)
                                              .clamp(230.0, 350.0),
                                          width: double.infinity,
                                          child: OnboardingArtwork(page: index),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Semantics(
                                        header: true,
                                        child: Text(
                                          _slides[index].title,
                                          key: Key('onboarding-title-$index'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily:
                                                GetPrioTypography.uiFontFamily,
                                            fontSize: 28,
                                            height: 1.18,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -1,
                                            color: Color(0xFF191919),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 340,
                                        ),
                                        child: Text(
                                          _slides[index].body,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily:
                                                GetPrioTypography.uiFontFamily,
                                            fontSize: 14,
                                            height: 1.65,
                                            color: GetPrioTheme.mutedInk,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    Semantics(
                      liveRegion: true,
                      label: 'Slide ${_page + 1} of 3',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (index) => Semantics(
                            label: 'Go to slide ${index + 1}',
                            selected: _page == index,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: GhostButton(
                                key: Key('onboarding-dot-$index'),
                                density: ButtonDensity.compact,
                                alignment: Alignment.center,
                                onPressed: _saving ? null : () => _goTo(index),
                                child: Container(
                                  key: Key('onboarding-dot-mark-$index'),
                                  width: _page == index ? 23 : 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _page == index
                                        ? const Color(0xFF282729)
                                        : const Color(0xFFD4CEC6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: GetPrioTheme.orangeStrong,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 32, 22, 18),
                      child: ComponentTheme<PrimaryButtonTheme>(
                        data: PrimaryButtonTheme(
                          decoration: (context, states, value) =>
                              value is BoxDecoration
                              ? value.copyWith(
                                  color: GetPrioTheme.primary,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: const Color(0xFFE8781B),
                                  ),
                                  boxShadow: const [
                                    GetPrioTheme.primaryActionShadow,
                                  ],
                                )
                              : value,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: PrimaryButton(
                            key: const Key('onboarding-next'),
                            onPressed: _saving ? null : _next,
                            alignment: Alignment.center,
                            child: Text(
                              _saving
                                  ? 'Saving…'
                                  : _page == 2
                                  ? 'Get started'
                                  : 'Next',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3B200B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
