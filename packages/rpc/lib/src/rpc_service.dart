import 'package:tekartik_rpc/rpc.dart';
import 'package:tekartik_rpc/src/log_utils.dart';
import 'package:tekartik_rpc/src/rpc_exception.dart';

import 'import.dart';

/// What to implement.
abstract class RpcService {
  /// Service name
  String get name;

  /// Handle service
  FutureOr<Object?> onCall(RpcMethodCall methodCall);
}

/// Base class to implement a service
abstract class RpcServiceBase implements RpcService {
  @override
  final String name;

  /// Constructor
  RpcServiceBase(this.name);

  @override
  @mustCallSuper
  FutureOr<Object?> onCall(RpcMethodCall methodCall) async {
    throw RpcException(rpcExceptionCodeUnsupported,
        '$name: onCall(${methodCall.toDebugText()}) not supported');
  }
}
