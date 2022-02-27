import 'package:tekartik_rpc/src/rpc_client.dart';
import 'package:tekartik_rpc/src/rpc_server.dart';
import 'package:tekartik_web_socket/web_socket.dart';
import 'package:test/test.dart';

class DevshTestContext {
  final WebSocketChannelFactory webSocketChannelFactory;

  late RpcServer devshServer;

  DevshTestContext(this.webSocketChannelFactory);
  Future<void> setUp() async {
    WebSocketChannelFactory factory = webSocketChannelFactoryMemory;
    devshServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server, services: []);
    var devshClient = await RpcClient.connect(
      Uri.parse(devshServer.url),
      webSocketChannelClientFactory: factory.client,
    );
    expect(devshClient, isNotNull);
  }

  Future<void> tearDown() async {
    await devshServer.close();
  }
}

void main() {
  group('server', () {
    test('init', () async {
      WebSocketChannelFactory factory = webSocketChannelFactoryMemory;
      var devshServer = await RpcServer.serve(
        webSocketChannelServerFactory: factory.server,
        services: [],
      );
      var devshClient = await RpcClient.connect(
        Uri.parse(devshServer.url),
        webSocketChannelClientFactory: factory.client,
      );

      expect(devshClient, isNotNull);

      await devshServer.close();
    });
    late DevshTestContext ctx;

    setUpAll(() async {
      ctx = DevshTestContext(webSocketChannelFactoryMemory);
      await ctx.setUp();
    });
    tearDownAll(() async {
      await ctx.tearDown();
    });
  });
}
