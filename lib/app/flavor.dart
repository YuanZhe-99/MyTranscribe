/// Build flavor configuration.
///
/// Pass `--dart-define=FLAVOR=store` for Google Play / App Store builds.
/// Default is `full`. No feature is gated on the flavor yet — the constant
/// exists so store-facing builds can be told apart the same way the sibling
/// apps do, and so a future online feature has a gate ready.
class AppFlavor {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AppFlavor._` instance.
  /// Side effects: None.
  /// Notes: Implementations should preserve this contract.
  AppFlavor._();

  static const _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'full');

  /// True when built for Google Play / App Store.
  static const isStore = _flavor == 'store';

  /// True when built as the full-featured version.
  static const isFull = !isStore;
}
