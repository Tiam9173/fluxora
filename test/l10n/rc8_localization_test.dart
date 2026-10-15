// RC.8 — the three hand-written l10n modules used to be missing from the
// generated English table, so `Intl.message` fell back to its Chinese source
// string for **every** locale. These tests read the real getters (not the key
// list) under both locales.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';

/// Every key defined by the generated l10n tables,
/// read through the real getter.
final Map<String, String Function(AppLocalizations)> _keys = {
  'chainProxy': (l) => l.chainProxy,
  'chainProxyDesc': (l) => l.chainProxyDesc,
  'enableChainProxy': (l) => l.enableChainProxy,
  'enableChainProxyDesc': (l) => l.enableChainProxyDesc,
  'defaultDialerProxy': (l) => l.defaultDialerProxy,
  'defaultDialerProxyDesc': (l) => l.defaultDialerProxyDesc,
  'followMainSelector': (l) => l.followMainSelector,
  'dedicatedGroup': (l) => l.dedicatedGroup,
  'dedicatedGroupDesc': (l) => l.dedicatedGroupDesc,
  'autoInjectGroups': (l) => l.autoInjectGroups,
  'autoInjectGroupsDesc': (l) => l.autoInjectGroupsDesc,
  'preventWebRtcLeak': (l) => l.preventWebRtcLeak,
  'preventWebRtcLeakDesc': (l) => l.preventWebRtcLeakDesc,
  'landingProxies': (l) => l.landingProxies,
  'addLandingProxy': (l) => l.addLandingProxy,
  'quickImport': (l) => l.quickImport,
  'quickImportDesc': (l) => l.quickImportDesc,
  'pasteFromClipboard': (l) => l.pasteFromClipboard,
  'testAll': (l) => l.testAll,
  'emptyLandingTip': (l) => l.emptyLandingTip,
  'nodeName': (l) => l.nodeName,
  'protocol': (l) => l.protocol,
  'serverAddress': (l) => l.serverAddress,
  'port': (l) => l.port,
  'username': (l) => l.username,
  'password': (l) => l.password,
  'cipher': (l) => l.cipher,
  'udpForwarding': (l) => l.udpForwarding,
  'udpForwardingDesc': (l) => l.udpForwardingDesc,
  'specificDialerProxy': (l) => l.specificDialerProxy,
  'inheritDefaultDialer': (l) => l.inheritDefaultDialer,
  'directConnection': (l) => l.directConnection,
  'hop': (l) => l.hop,
  'inputProxyTextHint': (l) => l.inputProxyTextHint,
  'importSuccessCount': (l) => l.importSuccessCount(3),
  'parseNoValidNode': (l) => l.parseNoValidNode,
  'healthCheck': (l) => l.healthCheck,
  'healthCheckAll': (l) => l.healthCheckAll,
  'healthReport': (l) => l.healthReport,
  'testingHealth': (l) => l.testingHealth,
  'healthHealthy': (l) => l.healthHealthy,
  'healthWarning': (l) => l.healthWarning,
  'healthError': (l) => l.healthError,
  'healthUntested': (l) => l.healthUntested,
  'filterAll': (l) => l.filterAll,
  'filterHealthy': (l) => l.filterHealthy,
  'filterError': (l) => l.filterError,
  'clearInvalidProxies': (l) => l.clearInvalidProxies,
  'clearedInvalidCount': (l) => l.clearedInvalidCount(3),
  'noInvalidProxies': (l) => l.noInvalidProxies,
  'testCurrentProxy': (l) => l.testCurrentProxy,
  'testing': (l) => l.testing,
  'batchCheckingProgress': (l) => l.batchCheckingProgress(1, 3),
  'topologyClient': (l) => l.topologyClient,
  'topologyHop': (l) => l.topologyHop,
  'topologyLanding': (l) => l.topologyLanding,
  'topologyTarget': (l) => l.topologyTarget,
  'diagnosticAdvice': (l) => l.diagnosticAdvice,
  'retest': (l) => l.retest,
  'confirmClearInvalid': (l) => l.confirmClearInvalid,
  'chainHopMode': (l) => l.chainHopMode,
  'chainHopModeDesc': (l) => l.chainHopModeDesc,
  'chainHopRelayNode': (l) => l.chainHopRelayNode,
  'chainHopExitNode': (l) => l.chainHopExitNode,
  'chainHopNotSelected': (l) => l.chainHopNotSelected,
  'chainHopIncomplete': (l) => l.chainHopIncomplete,
  'chainHopUnavailable': (l) => l.chainHopUnavailable,
  'topologyRelay': (l) => l.topologyRelay,
  'ascending': (l) => l.ascending,
  'descending': (l) => l.descending,
  'failover': (l) => l.failover,
  'failoverEnableFirst': (l) => l.failoverEnableFirst,
  'failoverNoCandidates': (l) => l.failoverNoCandidates,
  'failoverManualHint': (l) => l.failoverManualHint,
  'autoFailover': (l) => l.autoFailover,
  'autoFailoverOnDesc': (l) => l.autoFailoverOnDesc,
  'autoFailoverOffDesc': (l) => l.autoFailoverOffDesc,
  'failoverTrigger': (l) => l.failoverTrigger,
  'failoverInProgress': (l) => l.failoverInProgress,
  'failoverTriggerReason': (l) => l.failoverTriggerReason,
  'failoverNoCandidatesAdvice': (l) => l.failoverNoCandidatesAdvice,
  'roleEntry': (l) => l.roleEntry,
  'roleRelay': (l) => l.roleRelay,
  'roleExit': (l) => l.roleExit,
  'addRoleCandidate': (l) => l.addRoleCandidate('N'),
  'addRoleFallbackCandidate': (l) => l.addRoleFallbackCandidate('N'),
  'failoverSuccess': (l) => l.failoverSuccess('N'),
  'failoverFailed': (l) => l.failoverFailed('R'),
  'tunActualStatus': (l) => l.tunActualStatus,
  'tunChecking': (l) => l.tunChecking,
  'tunActualOn': (l) => l.tunActualOn,
  'tunActualOff': (l) => l.tunActualOff,
  'tunMismatchOn': (l) => l.tunMismatchOn,
  'tunMismatchOff': (l) => l.tunMismatchOff,
  'tunUnknown': (l) => l.tunUnknown,
  'tunUnsupported': (l) => l.tunUnsupported,
  'systemProxyActualStatus': (l) => l.systemProxyActualStatus,
  'systemProxyChecking': (l) => l.systemProxyChecking,
  'systemProxyActualOn': (l) => l.systemProxyActualOn,
  'systemProxyActualOff': (l) => l.systemProxyActualOff,
  'systemProxyMismatchOn': (l) => l.systemProxyMismatchOn,
  'systemProxyMismatchOff': (l) => l.systemProxyMismatchOff,
  'systemProxyUnknown': (l) => l.systemProxyUnknown,
  'systemProxyUnsupported': (l) => l.systemProxyUnsupported,
};

/// Keys whose English copy intentionally keeps a Chinese proper noun (a real
/// group name in the user's config), so CJK alone is not a failure for them.
const Set<String> _cjkAllowedInEnglish = {'autoInjectGroupsDesc', 'dedicatedGroupDesc'};

final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

void main() {
  group('RC.8 — l10n modules resolve in both locales', () {
    test('under en no key falls back to the Chinese source', () async {
      await AppLocalizations.load(const Locale('en'));
      final l = appLocalizations;

      final leaked = <String>[];
      _keys.forEach((name, read) {
        if (_cjkAllowedInEnglish.contains(name)) return;
        final value = read(l);
        if (_cjk.hasMatch(value)) leaked.add('$name => "$value"');
      });

      expect(
        leaked,
        isEmpty,
        reason: 'these keys still render the Chinese source under en: $leaked',
      );
    });

    test('under zh_CN the same keys stay Chinese', () async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      final l = appLocalizations;

      final notChinese = <String>[];
      _keys.forEach((name, read) {
        if (!_cjk.hasMatch(read(l))) notChinese.add(name);
      });

      expect(
        notChinese,
        isEmpty,
        reason: 'these keys lost their Chinese text: $notChinese',
      );
    });

    test('parameterized keys interpolate in both locales', () async {
      await AppLocalizations.load(const Locale('en'));
      expect(appLocalizations.failoverSuccess('Node-A'), contains('Node-A'));
      expect(appLocalizations.failoverFailed('pool empty'), contains('pool empty'));
      expect(appLocalizations.addRoleCandidate('Entry'), contains('Entry'));
      expect(appLocalizations.importSuccessCount(3), contains('3'));
      expect(appLocalizations.batchCheckingProgress(1, 3), contains('1/3'));

      await AppLocalizations.load(const Locale('zh', 'CN'));
      expect(appLocalizations.failoverSuccess('Node-A'), contains('Node-A'));
      expect(appLocalizations.failoverFailed('pool empty'), contains('pool empty'));
      expect(appLocalizations.batchCheckingProgress(1, 3), contains('1/3'));
    });

    test('switching the locale changes the rendered copy', () async {
      await AppLocalizations.load(const Locale('en'));
      final en = appLocalizations.chainProxy;

      await AppLocalizations.load(const Locale('zh', 'CN'));
      final zh = appLocalizations.chainProxy;

      expect(en, isNot(equals(zh)));
      expect(_cjk.hasMatch(zh), isTrue);
      expect(_cjk.hasMatch(en), isFalse);
    });
  });

  // RC.10 — `domain` used to be defined twice with different values (a DNS
  // filter label and an IP-detail label). The DNS side now has its own
  // `domainName` key, so `domain` keeps the IP-detail copy.
  group('RC.10 — domain / domainName resolve to distinct labels', () {
    test('en', () async {
      await AppLocalizations.load(const Locale('en'));
      expect(appLocalizations.domainName, 'Domain');
      expect(appLocalizations.domain, 'Organization / Domain');
    });

    test('zh_CN', () async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      expect(appLocalizations.domainName, '域名');
      expect(appLocalizations.domain, '组织 / 域名');
    });

    test('zh_TC', () async {
      await AppLocalizations.load(const Locale('zh', 'TC'));
      expect(appLocalizations.domainName, '網域');
      expect(appLocalizations.domain, '組織 / 域名');
    });
  });

  // RC.10 — the zh_TC table defined `script` twice (`腳本` / `指令碼`). Only the
  // `腳本` copy is kept, matching `scriptDesc` and `pleaseEnterScriptName`.
  group('RC.10 — zh_TC script keeps 腳本', () {
    test('zh_TC', () async {
      await AppLocalizations.load(const Locale('zh', 'TC'));
      expect(appLocalizations.script, '腳本');
    });
  });
}
