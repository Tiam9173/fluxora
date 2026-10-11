import 'package:fluxora/manager/warp_manager.dart';
import 'package:flutter_riverpod/legacy.dart';

final warpProvider = ChangeNotifierProvider<WarpManager>((ref) {
  return warpManager;
});
