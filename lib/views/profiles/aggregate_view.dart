import 'dart:async';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Manages the node-pool aggregate without forcing users back into every
/// profile's edit sheet. Members are the profiles already marked with
/// `joinAggregate`; the current profile is always the base config and cannot
/// be a member of itself.
class AggregateView extends StatefulWidget {
  const AggregateView({super.key});

  @override
  State<AggregateView> createState() => _AggregateViewState();
}

class _AggregateMemberStats {
  final int nodes;
  final int groups;
  final int rules;
  final bool failed;
  final String? error;

  const _AggregateMemberStats({
    required this.nodes,
    required this.groups,
    required this.rules,
    this.failed = false,
    this.error,
  });
}

class _AggregateViewState extends State<AggregateView> {
  late List<Profile> profiles;
  final Map<String, TextEditingController> _aliasControllers = {};
  final Map<String, Timer> _aliasTimers = {};
  final Map<String, _AggregateMemberStats> _stats = {};
  bool _loadingStats = true;
  bool _buildingPreview = false;

  @override
  void initState() {
    super.initState();
    profiles = List<Profile>.from(globalState.config.profiles);
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!_loadingStats && mounted) {
      setState(() => _loadingStats = true);
    }
    final next = <String, _AggregateMemberStats>{};
    for (final profile in profiles) {
      try {
        final config = await globalState.getProfileConfig(profile.id);
        final proxies = config['proxies'];
        final groups = config['proxy-groups'];
        final rules = config['rules'] ?? config['rule'];
        next[profile.id] = _AggregateMemberStats(
          nodes: proxies is List ? proxies.length : 0,
          groups: groups is List ? groups.length : 0,
          rules: rules is List ? rules.length : 0,
        );
      } catch (e) {
        next[profile.id] = _AggregateMemberStats(
          nodes: 0,
          groups: 0,
          rules: 0,
          failed: true,
          error: e.toString(),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _stats
        ..clear()
        ..addAll(next);
      _loadingStats = false;
    });
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
    final previous = profiles[index];
    var next = profile;
    if (previous.aggregateAlias != profile.aggregateAlias) {
      final oldAlias = previous.aggregateAlias.isNotEmpty
          ? previous.aggregateAlias
          : (previous.label ?? previous.id);
      final newAlias = profile.aggregateAlias.isNotEmpty
          ? profile.aggregateAlias
          : (profile.label ?? profile.id);
      final oldPrefix = '[$oldAlias] ';
      final currentGroup = profile.currentGroupName;
      next = profile.copyWith(
        selectedMap: remapAggregateSelection(
          profile.selectedMap,
          oldAlias: oldAlias,
          newAlias: newAlias,
        ),
        currentGroupName:
            currentGroup != null && currentGroup.startsWith(oldPrefix)
            ? '[$newAlias] ${currentGroup.substring(oldPrefix.length)}'
            : currentGroup,
      );
    }
    setState(() => profiles[index] = next);
    globalState.appController.setProfile(next);
    globalState.appController.applyProfileDebounce(silence: true);
  }

  AggregateProfile? get _activeAggregate =>
      globalState.config.currentAggregate;

  bool _isMember(Profile profile) {
    final active = _activeAggregate;
    if (active != null) return active.memberIds.contains(profile.id);
    return profile.joinAggregate;
  }

  Future<void> _selectAggregate(String? id) async {
    final config = globalState.config.copyWith(
      currentAggregateId: id == null || id.isEmpty ? null : id,
    );
    globalState.config = config;
    await preferences.saveConfig(config);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  Future<void> _editAggregateName({AggregateProfile? aggregate}) async {
    final controller = TextEditingController(text: aggregate?.name ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            aggregate == null
                ? appLocalizations.aggregateNew
                : appLocalizations.aggregateRename,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: appLocalizations.aggregateName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final current = globalState.config;
                late final Config config;
                if (aggregate == null) {
                  final created = AggregateProfile(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: name,
                  );
                  config = current.copyWith(
                    aggregates: [...current.aggregates, created],
                    currentAggregateId: created.id,
                  );
                } else {
                  config = current.copyWith(
                    aggregates: current.aggregates
                        .map(
                          (item) => item.id == aggregate.id
                              ? item.copyWith(name: name)
                              : item,
                        )
                        .toList(),
                  );
                }
                globalState.config = config;
                await preferences.saveConfig(config);
                globalState.appController.applyProfileDebounce(silence: true);
                if (mounted) setState(() {});
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(appLocalizations.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAggregate() async {
    final aggregate = _activeAggregate;
    if (aggregate == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appLocalizations.aggregateDelete),
        content: Text(aggregate.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(appLocalizations.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final config = globalState.config.copyWith(
      aggregates: globalState.config.aggregates
          .where((item) => item.id != aggregate.id)
          .toList(),
      currentAggregateId: null,
    );
    globalState.config = config;
    await preferences.saveConfig(config);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  void _setJoin(Profile profile, bool value) {
    final active = _activeAggregate;
    if (active == null) {
      _replaceProfile(profile.copyWith(joinAggregate: value));
      return;
    }
    final memberIds = [...active.memberIds];
    if (value) {
      if (!memberIds.contains(profile.id)) memberIds.add(profile.id);
    } else {
      memberIds.remove(profile.id);
    }
    final aggregates = globalState.config.aggregates
        .map(
          (item) => item.id == active.id
              ? item.copyWith(memberIds: memberIds)
              : item,
        )
        .toList();
    final config = globalState.config.copyWith(aggregates: aggregates);
    globalState.config = config;
    preferences.saveConfig(config);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  Config _withAggregateSettings({
    AggregateMode? mode,
    AggregateScriptTiming? timing,
    bool? nodes,
    bool? groups,
    bool? rules,
    bool? ruleProviders,
    bool? memberScripts,
    bool? nodeOverrides,
    OverrideData? overrideData,
  }) {
    final current = globalState.config;
    final active = current.currentAggregate;
    if (active == null) {
      return current.copyWith(
        aggregateMode: mode ?? current.aggregateMode,
        aggregateScriptTiming: timing ?? current.aggregateScriptTiming,
        aggregateMergeNodes: nodes ?? current.aggregateMergeNodes,
        aggregateMergeGroups: groups ?? current.aggregateMergeGroups,
        aggregateMergeRules: rules ?? current.aggregateMergeRules,
        aggregateMergeRuleProviders:
            ruleProviders ?? current.aggregateMergeRuleProviders,
        aggregateMergeMemberScripts:
            memberScripts ?? current.aggregateMergeMemberScripts,
        aggregateApplyNodeOverrides:
            nodeOverrides ?? current.aggregateApplyNodeOverrides,
        aggregateOverrideData:
            overrideData ?? current.aggregateOverrideData,
      );
    }
    final updated = active.copyWith(
      mode: mode ?? active.mode,
      scriptTiming: timing ?? active.scriptTiming,
      mergeNodes: nodes ?? active.mergeNodes,
      mergeGroups: groups ?? active.mergeGroups,
      mergeRules: rules ?? active.mergeRules,
      mergeRuleProviders: ruleProviders ?? active.mergeRuleProviders,
      mergeMemberScripts: memberScripts ?? active.mergeMemberScripts,
      applyNodeOverrides: nodeOverrides ?? active.applyNodeOverrides,
      overrideData: overrideData ?? active.overrideData,
    );
    return current.copyWith(
      aggregates: current.aggregates
          .map((item) => item.id == active.id ? updated : item)
          .toList(),
    );
  }

  Future<void> _setMode(AggregateMode mode) async {
    if (globalState.config.effectiveAggregateMode == mode) return;
    final next = _withAggregateSettings(mode: mode);
    globalState.config = next;
    await preferences.saveConfig(next);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  Future<void> _setScriptTiming(AggregateScriptTiming timing) async {
    if (globalState.config.effectiveScriptTiming == timing) return;
    final next = _withAggregateSettings(timing: timing);
    globalState.config = next;
    await preferences.saveConfig(next);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  Future<void> _setCustomOption({
    bool? nodes,
    bool? groups,
    bool? rules,
    bool? ruleProviders,
    bool? memberScripts,
    bool? nodeOverrides,
  }) async {
    final next = _withAggregateSettings(
      nodes: nodes,
      groups: groups,
      rules: rules,
      ruleProviders: ruleProviders,
      memberScripts: memberScripts,
      nodeOverrides: nodeOverrides,
    );
    globalState.config = next;
    await preferences.saveConfig(next);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  Future<void> _setAggregateOverride({
    bool? enable,
    OverrideRuleType? type,
  }) async {
    final current = globalState.config;
    final override = current.effectiveAggregateOverride;
    final next = override.copyWith(
      enable: enable ?? override.enable,
      rule: type == null ? override.rule : override.rule.copyWith(type: type),
    );
    final config = _withAggregateSettings(overrideData: next);
    globalState.config = config;
    await preferences.saveConfig(config);
    globalState.appController.applyProfileDebounce(silence: true);
    if (mounted) setState(() {});
  }

  Future<void> _editAggregateOverrideRules() async {
    final override = globalState.config.effectiveAggregateOverride;
    final controller = TextEditingController(
      text: override.rule.rules.map((rule) => rule.value).join('\n'),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(appLocalizations.aggregateOverride),
          content: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 16,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'DOMAIN,example.com,DIRECT',
              helperText: appLocalizations.aggregateOverrideHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                final rules = controller.text
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .map(Rule.value)
                    .toList();
                final current = globalState.config;
                final override = current.effectiveAggregateOverride;
                final next = override.copyWith(
                  rule: override.rule.updateRules((_) => rules),
                );
                final config = _withAggregateSettings(overrideData: next);
                globalState.config = config;
                await preferences.saveConfig(config);
                globalState.appController.applyProfileDebounce(silence: true);
                if (mounted) setState(() {});
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(appLocalizations.save),
            ),
          ],
        );
      },
    );
  }

  bool _hasDuplicateAliases(String currentProfileId) {
    final seen = <String>{};
    for (final profile in profiles) {
      if (profile.id == currentProfileId || !_isMember(profile)) continue;
      final alias = profile.aggregateAlias.isNotEmpty
          ? profile.aggregateAlias
          : (profile.label ?? profile.id);
      if (!seen.add(alias.toLowerCase())) return true;
    }
    return false;
  }

  void _fixDuplicateAliases(String currentProfileId) {
    final used = <String>{};
    var changed = false;
    for (var index = 0; index < profiles.length; index++) {
      final profile = profiles[index];
      if (profile.id == currentProfileId || !_isMember(profile)) continue;
      final preferred = profile.aggregateAlias.isNotEmpty
          ? profile.aggregateAlias
          : (profile.label ?? profile.id);
      final unique = uniqueAggregateAlias(preferred, used);
      if (profile.aggregateAlias != unique) {
        profiles[index] = profile.copyWith(aggregateAlias: unique);
        changed = true;
      }
    }
    if (!changed) return;
    globalState.appController.setProfiles(profiles);
    globalState.appController.applyProfileDebounce(silence: true);
    globalState.showNotifier(appLocalizations.aggregateFixAliasesDone);
    if (mounted) setState(() {});
  }

  void _reorderProfiles(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      final profile = profiles.removeAt(oldIndex);
      profiles.insert(newIndex, profile);
    });
    globalState.appController.setProfiles(profiles);
    globalState.appController.applyProfileDebounce(silence: true);
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
      if (profile.id == currentProfileId || !_isMember(profile)) continue;
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

  Widget _memberTile(
    BuildContext context,
    Profile profile,
    bool isCurrent,
    int index,
  ) {
    final isMember = _isMember(profile);
    final stats = _stats[profile.id];
    final failed = stats?.failed == true;
    final updated = profile.lastUpdateDate;
    final statsText = stats == null
        ? (_loadingStats ? '…' : appLocalizations.aggregateStatsFailed)
        : failed
        ? appLocalizations.aggregateStatsFailed
        : appLocalizations.aggregateStats(
            stats.nodes,
            stats.groups,
            stats.rules,
          );
    final subtitle = updated == null
        ? statsText
        : '$statsText · ${appLocalizations.aggregateLastUpdated(updated.show)}';
    return Padding(
      key: ValueKey(profile.id),
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
                        style: context.textTheme.labelSmall?.toLight.copyWith(
                          color: failed
                              ? context.colorScheme.error
                              : null,
                        ),
                      ),
                      if (failed && stats?.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            stats!.error!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.labelSmall?.toLight
                                .copyWith(color: context.colorScheme.error),
                          ),
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
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
              if (globalState.config.scriptProps.scripts.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: globalState.config.scriptProps.scripts.any(
                        (script) => script.id == profile.scriptId,
                      )
                      ? profile.scriptId!
                      : '',
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: appLocalizations.aggregateMemberScript,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        appLocalizations.aggregateFollowGlobalScript,
                      ),
                    ),
                    for (final script in globalState.config.scriptProps.scripts)
                      DropdownMenuItem(
                        value: script.id,
                        child: Text(
                          script.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => _replaceProfile(
                    profile.copyWith(
                      scriptId: value == null || value.isEmpty ? null : value,
                    ),
                  ),
                ),
              ],
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
    final selected = globalState.config.effectiveAggregateMode == mode;
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

  String _scriptCoverageText(String currentProfileId) {
    final currentProfile = _profileById(currentProfileId);
    final scriptEnabled =
        globalState.config.scriptProps.currentScript != null &&
        (currentProfile?.useScriptOverride ?? false);
    if (!scriptEnabled) return appLocalizations.aggregateScriptOff;
    var nodes = 0;
    for (final profile in profiles) {
      if (profile.id != currentProfileId && !_isMember(profile)) continue;
      nodes += _stats[profile.id]?.nodes ?? 0;
    }
    final afterMerge =
        (globalState.config.effectiveAggregateMode == AggregateMode.full ||
            globalState.config.effectiveAggregateMode == AggregateMode.custom) &&
        globalState.config.effectiveScriptTiming ==
            AggregateScriptTiming.after;
    if (!afterMerge) {
      nodes = _stats[currentProfileId]?.nodes ?? 0;
    }
    return appLocalizations.aggregateScriptSees(nodes);
  }

  Future<void> _showEffectivePreview() async {
    if (_buildingPreview) return;
    final profile = globalState.config.currentProfile;
    if (profile == null) {
      globalState.showNotifier(appLocalizations.aggregatePreviewFailed);
      return;
    }
    setState(() => _buildingPreview = true);
    try {
      final sourceConfig = await globalState.getProfileConfig(
        profile.id,
        applyNodeOverrides: false,
      );
      final sourceYaml = await encodeYamlTask(sourceConfig);
      final raw = await globalState.patchRawConfig(
        patchConfig: globalState.config.patchClashConfig,
        profile: profile,
      );
      if (raw.isEmpty) throw StateError('empty config');
      final yaml = await encodeYamlTask(raw);
      final proxies = raw['proxies'];
      final groups = raw['proxy-groups'];
      final rules = raw['rules'];
      final groupNames = groups is List
          ? groups
                .whereType<Map>()
                .map((group) => group['name'])
                .whereType<String>()
                .toList()
          : <String>[];
      final proxyNames = proxies is List
          ? proxies
                .whereType<Map>()
                .map((proxy) => proxy['name'])
                .whereType<String>()
                .toList()
          : <String>[];
      final ruleStrings = rules is List
          ? rules.whereType<String>().toList()
          : <String>[];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(appLocalizations.aggregatePreviewTitle),
            content: SizedBox(
              width: double.maxFinite,
              height: 480,
              child: DefaultTabController(
                length: 6,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: appLocalizations.aggregatePreviewOverview),
                        Tab(text: appLocalizations.aggregatePreviewNodes),
                        Tab(text: appLocalizations.aggregatePreviewGroups),
                        Tab(text: appLocalizations.aggregatePreviewRules),
                        Tab(
                          text: appLocalizations.aggregatePreviewSourceYaml,
                        ),
                        Tab(text: appLocalizations.aggregatePreviewYaml),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView(
                            children: [
                              Text(
                                appLocalizations.aggregateStats(
                                  proxyNames.length,
                                  groupNames.length,
                                  ruleStrings.length,
                                ),
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                appLocalizations.aggregatePreviewHint,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                appLocalizations.aggregatePreviewSensitive,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        dialogContext,
                                      ).colorScheme.error,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                appLocalizations.aggregateConflicts,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleSmall,
                              ),
                              const SizedBox(height: 6),
                              if (globalState.lastAggregateMergeReport ==
                                      null ||
                                  globalState
                                      .lastAggregateMergeReport!
                                      .isEmpty)
                                Text(appLocalizations.aggregateNoConflicts)
                              else ...[
                                for (final rename
                                    in globalState
                                        .lastAggregateMergeReport!
                                        .groupRenames
                                        .take(8))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      appLocalizations.aggregateGroupRenamed(
                                        rename.from,
                                        rename.to,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (globalState
                                    .lastAggregateMergeReport!
                                    .droppedRules
                                    .isNotEmpty)
                                  Text(
                                    appLocalizations.aggregateDroppedRules(
                                      globalState
                                          .lastAggregateMergeReport!
                                          .droppedRules
                                          .length,
                                    ),
                                  ),
                                if (globalState
                                    .lastAggregateMergeReport!
                                    .droppedGroupProxies
                                    .isNotEmpty)
                                  Text(
                                    appLocalizations.aggregateDroppedProxies(
                                      globalState
                                          .lastAggregateMergeReport!
                                          .droppedGroupProxies
                                          .length,
                                    ),
                                  ),
                                if (globalState
                                    .lastAggregateMergeReport!
                                    .skippedProviders
                                    .isNotEmpty)
                                  Text(
                                    appLocalizations.aggregateSkippedProviders(
                                      globalState
                                          .lastAggregateMergeReport!
                                          .skippedProviders
                                          .length,
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 14),
                              Text(
                                appLocalizations.aggregateDiff,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleSmall,
                              ),
                              const SizedBox(height: 6),
                              if (globalState.lastAggregateConfigDiff ==
                                      null ||
                                  globalState
                                      .lastAggregateConfigDiff!
                                      .isEmpty)
                                Text(appLocalizations.aggregateNoDiff)
                              else ...[
                                Text(
                                  appLocalizations.aggregateDiffNodes(
                                    globalState
                                        .lastAggregateConfigDiff!
                                        .addedNodes
                                        .length,
                                    globalState
                                        .lastAggregateConfigDiff!
                                        .removedNodes
                                        .length,
                                  ),
                                ),
                                Text(
                                  appLocalizations.aggregateDiffGroups(
                                    globalState
                                        .lastAggregateConfigDiff!
                                        .addedGroups
                                        .length,
                                    globalState
                                        .lastAggregateConfigDiff!
                                        .removedGroups
                                        .length,
                                  ),
                                ),
                                Text(
                                  appLocalizations.aggregateDiffRules(
                                    globalState
                                        .lastAggregateConfigDiff!
                                        .addedRules
                                        .length,
                                    globalState
                                        .lastAggregateConfigDiff!
                                        .removedRules
                                        .length,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          ListView(
                            children: [
                              for (final name in proxyNames.take(300))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          ListView(
                            children: [
                              for (final name in groupNames.take(300))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          ListView(
                            children: [
                              for (final rule in ruleStrings.take(300))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    rule,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  appLocalizations.aggregatePreviewSensitive,
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          dialogContext,
                                        ).colorScheme.error,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Scrollbar(
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      sourceYaml,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  appLocalizations.aggregatePreviewSensitive,
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          dialogContext,
                                        ).colorScheme.error,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Scrollbar(
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      yaml,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: yaml));
                  globalState.showNotifier(appLocalizations.copySuccess);
                },
                child: Text(appLocalizations.copy),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(appLocalizations.close),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        globalState.showNotifier(
          '${appLocalizations.aggregatePreviewFailed}: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _buildingPreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProfileId = globalState.config.currentProfileId ?? '';
    final activeAggregate = _activeAggregate;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, appLocalizations.aggregateProfiles),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(activeAggregate?.id ?? ''),
                initialValue: activeAggregate?.id ?? '',
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(appLocalizations.aggregateDefault),
                  ),
                  for (final aggregate in globalState.config.aggregates)
                    DropdownMenuItem(
                      value: aggregate.id,
                      child: Text(
                        aggregate.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _selectAggregate,
              ),
            ),
            IconButton(
              tooltip: appLocalizations.aggregateNew,
              onPressed: () => _editAggregateName(),
              icon: const Icon(Icons.add),
            ),
            if (activeAggregate != null) ...[
              IconButton(
                tooltip: appLocalizations.aggregateRename,
                onPressed: () =>
                    _editAggregateName(aggregate: activeAggregate),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: appLocalizations.aggregateDelete,
                onPressed: _deleteAggregate,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          appLocalizations.aggregateSharedSettings,
          style: context.textTheme.labelSmall?.toLight,
        ),
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
        _modeCard(
          context,
          mode: AggregateMode.custom,
          icon: Icons.tune,
          title: appLocalizations.aggregateCustom,
          description: appLocalizations.aggregateCustomDesc,
        ),
        if (globalState.config.effectiveAggregateMode == AggregateMode.custom) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(appLocalizations.aggregateMergeNodes),
            value: globalState.config.effectiveMergeNodes,
            onChanged: (value) => _setCustomOption(nodes: value),
          ),
          if (!globalState.config.effectiveMergeNodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                appLocalizations.aggregateNodesOffHint,
                style: context.textTheme.labelSmall?.toLight,
              ),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(appLocalizations.aggregateMergeGroups),
            value: globalState.config.effectiveMergeGroups,
            onChanged: (value) => _setCustomOption(groups: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(appLocalizations.aggregateMergeRules),
            value: globalState.config.effectiveMergeRules,
            onChanged: (value) => _setCustomOption(rules: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(appLocalizations.aggregateMergeRuleProviders),
            value: globalState.config.effectiveMergeRuleProviders,
            onChanged: (value) => _setCustomOption(ruleProviders: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(appLocalizations.aggregateMergeMemberScripts),
            value: globalState.config.effectiveMergeMemberScripts,
            onChanged: (value) => _setCustomOption(memberScripts: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(appLocalizations.aggregateApplyNodeOverrides),
            value: globalState.config.effectiveApplyNodeOverrides,
            onChanged: (value) => _setCustomOption(nodeOverrides: value),
          ),
        ],
        if (globalState.config.effectiveAggregateMode == AggregateMode.full ||
            globalState.config.effectiveAggregateMode == AggregateMode.custom) ...[
          _sectionTitle(context, appLocalizations.aggregateScriptTiming),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(appLocalizations.aggregateScriptBefore),
                selected:
                    globalState.config.effectiveScriptTiming ==
                    AggregateScriptTiming.before,
                onSelected: (_) =>
                    _setScriptTiming(AggregateScriptTiming.before),
              ),
              ChoiceChip(
                label: Text(appLocalizations.aggregateScriptAfter),
                selected:
                    globalState.config.effectiveScriptTiming ==
                    AggregateScriptTiming.after,
                onSelected: (_) =>
                    _setScriptTiming(AggregateScriptTiming.after),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            globalState.config.effectiveScriptTiming ==
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
        _sectionTitle(context, appLocalizations.aggregateOverride),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(appLocalizations.aggregateOverride),
          subtitle: Text(appLocalizations.aggregateOverrideHint),
          value: globalState.config.effectiveAggregateOverride.enable,
          onChanged: (value) => _setAggregateOverride(enable: value),
        ),
        if (globalState.config.effectiveAggregateOverride.enable) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(appLocalizations.overrideOriginRules),
                selected:
                    globalState.config.effectiveAggregateOverride.rule.type ==
                    OverrideRuleType.override,
                onSelected: (_) =>
                    _setAggregateOverride(type: OverrideRuleType.override),
              ),
              ChoiceChip(
                label: Text(appLocalizations.addedOriginRules),
                selected:
                    globalState.config.effectiveAggregateOverride.rule.type ==
                    OverrideRuleType.added,
                onSelected: (_) =>
                    _setAggregateOverride(type: OverrideRuleType.added),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _editAggregateOverrideRules,
              icon: const Icon(Icons.edit_note),
              label: Text(
                '${appLocalizations.rule} (${globalState.config.effectiveAggregateOverride.rule.rules.length})',
              ),
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                context,
                appLocalizations.aggregateMembers,
              ),
            ),
            IconButton(
              tooltip: appLocalizations.refresh,
              onPressed: _loadingStats ? null : _loadStats,
              icon: _loadingStats
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_hasDuplicateAliases(currentProfileId))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _fixDuplicateAliases(currentProfileId),
              icon: const Icon(Icons.build_outlined),
              label: Text(appLocalizations.aggregateFixAliases),
            ),
          ),
      ],
    );
    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_memberAliases(currentProfileId).isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              appLocalizations.aggregateNoMembers,
              style: context.textTheme.bodyMedium?.toLight,
            ),
          ),
        if (!_loadingStats && _stats.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _scriptCoverageText(currentProfileId),
            style: context.textTheme.labelSmall?.toLight,
          ),
        ],
        _sectionTitle(context, appLocalizations.aggregateTitle),
        _card(context, _preview(context, currentProfileId)),
        const SizedBox(height: 10),
        Text(
          appLocalizations.aggregatePreviewNote,
          style: context.textTheme.labelSmall?.toLight,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _buildingPreview ? null : _showEffectivePreview,
            icon: _buildingPreview
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.description_outlined),
            label: Text(appLocalizations.aggregatePreviewTitle),
          ),
        ),
      ],
    );
    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      buildDefaultDragHandles: false,
      onReorderItem: _reorderProfiles,
      header: header,
      footer: footer,
      children: [
        for (var index = 0; index < profiles.length; index++)
          _memberTile(
            context,
            profiles[index],
            profiles[index].id == currentProfileId,
            index,
          ),
      ],
    );
  }
}
