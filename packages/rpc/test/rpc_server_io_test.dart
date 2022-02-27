import 'package:tekartik_rpc/src/import.dart';
import 'package:tekartik_rpc/src/rpc_client.dart';
import 'package:tekartik_rpc/src/rpc_server.dart';
import 'package:test/test.dart';

void main() {
  group('shell_server_io', () {
    test('init', () async {
      WebSocketChannelFactory factory = webSocketChannelFactoryIo;
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

    late RpcServer rpcServer;

    setUpAll(() async {
      WebSocketChannelFactory factory = webSocketChannelFactoryIo;
      rpcServer = await RpcServer.serve(
          webSocketChannelServerFactory: factory.server, services: []);
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
