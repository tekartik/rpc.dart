// ignore_for_file: avoid_print

import 'dart:async';

import 'package:tekartik_rpc/rpc_server.dart';

const simpleRcpServiceName = 'simple';

class SimpleRpcService extends RpcServiceBase {
  SimpleRpcService() : super(simpleRcpServiceName);

  @override
  FutureOr<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
    var method = methodCall.method;
    if (method == 'ping') {
      return 'pong ${channel.id}';
    }
    if (method == 'throw') {
      throw RpcException('throw', 'Throwing', const {});
    }
    if (method == 'throw_any') {
      throw StateError('Throwing any');
    }
    return super.onCall(channel, methodCall);
  }
}

Future<void> main() async {
  var rpcServer = await RpcServer.serve(
    services: [SimpleRpcService()],
    port: 8060,
  );
  print('listening on ${rpcServer.url}');
}
