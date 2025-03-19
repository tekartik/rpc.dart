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

  /// Constructor
  RpcTestContext(this.webSocketChannelFactory);

  /// Set up
  Future<void> setUp() async {
    rpcServer = await RpcServer.serve(
      webSocketChannelServerFactory: webSocketChannelFactory.server,
      services: [],
    );
    var rpcClient = await RpcClient.connect(
      Uri.parse(rpcServer.url),
      webSocketChannelClientFactory: webSocketChannelFactory.client,
    );
    expect(rpcClient, isNotNull);
  }

  /// Tear down
  Future<void> tearDown() async {
    await rpcServer.close();
  }
}

/// Rpc tests
void rpcTests(WebSocketChannelFactory factory) {
  group('rpc', () {
    test('init', () async {
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [],
      );
      var rpcClient = await RpcClient.connect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
      );

      expect(rpcClient, isNotNull);

      await rpcServer.close();
    });

    test('onConnect', () async {
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [],
      );
      var onConnectCalledCount = 0;
      var rpcClient = await RpcClient.connect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
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
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [PingRpcService()],
      );
      var rpcClient = await RpcClient.connect(
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
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [],
      );
      var rpcClient = await RpcClient.connect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
      );

      var doneFuture = rpcClient.done;
      await rpcServer.close();
      await doneFuture;
    });

    late RpcServer rpcServer;

    setUpAll(() async {
      rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [],
      );
      var rpcClient = await RpcClient.connect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
      );

      expect(rpcClient, isNotNull);
    });
    tearDownAll(() async {
      await rpcServer.close();
    });
  });
}

void main() {
  rpcTests(webSocketChannelFactoryMemory);
  group('server', () {
    test('init', () async {
      WebSocketChannelFactory factory = webSocketChannelFactoryMemory;
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [],
      );
      var rpcClient = await RpcClient.connect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
      );

      expect(rpcClient, isNotNull);

      await rpcServer.close();
    });
    late RpcTestContext ctx;

    setUpAll(() async {
      ctx = RpcTestContext(webSocketChannelFactoryMemory);
      await ctx.setUp();
    });
    tearDownAll(() async {
      await ctx.tearDown();
    });
  });
}
