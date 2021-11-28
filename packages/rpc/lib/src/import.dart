import 'package:tekartik_rpc/rpc.dart';

export 'package:tekartik_common_utils/common_utils_import.dart';
export 'package:tekartik_web_socket/web_socket.dart';
export 'package:tekartik_web_socket_io/web_socket_io.dart';

extension RpcMethodCallPrint on RpcMethodCall {
  String toDebugText() => '$method${arguments == null ? '' : ', $arguments'}';
}
