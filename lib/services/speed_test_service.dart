import 'dart:async';

import 'package:fluxora/clash/message.dart';
import 'package:fluxora/models/models.dart';

/// 测速进度的单一来源。
///
/// 内核每 200ms 推一帧，这里转成广播流给界面用。`invokeAction` 是一次性的
/// （收到第一条就关端口），所以进度只能走消息通道。
class SpeedTestService extends AppMessageListener {
  SpeedTestService._() {
    ClashMessage.instance.addListener(this);
  }

  static final SpeedTestService instance = SpeedTestService._();

  final _controller = StreamController<SpeedTestProgress>.broadcast();

  Stream<SpeedTestProgress> get progress => _controller.stream;

  @override
  void onSpeedTest(SpeedTestProgress progress) {
    if (!_controller.isClosed) _controller.add(progress);
  }
}
