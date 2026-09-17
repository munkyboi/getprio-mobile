import 'package:flutter/services.dart';

abstract interface class OnboardingStore {
  Future<bool> isComplete();
  Future<void> complete();
}

/// Installation-local storage, deliberately outside Keychain and OS backups.
class InstallationOnboardingStore implements OnboardingStore {
  const InstallationOnboardingStore();

  static const channel = MethodChannel('getprio/onboarding');

  @override
  Future<bool> isComplete() async =>
      await channel.invokeMethod<bool>('isComplete') ?? false;

  @override
  Future<void> complete() => channel.invokeMethod<void>('complete');
}
