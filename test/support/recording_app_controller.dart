import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';

/// An [AppController] that **records** the system-back-block calls instead of
/// writing `backBlockProvider`.
///
/// Why this exists:
///
/// `SystemBackBlock` schedules `backBlock()` in `initState` and `unBackBlock()`
/// in `dispose`, both via `addPostFrameCallback`. In production the controller
/// is bound in `ApplicationState.initState` (`lib/application.dart:103`), and
/// `Application` is the widget passed to `runApp`, so the controller's `ref`
/// lives exactly as long as the app does — the dispose-time call is safe.
///
/// A widget test cannot reproduce that: whichever `Consumer` binds the
/// controller is torn down with the test tree, and a post-frame callback that
/// lands after teardown trips riverpod's "using ref after unmount" guard. That
/// failure says nothing about the widget under test.
///
/// Overriding the two methods keeps the lifecycle observable while removing the
/// dependency on a ref that outlives the tree. This is a double for an unrelated
/// collaborator: the behaviour under test (`CommonScaffold`'s search / edit
/// state machine, `SystemBackBlock`'s mount-unmount pairing) never reads
/// `backBlockProvider`.
class RecordingAppController extends AppController {
  RecordingAppController(super.context, super.ref);

  /// One entry per call, in order: `'block'` / `'unblock'`.
  final List<String> calls = <String>[];

  /// Every page the navigation asked to switch to, in order.
  ///
  /// `toPage` normally drives the real `Navigator` through
  /// `globalState.navigatorKey`; a widget test has no such navigator, so
  /// recording the request is what lets a test assert "this destination maps to
  /// that page" without standing up the whole shell.
  final List<PageLabel> pages = <PageLabel>[];

  @override
  void backBlock() => calls.add('block');

  @override
  void unBackBlock() => calls.add('unblock');

  @override
  void toPage(PageLabel pageLabel) => pages.add(pageLabel);
}
