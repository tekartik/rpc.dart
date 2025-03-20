import 'package:dev_test/test.dart';
import 'package:tekartik_rpc/rpc_client.dart';

/// Rpc client tests
void rpcClientTests(WebSocketChannelClientFactory clientFactory) {
  group('rpc_client', () {
    test('no_server', () async {
      try {
        await RpcClient.connect(
          Uri.parse('ws://localhost:9999'),
          webSocketChannelClientFactory: clientFactory,
        );
        fail('should fail');
      } on RpcClientConnectionException catch (_) {}
    });
  });
}
