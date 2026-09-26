import 'package:riverpod_annotation/riverpod_annotation.dart';

mixin AutoDisposeNotifierMixin<T> on $Notifier<T> {
  set value(T value) {
    state = value;
  }

  @override
  bool updateShouldNotify(T previous, T next) {
    final res = super.updateShouldNotify(previous, next);
    if (res) {
      onUpdate(next);
    }
    return res;
  }

  void onUpdate(T value) {}
}
