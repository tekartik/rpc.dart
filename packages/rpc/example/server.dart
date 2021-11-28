import 'dart:async';

import 'package:tekartik_rpc/rpc_server.dart';

const simpleRcpServiceName = 'simple';

class SimpleRpcService extends RpcServiceBase {
  SimpleRpcService() : super(simpleRcpServiceName);

  @override
  FutureOr<Object?> onCall(RpcMethodCall methodCall) async {
    var method = methodCall.method;
    if (method == 'ping') {
      return 'pong';
    }
    if (method == 'throw') {
      throw RpcException('throw', 'Throwing', {});
    }
    if (method == 'throw_any') {
      throw StateError('Throwing any');
    }
    return super.onCall(methodCall);
  }
}

Future<void> main() async {
  var rpcServer =
      await RpcServer.serve(services: [SimpleRpcService()], port: 8060);
  print('listening on ${rpcServer.url}');
}
