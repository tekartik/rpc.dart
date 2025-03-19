@TestOn('browser')
library;

import 'package:tekartik_rpc_test/rpc_client_test.dart';
import 'package:tekartik_web_socket_browser/web_socket_browser.dart';
import 'package:test/test.dart';

void main() {
  group('rpc_memory', () {
    rpcClientTests(webSocketChannelClientFactoryBrowser);
  });
}
