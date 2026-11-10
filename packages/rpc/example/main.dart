// ignore_for_file: avoid_print

import 'dart:async';

import 'package:tekartik_rpc/rpc_client.dart';
import 'package:tekartik_rpc/rpc_server.dart';

class GreetingService extends RpcServiceBase {
  GreetingService() : super('greeting');

  @override
  FutureOr<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
    switch (methodCall.method) {
      case 'hello':
        return 'hello ${methodCall.arguments}';
    }
    // Unknown method: RpcException rpc_exception_unsupported
    return super.onCall(channel, methodCall);
  }
}

Future<void> main() async {
  var server = await RpcServer.serve(services: [GreetingService()]);
  var client = await RpcClient.connect(server.uri);
  try {
    print(await client.sendServiceRequest<String>('greeting', 'hello', 'you'));
  } finally {
    await client.close();
    await server.close();
  }
}
