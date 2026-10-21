import 'package:fluxora/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('release candidates are ordered by their number, not the text', () {
      // 10 和 11 当字符串比会得出 "10" < "11" 也成立，但 "9" > "10"，
      // 所以必须按数字比。
      expect(utils.compareVersions('1.1.0-rc.11', '1.1.0-rc.10'), greaterThan(0));
      expect(utils.compareVersions('1.1.0-rc.9', '1.1.0-rc.10'), lessThan(0));
      expect(utils.compareVersions('1.1.0-rc.10', '1.1.0-rc.10'), 0);
    });

    test('a release is newer than any of its release candidates', () {
      expect(utils.compareVersions('1.1.0', '1.1.0-rc.11'), greaterThan(0));
      expect(utils.compareVersions('1.1.0-rc.11', '1.1.0'), lessThan(0));
    });

    test('plain versions compare segment by segment', () {
      expect(utils.compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(utils.compareVersions('2.0.0', '1.99.99'), greaterThan(0));
      expect(utils.compareVersions('1.1.0', '1.1.0'), 0);
    });

    test('a leading v and build metadata are ignored for ordering', () {
      expect(utils.compareVersions('v1.1.0', '1.1.0'), 0);
      expect(utils.compareVersions('1.1.0+2026102102', '1.1.0+2026102101'),
          greaterThan(0));
    });

    test('rc.10 can see rc.11 as an update', () {
      // 这就是用户报的那个场景：装在 rc.10 上，rc.11 发布后收不到提示。
      final current = '1.1.0-rc.10';
      final latest = '1.1.0-rc.11';
      expect(utils.compareVersions(latest, current), greaterThan(0));
    });

    test('malformed input never throws', () {
      // 版本号来自远端 release 标题，格式不可控。抛一次就让整个更新检查失效。
      expect(() => utils.compareVersions('abc', '1.0.0'), returnsNormally);
      expect(() => utils.compareVersions('', ''), returnsNormally);
      expect(() => utils.compareVersions('1.1.0-', '1.1.0'), returnsNormally);
    });
  });
}
