import 'package:getprio_mobile/onboarding/onboarding_store.dart';

class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore({this.completed = false});
  bool completed;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;

  @override
  Future<bool> isComplete() async {
    if (failRead) throw StateError('Read unavailable');
    return completed;
  }

  @override
  Future<void> complete() async {
    writes++;
    if (failWrite) throw StateError('Write unavailable');
    completed = true;
  }
}
