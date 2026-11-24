import 'package:archive/archive_io.dart';
import 'package:fluxora/common/profile_recovery.dart';
import 'package:fluxora/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(String id, String url, {String? label}) => Profile(
  id: id,
  label: label ?? id,
  url: url,
  autoUpdateDuration: const Duration(days: 1),
);

void main() {
  const url = 'https://example.test/sub?token=a';

  test('compatible restore reuses the local subscription ID and label', () {
    final incoming = _profile('backup', ' HTTPS://EXAMPLE.TEST/sub?token=a#x ');
    final plan = ProfileRecoveryPlan.compatible(
      [incoming],
      [_profile('local', url, label: 'My subscription')],
    );

    expect(plan.profiles.single.id, 'local');
    expect(plan.profiles.single.label, 'My subscription');
    expect(plan.targetId('backup'), 'local');
  });

  test('same URL entries in a backup remain separate', () {
    final incoming = [
      _profile('first', url, label: 'Backup A'),
      _profile('second', url, label: 'Backup B'),
    ];
    final plan = ProfileRecoveryPlan.compatible(incoming, [
      _profile('local', url, label: 'Local'),
    ]);

    expect(plan.profiles.map((profile) => profile.id), ['local', 'second']);
    expect(plan.profiles.map((profile) => profile.label), [
      'Local',
      'Backup B',
    ]);
    expect(plan.targetId('first'), 'local');
    expect(plan.targetId('second'), 'second');
  });

  test(
    'duplicate profile IDs are rejected without collapsing subscriptions',
    () {
      expect(
        () => ProfileRecoveryPlan.compatible([
          _profile('duplicate', url),
          _profile('duplicate', 'https://other.test/sub'),
        ], const []),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('duplicate profile IDs are rejected in exact recovery', () {
    expect(
      () => ProfileRecoveryPlan.exact([
        _profile('duplicate', url),
        _profile('duplicate', 'https://other.test/sub'),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('exact ID wins and a different subscription token is not merged', () {
    final exact = _profile('local', url, label: 'Restored label');
    final plan = ProfileRecoveryPlan.compatible(
      [exact, _profile('other', 'https://example.test/sub?token=b')],
      [exact, _profile('another-local', url, label: 'Other')],
    );

    expect(plan.profiles.first, exact);
    expect(plan.profiles.last.id, 'other');
    expect(plan.targetId('local'), 'local');
    expect(plan.targetId('other'), 'other');
  });

  test(
    'remaps subscription files, provider caches, and leaves unrelated files',
    () {
      final plan = ProfileRecoveryPlan.compatible(
        [_profile('backup', url)],
        [_profile('local', url)],
      );
      final profileFile = ArchiveFile.bytes('profiles/backup.yaml', [1]);
      final providerFile = ArchiveFile.bytes(
        'profiles/providers/backup/proxy/config.yaml',
        [2],
      );
      final otherFile = ArchiveFile.bytes('scripts/backup.js', [3]);

      expect(plan.remapArchiveFile(profileFile).name, 'profiles/local.yaml');
      expect(
        plan.remapArchiveFile(providerFile).name,
        'profiles/providers/local/proxy/config.yaml',
      );
      expect(plan.remapArchiveFile(otherFile), same(otherFile));
    },
  );

  test('override restore keeps backup IDs unchanged', () {
    final incoming = _profile('backup', url);
    final plan = ProfileRecoveryPlan.exact([incoming]);

    expect(plan.profiles, [incoming]);
    expect(plan.targetId('backup'), 'backup');
    expect(plan.targetId(null), isNull);
    expect(
      plan
          .remapArchiveFile(ArchiveFile.bytes('profiles/backup.yaml', [1]))
          .name,
      'profiles/backup.yaml',
    );
  });
}
