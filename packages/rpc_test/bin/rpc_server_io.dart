// ignore_for_file: avoid_print

import 'dart:async';

import 'package:tekartik_rpc/rpc_server.dart';

import '../example/rpc_client_menu.dart';

class SimpleRpcService extends RpcServiceBase {
  SimpleRpcService() : super(simpleRcpServiceName);

  @override
  FutureOr<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
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
    return super.onCall(channel, methodCall);
  }
}

Future<void> main(List<String> args) async {
  debugRpcServer = true;
  await mainMenu(args, () {
    rpcServerMainMenu();
  });
}

void rpcServerMainMenu() {
  RpcServer? rpcServer;
  item('serve', () async {
    rpcServer = await RpcServer.serve(
      services: [SimpleRpcService()],
      port: urlKvPort,
      onClientConnected: (channel) {
        write('client connected ${channel.id}');
      },
      onClientDisconnected: (channel) {
        write('client disconnected ${channel.id}');
      },
    );
    print('listening on ${rpcServer?.url}');
  });
  item('get channels', () {
    for (var channel in rpcServer?.channels ?? <RpcServerChannel>[]) {
      write(channel.id);
    }
  });
  item('close channel', () {
    showMenu(() {
      for (var channel in rpcServer?.channels ?? <RpcServerChannel>[]) {
        item('channel ${channel.id}', () async {
          await channel.close();
          await popMenu();
        });
      }
    });
  });
  item('close all channels', () async {
    var futures = <Future>[];

    for (var channel in rpcServer?.channels ?? <RpcServerChannel>[]) {
      futures.add(channel.close());
    }
    await Future.wait(futures);
  });
  item('close', () async {
    await rpcServer?.close();
  });
}
