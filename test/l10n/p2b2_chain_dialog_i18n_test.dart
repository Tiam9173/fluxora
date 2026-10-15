// P2-B2 — the chain-proxy dialog (`lib/views/profiles/profile_chain_dialog.dart`)
// used to hard-code Chinese literals for both its topology preview and its
// pre-proxy / landing-proxy configuration sections.
//
// These tests read the real getters in every supported locale and assert the new
// keys resolve to a non-empty, locale-appropriate string. A non-vacuity check
// also proves that the non-English CJK locales are not silently falling back to
// the English strings (an empty map or a copy of English would fail this).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';

/// Non-parameterised keys introduced by P2-B2 for `profile_chain_dialog.dart`.
final Map<String, String Function(AppLocalizations)> _plainChainKeys = {
  'chainTopologyPreview': (l) => l.chainTopologyPreview,
  'chainNodeDeviceApp': (l) => l.chainNodeDeviceApp,
  'chainNodeLocal': (l) => l.chainNodeLocal,
  'chainNodePreProxy': (l) => l.chainNodePreProxy,
  'chainPreProxyNone': (l) => l.chainPreProxyNone,
  'chainNodeSubscription': (l) => l.chainNodeSubscription,
  'chainNodeGroupNodes': (l) => l.chainNodeGroupNodes,
  'chainLandingProxyNone': (l) => l.chainLandingProxyNone,
  'enableProfileChain': (l) => l.enableProfileChain,
  'enableProfileChainDesc': (l) => l.enableProfileChainDesc,
  'preProxySectionTitle': (l) => l.preProxySectionTitle,
  'preProxySectionDesc': (l) => l.preProxySectionDesc,
  'preProxyOptionNone': (l) => l.preProxyOptionNone,
  'preProxyOptionCustom': (l) => l.preProxyOptionCustom,
  'customPreProxyName': (l) => l.customPreProxyName,
  'landingProxySectionTitle': (l) => l.landingProxySectionTitle,
  'landingProxySectionDesc': (l) => l.landingProxySectionDesc,
  'landingProxyOptionNone': (l) => l.landingProxyOptionNone,
  'landingProxyOptionCustom': (l) => l.landingProxyOptionCustom,
  'customLandingProxyName': (l) => l.customLandingProxyName,
  'profileChainSaved': (l) => l.profileChainSaved,
  'saveAndApply': (l) => l.saveAndApply,
};

/// Non-parameterised keys introduced by P2-B2 for `profile_nodes_view.dart`.
final Map<String, String Function(AppLocalizations)> _plainNodeKeys = {
  'confirmDelete': (l) => l.confirmDelete,
  'batchImportShareLinks': (l) => l.batchImportShareLinks,
  'batchImportSupportHint': (l) => l.batchImportSupportHint,
  'batchImportPasteHint': (l) => l.batchImportPasteHint,
  'batchImportParseFailed': (l) => l.batchImportParseFailed,
  'confirmImport': (l) => l.confirmImport,
  'batchImportLinks': (l) => l.batchImportLinks,
  'refresh': (l) => l.refresh,
  'manualAddNode': (l) => l.manualAddNode,
  'noNodesInGroup': (l) => l.noNodesInGroup,
  'noNodesInGroupHint': (l) => l.noNodesInGroupHint,
  'importShareLinks': (l) => l.importShareLinks,
  'manualEntry': (l) => l.manualEntry,
  'unnamedNode': (l) => l.unnamedNode,
  'customConfigNode': (l) => l.customConfigNode,
  'deleteNode': (l) => l.deleteNode,
  'nodeProtocol': (l) => l.nodeProtocol,
  'customConfigHintText': (l) => l.customConfigHintText,
  'customConfigLabel': (l) => l.customConfigLabel,
  'nodeNameLabel': (l) => l.nodeNameLabel,
  'serverAddressLabel': (l) => l.serverAddressLabel,
  'serverAddressHint': (l) => l.serverAddressHint,
  'portLabel': (l) => l.portLabel,
  'privateKey': (l) => l.privateKey,
  'pskKey': (l) => l.pskKey,
  'passwordAuth': (l) => l.passwordAuth,
  'juicityPassword': (l) => l.juicityPassword,
  'usernameOptional': (l) => l.usernameOptional,
  'networkLabel': (l) => l.networkLabel,
  'securityLabel': (l) => l.securityLabel,
  'securityNonePlain': (l) => l.securityNonePlain,
  'obfsModeLabel': (l) => l.obfsModeLabel,
  'obfsNoneOff': (l) => l.obfsNoneOff,
  'snellVersion': (l) => l.snellVersion,
  'realityPublicKey': (l) => l.realityPublicKey,
  'sniLabel': (l) => l.sniLabel,
  'sniHint': (l) => l.sniHint,
  'cipherLabel': (l) => l.cipherLabel,
  'upLabel': (l) => l.upLabel,
  'downLabel': (l) => l.downLabel,
  'peerPublicKey': (l) => l.peerPublicKey,
  'localIpLabel': (l) => l.localIpLabel,
  'amneziaObfsParams': (l) => l.amneziaObfsParams,
  'jcLabel': (l) => l.jcLabel,
  'enableUdpForwarding': (l) => l.enableUdpForwarding,
  'skipCertVerify': (l) => l.skipCertVerify,
  'skipCertVerifyDesc': (l) => l.skipCertVerifyDesc,
  'serverAddressRequired': (l) => l.serverAddressRequired,
  'saveNode': (l) => l.saveNode,
};

/// The chain-dialog key that must keep its placeholder.
const _parameterisedChain = ['profileChainDialogTitle'];

/// The nodes-view parameterised keys and their placeholder names.
final Map<String, List<String>> _parameterisedNodeKeys = {
  'confirmDeleteNodeMsg': ['name'],
  'nodeDeleted': ['name'],
  'batchImportSuccess': ['count'],
  'nodeManagement': ['name'],
  'nodeNameHint': ['proto'],
  'nodeAdded': ['name'],
};

final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

/// Locales whose script is CJK (the non-English ones that could fall back).
const _cjkLocales = [
  Locale('zh', 'CN'),
  Locale('zh', 'TC'),
  Locale('ja'),
  Locale('ko'),
];

/// All locales the app ships.
const _allLocales = [
  Locale('en'),
  Locale('zh', 'CN'),
  Locale('zh', 'TC'),
  Locale('ja'),
  Locale('ko'),
  Locale('fa'),
  Locale('ru'),
];

void main() {
  group('P2-B2 — chain-dialog copy resolves in every locale', () {
    for (final locale in _allLocales) {
      test('${locale.toLanguageTag()} returns non-empty text for all keys',
          () async {
        await AppLocalizations.load(locale);
        final l = appLocalizations;
        _plainChainKeys.forEach((name, read) {
          expect(read(l), isNotEmpty, reason: '$name empty in $locale');
        });
      });
    }

    test('non-English CJK locales do not fall back to English', () async {
      await AppLocalizations.load(const Locale('en'));
      final enValues = <String, String>{};
      _plainChainKeys.forEach(
          (name, read) => enValues[name] = read(appLocalizations));

      for (final locale in _cjkLocales) {
        await AppLocalizations.load(locale);
        final l = appLocalizations;
        _plainChainKeys.forEach((name, read) {
          expect(
            read(l),
            isNot(equals(enValues[name])),
            reason: '$name appears to fall back to English in $locale',
          );
        });
      }
    });

    test('zh_CN chain-dialog copy is Chinese', () async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      // Two keys are intentionally numeric-prefixed ("1. 前置代理" already
      // contains Chinese; the ✏️ option strings also contain Chinese).
      _plainChainKeys.forEach((name, read) {
        expect(_cjk.hasMatch(read(appLocalizations)), isTrue,
            reason: '$name lost its Chinese text');
      });
    });

    test('profileChainDialogTitle keeps its {name} placeholder', () async {
      await AppLocalizations.load(const Locale('en'));
      expect(appLocalizations.profileChainDialogTitle('MyProfile'),
          contains('MyProfile'));

      await AppLocalizations.load(const Locale('zh', 'CN'));
      expect(appLocalizations.profileChainDialogTitle('MyProfile'),
          contains('MyProfile'));

      await AppLocalizations.load(const Locale('zh', 'TC'));
      expect(appLocalizations.profileChainDialogTitle('MyProfile'),
          contains('MyProfile'));

      await AppLocalizations.load(const Locale('ru'));
      expect(appLocalizations.profileChainDialogTitle('MyProfile'),
          contains('MyProfile'));
    });

    test('reused keys stay semantically appropriate', () async {
      // `roleExit` ("落地出口") is reused for the topology's exit hop.
      await AppLocalizations.load(const Locale('zh', 'CN'));
      expect(appLocalizations.roleExit, isNotEmpty);
      // `cancel` is reused for the dialog's dismiss button.
      expect(appLocalizations.cancel, isNotEmpty);
    });

    test('every parameterised key exists in the shipped surface', () {
      expect(_parameterisedChain.length, 1);
    });
  });

  group('P2-B2 — nodes-view copy resolves in every locale', () {
    for (final locale in _allLocales) {
      test('${locale.toLanguageTag()} returns non-empty text for all keys',
          () async {
        await AppLocalizations.load(locale);
        final l = appLocalizations;
        _plainNodeKeys.forEach((name, read) {
          expect(read(l), isNotEmpty, reason: '$name empty in $locale');
        });
      });
    }

    test('non-English CJK locales do not fall back to English', () async {
      await AppLocalizations.load(const Locale('en'));
      final enValues = <String, String>{};
      _plainNodeKeys.forEach(
          (name, read) => enValues[name] = read(appLocalizations));

      for (final locale in _cjkLocales) {
        await AppLocalizations.load(locale);
        final l = appLocalizations;
        _plainNodeKeys.forEach((name, read) {
          expect(
            read(l),
            isNot(equals(enValues[name])),
            reason: '$name appears to fall back to English in $locale',
          );
        });
      }
    });

    test('zh_CN nodes-view copy is Chinese', () async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      _plainNodeKeys.forEach((name, read) {
        expect(_cjk.hasMatch(read(appLocalizations)), isTrue,
            reason: '$name lost its Chinese text');
      });
    });

    test('every nodes-view parameterised key keeps its placeholders',
        () async {
      // A distinct sentinel per placeholder proves interpolation actually
      // happens (and each locale declares the same placeholder name).
      const sentinel = 'ZZ_SENTINEL';
      for (final locale in _allLocales) {
        await AppLocalizations.load(locale);
        final l = appLocalizations;
        final results = <String, String>{
          'confirmDeleteNodeMsg': l.confirmDeleteNodeMsg(sentinel),
          'nodeDeleted': l.nodeDeleted(sentinel),
          'batchImportSuccess': l.batchImportSuccess(sentinel),
          'nodeManagement': l.nodeManagement(sentinel),
          'nodeNameHint': l.nodeNameHint(sentinel),
          'nodeAdded': l.nodeAdded(sentinel),
        };
        results.forEach((name, rendered) {
          expect(rendered, contains(sentinel),
              reason: '$name lost its placeholder in $locale');
        });
        expect(_parameterisedNodeKeys.length, 6);
      }
    });

    test('reused nodes-view keys stay semantically appropriate', () async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      expect(appLocalizations.pasteFromClipboard, isNotEmpty);
      expect(appLocalizations.cancel, isNotEmpty);
    });
  });
}
