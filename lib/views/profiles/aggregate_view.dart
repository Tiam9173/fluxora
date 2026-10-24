import 'dart:async';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';

/// Manages the node-pool aggregate without forcing users back into every
/// profile's edit sheet. Members are the profiles already marked with
/// `joinAggregate`; the current profile is always the base config and cannot
/// be a member of itself.
class AggregateView extends StatefulWidget {
  const AggregateView({super.key});

  @override
  State<AggregateView> createState() => _AggregateViewState();
}

class _AggregateViewState extends State<AggregateView> {
  late List<Profile> profiles;
  final Map<String, TextEditingController> _aliasControllers = {};
  final Map<String, Timer> _aliasTimers = {};

  @override
  void initState() {
    super.initState();
    profiles = List<Profile>.from(globalState.config.profiles);
  }

  @override
  void dispose() {
    for (final timer in _aliasTimers.values) {
      timer.cancel();
    }
    for (final controller in _aliasControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _aliasController(Profile profile) {
    return _aliasControllers.putIfAbsent(
      profile.id,
      () => TextEditingController(text: profile.aggregateAlias),
    );
  }

  Profile? _profileById(String id) {
    final index = profiles.indexWhere((profile) => profile.id == id);
    return index == -1 ? null : profiles[index];
  }

  void _replaceProfile(Profile profile) {
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) return;
    setState(() => profiles[index] = profile);
    globalState.appController.setProfile(profile);
    globalState.appController.applyProfileDebounce(silence: true);
  }

  void _setJoin(Profile profile, bool value) {
    _replaceProfile(profile.copyWith(joinAggregate: value));
  }

  Future<void> _setMode(AggregateMode mode) async {
    if (globalState.config.aggregateMode == mode) return;
    final next = globalState.config.copyWith(aggregateMode: mode);
    globalState.config = next;
    await preferences.saveConfig(next);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  Future<void> _setScriptTiming(AggregateScriptTiming timing) async {
    if (globalState.config.aggregateScriptTiming == timing) return;
    final next = globalState.config.copyWith(aggregateScriptTiming: timing);
    globalState.config = next;
    await preferences.saveConfig(next);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  void _scheduleAlias(Profile profile, String value) {
    _aliasTimers[profile.id]?.cancel();
    _aliasTimers[profile.id] = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final current = _profileById(profile.id);
      if (current == null) return;
      final alias = value.trim();
      if (alias == current.aggregateAlias) return;
      _replaceProfile(current.copyWith(aggregateAlias: alias));
    });
  }

  Map<String, String> _memberAliases(String currentProfileId) {
    final aliases = <String, String>{};
    final used = <String>{};
    for (final profile in profiles) {
      if (profile.id == currentProfileId || !profile.joinAggregate) continue;
      aliases[profile.id] = uniqueAggregateAlias(
        profile.aggregateAlias.isNotEmpty
            ? profile.aggregateAlias
            : (profile.label ?? profile.id),
        used,
      );
    }
    return aliases;
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text, style: context.textTheme.titleSmall),
    );
  }

  Widget _card(BuildContext context, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _memberTile(BuildContext context, Profile profile, bool isCurrent) {
    final isMember = profile.joinAggregate;
    final subtitle = isCurrent
        ? appLocalizations.aggregateBaseProfile
        : (profile.type == ProfileType.url
              ? appLocalizations.url
              : appLocalizations.localFile);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _card(
        context,
        Column(
          children: [
            Row(
              children: [
                Icon(
                  isCurrent ? Icons.flag_outlined : Icons.link_rounded,
                  size: 18,
                  color: isCurrent
                      ? context.colorScheme.primary
                      : context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.label ?? profile.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyLarge,
                      ),
                      Text(
                        subtitle,
                        style: context.textTheme.labelSmall?.toLight,
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Chip(
                    label: Text(appLocalizations.aggregateCurrent),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Switch(
                    value: isMember,
                    onChanged: (value) => _setJoin(profile, value),
                  ),
              ],
            ),
            if (!isCurrent && isMember) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _aliasController(profile),
                onChanged: (value) => _scheduleAlias(profile, value),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: appLocalizations.aggregatePrefix,
                  hintText: profile.label ?? profile.id,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required AggregateMode mode,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = globalState.config.aggregateMode == mode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _setMode(mode),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.45)
                : context.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.2 : 0.5,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: context.textTheme.titleSmall,
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: context.colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: context.textTheme.bodySmall?.toLight,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, String currentProfileId) {
    final aliases = _memberAliases(currentProfileId);
    if (aliases.isEmpty) {
      return Text(
        appLocalizations.aggregateNoMembers,
        style: context.textTheme.bodyMedium?.toLight,
      );
    }
    final rows = <Widget>[];
    for (final entry in aliases.entries) {
      rows.add(_previewRow(
        context,
        icon: Icons.dns_outlined,
        title: appLocalizations.aggregateMemberGroup(entry.value),
        source: appLocalizations.aggregateNotCurrent,
      ));
      rows.add(_previewRow(
        context,
        icon: Icons.speed_outlined,
        title: appLocalizations.aggregateMemberAuto(entry.value),
        source: appLocalizations.aggregateNotCurrent,
      ));
    }
    rows.add(_previewRow(
      context,
      icon: Icons.hub_outlined,
      title: appLocalizations.aggregateGroupNodes,
      source: appLocalizations.aggregateCurrent,
    ));
    rows.add(_previewRow(
      context,
      icon: Icons.auto_awesome_outlined,
      title: appLocalizations.aggregateGroupAuto,
      source: appLocalizations.aggregateCurrent,
    ));
    return Column(children: rows);
  }

  Widget _previewRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String source,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(source, style: context.textTheme.labelSmall?.toLight),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProfileId = globalState.config.currentProfileId ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          appLocalizations.aggregateDesc,
          style: context.textTheme.bodyMedium?.toLight,
        ),
        _sectionTitle(context, appLocalizations.aggregateMode),
        _modeCard(
          context,
          mode: AggregateMode.nodePool,
          icon: Icons.hub_outlined,
          title: appLocalizations.aggregateNodePool,
          description: appLocalizations.aggregateNodePoolDesc,
        ),
        _modeCard(
          context,
          mode: AggregateMode.full,
          icon: Icons.merge_type,
          title: appLocalizations.aggregateFullMerge,
          description: appLocalizations.aggregateFullMergeDesc,
        ),
        if (globalState.config.aggregateMode == AggregateMode.full) ...[
          _sectionTitle(context, appLocalizations.aggregateScriptTiming),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(appLocalizations.aggregateScriptBefore),
                selected: globalState.config.aggregateScriptTiming ==
                    AggregateScriptTiming.before,
                onSelected: (_) =>
                    _setScriptTiming(AggregateScriptTiming.before),
              ),
              ChoiceChip(
                label: Text(appLocalizations.aggregateScriptAfter),
                selected: globalState.config.aggregateScriptTiming ==
                    AggregateScriptTiming.after,
                onSelected: (_) =>
                    _setScriptTiming(AggregateScriptTiming.after),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            globalState.config.aggregateScriptTiming ==
                    AggregateScriptTiming.after
                ? appLocalizations.aggregateScriptAfterDesc
                : appLocalizations.aggregateMemberScriptNote,
            style: context.textTheme.labelSmall?.toLight,
          ),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            appLocalizations.aggregateMemberScriptNote,
            style: context.textTheme.labelSmall?.toLight,
          ),
        ],
        _sectionTitle(context, appLocalizations.aggregateMembers),
        for (final profile in profiles)
          _memberTile(
            context,
            profile,
            profile.id == currentProfileId,
          ),
        if (_memberAliases(currentProfileId).isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              appLocalizations.aggregateNoMembers,
              style: context.textTheme.bodyMedium?.toLight,
            ),
          ),
        _sectionTitle(context, appLocalizations.aggregateTitle),
        _card(context, _preview(context, currentProfileId)),
        const SizedBox(height: 10),
        Text(
          appLocalizations.aggregatePreviewNote,
          style: context.textTheme.labelSmall?.toLight,
        ),
      ],
    );
  }
}
