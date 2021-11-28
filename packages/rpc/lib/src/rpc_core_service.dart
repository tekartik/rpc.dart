import 'package:tekartik_rpc/rpc.dart';
import 'package:tekartik_rpc/src/constant.dart';
import 'package:tekartik_rpc/src/rpc.dart';
import 'package:tekartik_rpc/src/rpc_service.dart';

import 'import.dart';

/// Core service (always present)
class RpcCoreService extends RpcServiceBase {
  RpcCoreService() : super(coreServiceName);

  @override
  FutureOr<Object?> onCall(RpcMethodCall methodCall) {
    switch (methodCall.method) {
      case coreServiceMethodeInit:
        return null;
    }
    super.onCall(methodCall);
  }
}
