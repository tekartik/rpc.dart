import '../rpc.dart';

/// Log helper
void log(String tag, Object? message) {
  // ignore: avoid_print
  print('/$tag $message');
}

/// Debug helper
extension RpcMethodCallPrint on RpcMethodCall {
  /// Debug text
  String toDebugText() => '$method${arguments == null ? '' : ', $arguments'}';
}
