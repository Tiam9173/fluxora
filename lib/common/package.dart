const defaultSubscriptionUserAgent = 'FlClash/ClashMetaForAndroid/2.11.33.Fluxora';

String subscriptionUserAgent(String? custom) {
  final value = custom?.trim();
  return value == null || value.isEmpty ? defaultSubscriptionUserAgent : value;
}
