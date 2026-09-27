/// Fluxora Design System — reusable components (D4.5).
///
/// The first reusable layer built on the D4.3 tokens and the D4.4 theme
/// integration. Every component here is **presentational**: it takes plain
/// values, reads colours from `ColorScheme` / `FluxoraColorSet`, and never
/// touches a provider, the network core or any page-specific state.
///
/// | component | purpose |
/// | --- | --- |
/// | [FluxoraCard] | surface / card primitive (thin wrapper over `CommonCard`) |
/// | [FluxoraStatus] | semantic connection / health dot + label |
/// | [FluxoraFlowIndicator] | the "Flow" mark — flow line into a node |
/// | [FluxoraProxyTile] | proxy / node row |
/// | [FluxoraSpeedGauge] | download / upload / combined speed read-out |
/// | [FluxoraLatencyBadge] | latency pill (`12 ms` / `Timeout`) |
/// | [FluxoraEmptyState] | unified empty / unavailable / error placeholder |
library;

export 'fluxora_card.dart';
export 'fluxora_empty_state.dart';
export 'fluxora_flow_indicator.dart';
export 'fluxora_latency_badge.dart';
export 'fluxora_proxy_tile.dart';
export 'fluxora_speed_gauge.dart';
export 'fluxora_status.dart';
