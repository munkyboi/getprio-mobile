import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'onboarding_page.dart';
import 'onboarding_store.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.store,
    required this.loading,
    required this.child,
  });

  final OnboardingStore store;
  final Widget loading;
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late Future<bool> _complete;

  @override
  void initState() {
    super.initState();
    _complete = widget.store.isComplete();
  }

  Future<void> _finish() async {
    // Wait for persistence before proceeding; retries stay on the final slide.
    await widget.store.complete();
    if (mounted) {
      setState(() {
        _complete = Future.value(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _complete,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return widget.loading;
      }
      if (snapshot.hasError) {
        return Scaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your welcome screen.'),
                const SizedBox(height: 16),
                PrimaryButton(
                  onPressed: () => setState(() {
                    _complete = widget.store.isComplete();
                  }),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      return snapshot.data == true
          ? widget.child
          : OnboardingPage(onComplete: _finish);
    },
  );
}
