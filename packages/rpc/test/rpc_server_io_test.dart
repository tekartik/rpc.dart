import 'package:tekartik_rpc/src/import.dart';
import 'package:tekartik_rpc_test/rpc_server_test.dart';
import 'package:test/test.dart';

void main() {
  group('rpc_memory', () {
    rpcTests(webSocketChannelFactoryIo);
  });
}
