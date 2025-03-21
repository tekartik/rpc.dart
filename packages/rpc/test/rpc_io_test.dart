@TestOn('vm')
library;

import 'package:tekartik_rpc_test/rpc_client_test.dart';
import 'package:tekartik_rpc_test/rpc_server_test.dart';
import 'package:tekartik_web_socket_io/web_socket_io.dart';
import 'package:test/test.dart';

void main() {
  // debugRpcClient = devWarning(true);
  // debugRpcServer = devWarning(true);
  group('rpc_io', () {
    rpcTests(webSocketChannelFactoryIo);
    rpcClientTests(webSocketChannelClientFactoryIo);
  });
}
