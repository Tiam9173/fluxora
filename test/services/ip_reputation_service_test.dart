
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/ip_reputation.dart';
import 'package:fluxora/services/ip_reputation_service.dart';

/// P4 — the IP reputation contract.
///
/// These are offline tests of the pure `parse` mapping: they pin the E-4
/// tri-state ("no data" is never "clear"), the E-5 failure taxonomy (failure is
/// never a clean result), and the deliberate absence of a composite score.
void main() {
  final service = IpReputationService();

  Map<String, dynamic> fullBody({
    Map<String, dynamic>? flags,
    Object? blocklists,
    Object? abuse,
    Object? unknowns,
    bool stale = false,
    String source = 'fresh',
  }) => {
    'ip': '203.0.113.7',
    'version': 4,
    'queriedAt': '2026-10-16T05:00:00.000Z',
    'source': source,
    'stale': stale,
    'usageType': 'hosting',
    'nativeType': 'broadcast',
    'flags':
        flags ??
        {
          'isProxy': true,
          'isVpn': false,
          'isTor': false,
          'isHosting': true,
          'isMobile': false,
          'isRelay': false,
          'isBogon': false,
          'isSearchEngineBot': false,
        },
    'asn': {'asn': 139341, 'name': 'ACE-AS-AP', 'org': 'Aceville Pte.ltd'},
    'risk': {
      'purity': 12,
      'verdict': 'dangerous',
      'factors': [
        {'id': 'native', 'label': 'native-ip', 'points': -5},
        {'id': 'rdns:missing', 'label': 'no-rdns', 'points': 5},
      ],
    },
    'scenarios': const [],
    'sources': const [],
    'blocklists': blocklists ?? const [],
    'abuse': abuse ?? const [],
    'unknowns': unknowns ?? const [],
    'reportUrl': 'https://ipure.dev/ip/203.0.113.7',
  };

  IpRiskMarker marker(IpReputation r, String id) =>
      r.markers.firstWhere((m) => m.id == id);

  group('P4 — success mapping', () {
    test('maps the independent markers from `flags`', () {
      final r = service.parse('203.0.113.7', 200, fullBody());

      expect(r.status, IpReputationStatus.ok);
      expect(r.isOk, isTrue);
      expect(r.ip, '203.0.113.7');
      expect(r.source, 'fresh');
      expect(r.stale, isFalse);
      expect(r.queriedAt, isNotNull);

      expect(marker(r, 'proxy').state, IpRiskMarkerState.flagged);
      expect(marker(r, 'hosting').state, IpRiskMarkerState.flagged);
      // `false` from the source is an affirmative "no", so it is `clear`.
      expect(marker(r, 'vpn').state, IpRiskMarkerState.clear);
      expect(marker(r, 'tor').state, IpRiskMarkerState.clear);
      expect(r.hasFlaggedMarker, isTrue);
      expect(r.unknownMarkers, isEmpty);
    });

    test('maps asn / usageType / nativeType / reportUrl', () {
      final r = service.parse('203.0.113.7', 200, fullBody());

      expect(r.asn, 'AS139341');
      expect(r.asnOrg, 'Aceville Pte.ltd');
      expect(r.usageType, 'hosting');
      expect(r.nativeType, 'broadcast');
      expect(r.reportUrl, 'https://ipure.dev/ip/203.0.113.7');
    });

    test('a stale store report keeps both flags', () {
      final r = service.parse(
        '203.0.113.7',
        200,
        fullBody(stale: true, source: 'store'),
      );

      expect(r.stale, isTrue);
      expect(r.source, 'store');
    });
  });

  group('P4 — E-4: missing data is unknown, never clear', () {
    test('a marker the source omits becomes unknown, not clear', () {
      final r = service.parse(
        '203.0.113.7',
        200,
        fullBody(flags: {'isVpn': true}),
      );

      expect(marker(r, 'vpn').state, IpRiskMarkerState.flagged);
      for (final id in const ['proxy', 'tor', 'hosting', 'relay']) {
        expect(
          marker(r, id).state,
          IpRiskMarkerState.unknown,
          reason: '$id must be unknown when the source is silent',
        );
      }
      // The silent markers are surfaced, not dropped.
      expect(r.unknownMarkers.length, IpReputationService.markerIds.length - 1);
    });

    test('every marker is present even with no flags object at all', () {
      final r = service.parse('203.0.113.7', 200, fullBody(flags: null)..remove('flags'));

      expect(r.markers.length, IpReputationService.markerIds.length);
      expect(
        r.markers.every((m) => m.state == IpRiskMarkerState.unknown),
        isTrue,
      );
      expect(r.hasFlaggedMarker, isFalse);
    });

    test('absent abuse data stays null — not a zero score', () {
      final r = service.parse('203.0.113.7', 200, fullBody());

      expect(r.abuseScore, isNull);
      expect(r.abuseReports, isNull);
    });

    test('abuse score and reports are summed across sources', () {
      final r = service.parse(
        '203.0.113.7',
        200,
        fullBody(
          abuse: [
            {'source': 'a', 'score': 30, 'reports': 4},
            {'source': 'b', 'score': 10, 'reports': 2},
          ],
        ),
      );

      expect(r.abuseScore, 30);
      expect(r.abuseReports, 6);
    });
  });

  group('P4 — blocklists only count genuine hits', () {
    test('listed and non-benign and available counts', () {
      final r = service.parse(
        '203.0.113.7',
        200,
        fullBody(
          blocklists: [
            {'zone': 'zen.spamhaus.org', 'label': 'Spamhaus ZEN', 'listed': true, 'benign': false, 'unavailable': false},
          ],
        ),
      );

      expect(r.blocklistsHit, ['Spamhaus ZEN']);
    });

    test('benign listings are excluded (PBL residential declaration)', () {
      final r = service.parse(
        '203.0.113.7',
        200,
        fullBody(
          blocklists: [
            {'zone': 'pbl', 'label': 'Spamhaus PBL', 'listed': true, 'benign': true, 'unavailable': false},
          ],
        ),
      );

      expect(r.blocklistsHit, isEmpty);
    });

    test('an unreachable list is not a hit', () {
      final r = service.parse(
        '203.0.113.7',
        200,
        fullBody(
          blocklists: [
            {'zone': 'x', 'label': 'X', 'listed': true, 'benign': false, 'unavailable': true},
          ],
        ),
      );

      expect(r.blocklistsHit, isEmpty);
    });
  });

  group('P4 — E-5: failure is never a clean result', () {
    test('403 verification_required maps to quota exhausted', () {
      final r = service.parse('203.0.113.7', 403, {
        'error': 'quota',
        'code': 'verification_required',
      });

      expect(r.status, IpReputationStatus.unavailable);
      expect(r.failureReason, IpReputationFailure.quotaExhausted);
      expect(r.isOk, isFalse);
      expect(r.markers, isEmpty);
      expect(r.hasFlaggedMarker, isFalse);
    });

    test('429 open_rate_limited maps to rate limited', () {
      final r = service.parse('203.0.113.7', 429, {
        'error': 'slow down',
        'code': 'open_rate_limited',
      });

      expect(r.failureReason, IpReputationFailure.rateLimited);
    });

    test('a 403 without the documented code is a generic http error', () {
      final r = service.parse('203.0.113.7', 403, {'error': 'nope'});

      expect(r.failureReason, IpReputationFailure.httpError);
    });

    test('5xx maps to http error', () {
      expect(
        service.parse('203.0.113.7', 503, null).failureReason,
        IpReputationFailure.httpError,
      );
    });

    test('a 200 without an ip field is a parse error', () {
      expect(
        service.parse('203.0.113.7', 200, {'source': 'fresh'}).failureReason,
        IpReputationFailure.parseError,
      );
    });

    test('an empty body is a parse error', () {
      expect(
        service.parse('203.0.113.7', 200, null).failureReason,
        IpReputationFailure.parseError,
      );
    });

    test('unavailable reports carry no markers to misread', () {
      final r = IpReputation.unavailable(
        '203.0.113.7',
        IpReputationFailure.timeout,
      );

      expect(r.isOk, isFalse);
      expect(r.failureReason, IpReputationFailure.timeout);
      expect(r.markers, isEmpty);
      expect(r.blocklistsHit, isEmpty);
      expect(r.abuseScore, isNull);
    });
  });

  // E-4 was relaxed by the user (decision B), but only on one condition: the
  // score must never travel alone. These tests pin the *new* contract, which is
  // stricter than the old one about the thing that actually matters.
  group('P4 - score only with its reasons (E-4 relaxed, decision B)', () {
    test('risk.purity is surfaced, together with its factors', () {
      final r = service.parse('203.0.113.7', 200, fullBody());

      expect(r.isOk, isTrue);
      expect(r.risk, isNotNull);
      expect(r.risk!.purity, fullBody()['risk']['purity']);
      // Without its reasons the score would be the black box E-4 rejected, so
      // the parser must never emit a score with an empty factor list when the
      // source sent factors.
      expect(fullBody()['risk']['factors'], isNotEmpty);
      expect(r.risk!.factors, isNotEmpty);
      // The per-marker verdicts are unchanged: the aggregate is additive.
      expect(r.markers.length, IpReputationService.markerIds.length);
    });

    test('a score with no reasons and no number is not surfaced', () {
      final body = fullBody()..['risk'] = <String, dynamic>{};

      final r = service.parse('203.0.113.7', 200, body);

      expect(r.isOk, isTrue);
      expect(r.risk, isNull);
      expect(r.markers, isNotEmpty);
    });

    test('a factor without a weight is kept at neutral, not invented', () {
      final body = fullBody();
      body['risk']['factors'] = [
        {'id': 'native', 'label': 'native-ip'},
      ];

      final r = service.parse('203.0.113.7', 200, body);

      expect(r.risk!.factors, hasLength(1));
      expect(r.risk!.factors.single.points, 0);
    });

    test('a negative source weight is a bonus, not a penalty', () {
      final body = fullBody();
      body['risk']['factors'] = [
        {'id': 'native', 'label': 'native-ip', 'points': -5},
      ];

      final r = service.parse('203.0.113.7', 200, body);

      expect(r.risk!.factors.single.points, -5);
    });

    test('null purity scores are never manufactured as zero', () {
      final r = IpReputation(
        status: IpReputationStatus.ok,
        ip: '203.0.113.7',
        risk: const IpRiskScore(factors: []),
      );

      expect(r.risk, isNotNull);
      expect(r.risk!.hasScore, isFalse);
    });

    test('scenarios are surfaced, and unscored uses are dropped', () {
      final body = fullBody();
      body['scenarios'] = [
        {'id': 'ai', 'label': 'AI', 'score': 99, 'levelLabel': 'very-suitable'},
        {'id': 'email', 'label': 'mail', 'score': 12, 'levelLabel': 'poor'},
        {'id': 'made-up', 'label': 'nope', 'score': 100},
        {'id': 'streaming', 'label': 'missing-score'},
      ];

      final r = service.parse('203.0.113.7', 200, body);

      // An unknown id and an unscored use both say nothing usable, so neither
      // may be surfaced as a score.
      expect(r.scenarios.map((e) => e.id).toList(), ['ai', 'email']);
      expect(r.scenarios.first.score, 99);
      expect(r.scenarios.first.levelLabel, 'very-suitable');
      expect(r.scenarios.last.score, 12);
    });

    test('an absent scenarios key is empty, not all-good', () {
      final body = fullBody()..remove('scenarios');

      final r = service.parse('203.0.113.7', 200, body);

      expect(r.scenarios, isEmpty);
    });
  });
}
