import 'package:flutter/foundation.dart';

import '../services/storage.dart';

/// Flips to true when the user finishes onboarding. `main.dart` listens to it
/// and swaps the onboarding flow for the root shell (no circular import).
final ValueNotifier<bool> onboardingDone = ValueNotifier(false);

/// Persists completion and notifies listeners.
Future<void> completeOnboarding() async {
  await Store.setBool('onboarded', true);
  onboardingDone.value = true;
}
