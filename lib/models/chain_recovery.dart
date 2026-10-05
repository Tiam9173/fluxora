import 'package:flutter/foundation.dart';

enum ChainRecoveryAction {
  none,
  retryCurrentChain,
  validateCurrentNodes,
  suggestNodeReplacement,
  prepareFailover,
  pauseChainProxy,
}

enum RecoveryRequestState { pending, approved, rejected, expired, executed }

@immutable
class ChainRecoveryPlan {
  final ChainRecoveryAction action;
  final String title;
  final String description;
  final List<String> affectedNodes;
  final bool requiresConfirmation;

  const ChainRecoveryPlan({
    required this.action,
    required this.title,
    required this.description,
    this.affectedNodes = const [],
    this.requiresConfirmation = true,
  });
}

class ChainRecoveryRequest {
  final ChainRecoveryPlan plan;
  RecoveryRequestState state;

  ChainRecoveryRequest({
    required this.plan,
    this.state = RecoveryRequestState.pending,
  });
}
