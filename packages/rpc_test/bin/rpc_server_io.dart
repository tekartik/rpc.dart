// ignore_for_file: avoid_print

import 'dart:async';

import 'package:tekartik_rpc/rpc_server.dart';

import '../example/rpc_client_menu.dart';

class SimpleRpcService extends RpcServiceBase {
  SimpleRpcService() : super(simpleRcpServiceName);

  @override
  FutureOr<Object?> onCall(RpcMethodCall methodCall) async {
    var method = methodCall.method;
    if (method == 'ping') {
      return 'pong';
    }
    if (method == 'throw') {
      throw RpcException('throw', 'Throwing', const {});
    }
    if (method == 'throw_any') {
      throw StateError('Throwing any');
    }
    return super.onCall(methodCall);
  }
}

Future<void> main(List<String> args) async {
  var rpcServer = await RpcServer.serve(
    services: [SimpleRpcService()],
    port: urlKvPort,
  );
  print('listening on ${rpcServer.url}');
}
