import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:tekartik_rpc/rpc_client.dart';
import 'package:tekartik_rpc/rpc_server.dart';
import 'package:tekartik_web_socket/web_socket.dart';

/// Rpc service base
class PingRpcService extends RpcServiceBase {
  /// Constructor
  PingRpcService() : super('ping_service');

  @override
  FutureOr<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
    var method = methodCall.method;
    if (method == 'ping') {
      return 'pong';
    }
    return super.onCall(channel, methodCall);
  }
}

/// Rpc Test context
class RpcTestContext {
  /// Web socket channel factory
  final WebSocketChannelFactory webSocketChannelFactory;

  /// Rpc server
  late RpcServer rpcServer;

  late RpcClient _rpcClient;

  /// Constructor
  RpcTestContext(this.webSocketChannelFactory);

  /// Set up
  Future<void> setUp() async {
    var (server, client) = await _serveAndConnect(
      webSocketChannelFactory,
      services: [],
    );
    rpcServer = server;
    _rpcClient = client;
  }

  /// Tear down
  Future<void> tearDown() async {
    await _rpcClient.close();
    await rpcServer.close();
  }
}

/// Serve [services] and connect a client to the server.
Future<(RpcServer, RpcClient)> _serveAndConnect(
  WebSocketChannelFactory factory, {
  required List<RpcService> services,
  FutureOr<void> Function(RpcServerChannel channel)? onClientDisconnected,
  FutureOr<void> Function(RpcClient client)? onConnect,
}) async {
  var rpcServer = await RpcServer.serve(
    webSocketChannelServerFactory: factory.server,
    services: services,
    onClientDisconnected: onClientDisconnected,
  );
  var rpcClient = await RpcClient.connect(
    Uri.parse(rpcServer.url),
    webSocketChannelClientFactory: factory.client,
    onConnect: onConnect,
  );
  return (rpcServer, rpcClient);
}

/// Rpc tests
void rpcTests(WebSocketChannelFactory factory) {
  group('rpc', () {
    test('init', () async {
      var (rpcServer, rpcClient) = await _serveAndConnect(
        factory,
        services: [],
      );

      expect(rpcClient, isNotNull);

      await rpcServer.close();
    });

    test('client close removes its channel', () async {
      var disconnected = <RpcServerChannel>[];
      var (rpcServer, rpcClient) = await _serveAndConnect(
        factory,
        services: [PingRpcService()],
        onClientDisconnected: disconnected.add,
      );
      // Make sure the server side channel exists
      await rpcClient.sendServiceRequest<String>('ping_service', 'ping', null);
      expect(rpcServer.channels, hasLength(1));
      var channel = rpcServer.channels.first;
      await rpcClient.close();
      var stopwatch = Stopwatch()..start();
      while (rpcServer.channels.isNotEmpty &&
          stopwatch.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(rpcServer.channels, isEmpty);
      expect(disconnected, [channel]);
      await rpcServer.close();
    });

    test('onConnect', () async {
      var onConnectCalledCount = 0;
      var (rpcServer, rpcClient) = await _serveAndConnect(
        factory,
        services: [],
        onConnect: (RpcClient client) async {
          expect(client, isNotNull);
          onConnectCalledCount++;
        },
      );

      expect(onConnectCalledCount, 1);
      var doneFuture = rpcClient.done;
      await rpcServer.close();
      await doneFuture;
    });

    test('autoConnect onConnect', () async {
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [PingRpcService()],
      );
      // print('rpcServer: ${rpcServer.url}');
      var onConnectCalledCount = 0;
      var rpcClient = AutoConnectRpcClient.autoConnect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
        onConnect: (RpcClient client) async {
          expect(client, isNotNull);
          onConnectCalledCount++;
        },
      );
      await rpcClient.sendServiceRequest<String>(
        'ping_service',
        'ping',
        'ping_data',
      );
      await rpcServer.close();
      rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        port: rpcServer.port,
        services: [PingRpcService()],
      );
      await rpcClient.sendServiceRequest<String>(
        'ping_service',
        'ping',
        'ping_data',
      );

      expect(onConnectCalledCount, 2);

      await rpcServer.close();
    });

    test('simple ping', () async {
      var (rpcServer, rpcClient) = await _serveAndConnect(
        factory,
        services: [PingRpcService()],
      );
      await rpcClient.sendServiceRequest<String>(
        'ping_service',
        'ping',
        'ping_data',
      );
      await rpcServer.close();
    });

    test('simple autoconnect ping', () async {
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [PingRpcService()],
      );
      var rpcClient = AutoConnectRpcClient.autoConnect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
      );
      await rpcClient.sendServiceRequest<String>(
        'ping_service',
        'ping',
        'ping_data',
      );
      await rpcServer.close();
    });

    test('close from server', () async {
      var (rpcServer, rpcClient) = await _serveAndConnect(
        factory,
        services: [],
      );

      var doneFuture = rpcClient.done;
      await rpcServer.close();
      await doneFuture;
    });

    test('RpcTestContext', () async {
      var ctx = RpcTestContext(factory);
      await ctx.setUp();
      expect(ctx.rpcServer.url, isNotEmpty);
      await ctx.tearDown();
    });
  });
}

void main() {
  rpcTests(webSocketChannelFactoryMemory);
}
