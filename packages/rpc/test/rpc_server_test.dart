import 'package:tekartik_rpc_test/rpc_server_test.dart';
import 'package:tekartik_web_socket/web_socket.dart';
import 'package:test/test.dart';

void main() {
  group('rpc_memory', () {
    rpcTests(webSocketChannelFactoryMemory);
  });
}
