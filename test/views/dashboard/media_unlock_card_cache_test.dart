import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/views/dashboard/widgets/media_unlock.dart';

/// item 6 (Bettbox 1.19.4 alignment) — the media-unlock card's build cache.
///
/// `mediaUnlockState.state` is a `ValueNotifier`, so every probe tick rebuilt
/// the whole card subtree even when only one spinner moved. The cache is only
/// correct if a tick that changes nothing visible costs nothing **and** a tick
/// that does change something always rebuilds — both directions are pinned here.
void main() {
  /// Three displayed platforms, plus `spotify` used as the "some other
  /// platform" fixture — it is deliberately absent from `platforms`.
  final platforms = [
    MediaPlatform.netflix,
    MediaPlatform.disney,
    MediaPlatform.youtube,
  ];
  final offCard = MediaPlatform.spotify;

  MediaUnlockState stateWith({
    bool isLoading = false,
    Set<MediaPlatform> testing = const {},
    Map<MediaPlatform, MediaUnlockResult>? results,
  }) => MediaUnlockState(
    isLoading: isLoading,
    testingPlatforms: testing,
    results: results ?? const {},
  );

  bool rebuild({
    MediaUnlockState? lastState,
    List<MediaPlatform>? lastPlatforms,
    bool? lastColorful,
    bool hasCachedCard = true,
    required MediaUnlockState newState,
    bool colorfulIcons = true,
    List<MediaPlatform>? displayed,
  }) => shouldRebuildMediaCard(
    lastState: lastState,
    lastDisplayedPlatforms: lastPlatforms,
    lastColorfulIcons: lastColorful,
    hasCachedCard: hasCachedCard,
    newState: newState,
    displayedPlatforms: displayed ?? platforms,
    colorfulIcons: colorfulIcons,
  );

  group('shouldRebuildMediaCard — a no-op tick costs nothing', () {
    test('an unchanged state does not rebuild', () {
      final state = stateWith(
        results: {
          MediaPlatform.netflix: MediaUnlockResult(
            platform: MediaPlatform.netflix,
            status: MediaUnlockStatus.unlocked,
          ),
        },
      );
      expect(
        rebuild(
          lastState: state,
          lastPlatforms: platforms,
          lastColorful: true,
          newState: state,
        ),
        isFalse,
      );
    });

    test('a brand-new but identical state does not rebuild', () {
      // `ValueNotifier` hands over a new object per tick; what matters is
      // whether anything the card *shows* differs.
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(),
        ),
        isFalse,
      );
    });

    test('a result for a platform that is not displayed is ignored', () {
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(
            results: {
              offCard: MediaUnlockResult(
                platform: offCard,
                status: MediaUnlockStatus.unlocked,
              ),
            },
          ),
        ),
        isFalse,
        reason:
            'the card only renders the displayed platforms, so an off-card '
            'result must not force a rebuild',
      );
    });
  });

  group('shouldRebuildMediaCard — anything visible invalidates', () {
    test('a result changing on a displayed platform rebuilds', () {
      final old = stateWith();
      final updated = stateWith(
        results: {
          MediaPlatform.netflix: MediaUnlockResult(
            platform: MediaPlatform.netflix,
            status: MediaUnlockStatus.unlocked,
          ),
        },
      );
      expect(
        rebuild(
          lastState: old,
          lastPlatforms: platforms,
          lastColorful: true,
          newState: updated,
        ),
        isTrue,
      );
    });

    test('the loading flag flipping rebuilds', () {
      expect(
        rebuild(
          lastState: stateWith(isLoading: false),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(isLoading: true),
        ),
        isTrue,
      );
      expect(
        rebuild(
          lastState: stateWith(isLoading: true),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(isLoading: false),
        ),
        isTrue,
      );
    });

    test('a platform entering or leaving the testing set rebuilds', () {
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(testing: {MediaPlatform.netflix}),
        ),
        isTrue,
      );
      expect(
        rebuild(
          lastState: stateWith(testing: {MediaPlatform.netflix}),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(),
        ),
        isTrue,
      );
    });

    test('a testing flag on an undisplayed platform does NOT rebuild', () {
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(testing: {offCard}),
        ),
        isFalse,
      );
    });

    test('the displayed platform list changing rebuilds', () {
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(),
          displayed: platforms.sublist(0, 2),
        ),
        isTrue,
      );
      // Same length, different members.
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(),
          displayed: [
            MediaPlatform.netflix,
            MediaPlatform.disney,
            offCard,
          ],
        ),
        isTrue,
      );
    });

    test('the colourful-icons toggle rebuilds', () {
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(),
          colorfulIcons: false,
        ),
        isTrue,
      );
    });
  });

  group('shouldRebuildMediaCard — a cold cache always rebuilds', () {
    test('no cached card rebuilds', () {
      expect(
        rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          lastColorful: true,
          hasCachedCard: false,
          newState: stateWith(),
        ),
        isTrue,
      );
    });

    test('a missing sentinel rebuilds', () {
      for (final missing in <bool Function()>[
        () => rebuild(
          lastPlatforms: platforms,
          lastColorful: true,
          newState: stateWith(),
        ),
        () => rebuild(
          lastState: stateWith(),
          lastColorful: true,
          newState: stateWith(),
        ),
        () => rebuild(
          lastState: stateWith(),
          lastPlatforms: platforms,
          newState: stateWith(),
        ),
      ]) {
        expect(missing(), isTrue);
      }
    });
  });
}
