import 'package:tekartik_rpc/rpc_server.dart';
import 'package:tekartik_rpc/src/constant.dart';

import 'import.dart';

/// Core service (always present)
class RpcCoreService extends RpcServiceBase {
  /// Constructor
  RpcCoreService() : super(coreServiceName);

  @override
  FutureOr<Object?> onCall(RpcServerChannel channel, RpcMethodCall methodCall) {
    switch (methodCall.method) {
      case coreServiceMethodeInit:
        return null;
    }
    return super.onCall(channel, methodCall);
  }
}
