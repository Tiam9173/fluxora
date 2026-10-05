abstract class INetworkFingerprintProvider {
  String getCurrentFingerprint();
}

class NetworkFingerprintProvider implements INetworkFingerprintProvider {
  static const String wifi = 'wifi_default';
  static const String cellular = 'cellular_default';
  static const String unknown = 'unknown_default';

  String _current = unknown;

  void setMockFingerprint(String fingerprint) {
    _current = fingerprint;
  }

  @override
  String getCurrentFingerprint() {
    // In a real app, this would use connectivity_plus to determine SSID or cellular state.
    // For Phase 5.7, we maintain an injectable fingerprint state.
    return _current;
  }
}

// Global instance for simple DI
final networkFingerprintProvider = NetworkFingerprintProvider();
