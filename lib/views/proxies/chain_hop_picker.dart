import 'package:flutter/material.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';

/// Picks a node for one front hop.
///
/// The card *is* the picker. Wrapping it in another dialog added a second title
/// bar and squeezed the node list into a narrow column; opening it directly, with
/// its title replaced by the hop name, keeps the layout the card was designed
/// for.
Future<void> showChainHopPicker({
  required BuildContext context,
  required String title,
  required Set<String> excludeNames,
  required void Function(String name) onSelect,
  bool allowFollowMain = true,
  bool allowPolicyGroups = false,
  String? sourceProfileId,
  List<Group>? candidateGroups,
  String? selectedName,
  List<SwitchCardSpecialOption> specialOptions = const [],
}) {
  return showDialog(
    context: context,
    builder: (ctx) => SwitchCard(
      title: title,
      excludeNames: excludeNames,
      allowPolicyGroups: allowPolicyGroups,
      sourceProfileId: sourceProfileId,
      candidateGroups: candidateGroups,
      selectedName: selectedName,
      specialOptions: [
        ...specialOptions,
        if (allowFollowMain)
          SwitchCardSpecialOption(
            label: appLocalizations.cardFollowMain,
            value: '',
            icon: Icons.auto_awesome,
          ),
      ],
      onSelect: (name, _) {
        onSelect(name);
        Navigator.of(ctx).pop();
      },
    ),
  );
}
