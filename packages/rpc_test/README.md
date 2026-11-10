# tekartik_rpc_test

The shared tests of [`tekartik_rpc`](../rpc) on a `tekartik_web_socket`
transport (memory, io, browser), plus small helpers (`PingRpcService`,
`RpcTestContext`) and two console dev menus. Pure Dart on `package:test`.

## Getting started

Git package, not on pub.dev, used as a dev dependency:

```yaml
dev_dependencies:
  tekartik_rpc_test:
    git:
      url: https://github.com/tekartik/rpc.dart
      path: packages/rpc_test
  test: '>=1.31.0'
```

Both suites on the memory transport (no network, runs on the VM and in the
browser), `test/rpc_memory_test.dart`:

```dart
import 'package:tekartik_rpc_test/rpc_client_test.dart';
import 'package:tekartik_rpc_test/rpc_server_test.dart';
import 'package:tekartik_web_socket/web_socket.dart';
import 'package:test/test.dart';

void main() {
  group('rpc_memory', () {
    rpcTests(webSocketChannelFactoryMemory);
    rpcClientTests(webSocketChannelClientFactoryMemory);
  });
}
```

Run it with `dart test` (`dart test -p chrome` too).

## What it checks

* `rpcTests(WebSocketChannelFactory)` (`rpc_server_test.dart`, it serves):
  connect, `onConnect` (and a failing one closing the connection), a ping
  through a service, a client close removing its server channel, auto
  connect across a server restart, `AutoConnectRpcClient.close()` failing a
  pending request and stopping the reconnect wait at once, a close from the
  server.
* `rpcClientTests(WebSocketChannelClientFactory)` (`rpc_client_test.dart`,
  client only, the one to run with the browser factory): connecting to a
  port without server throws `RpcClientConnectionException`.

## What to know

* `rpcTests` needs a server: the memory factory, or the io one
  (`webSocketChannelFactoryIo` of `tekartik_web_socket_io`, `@TestOn('vm')`,
  real local ports). In a browser use `rpcClientTests` with
  `webSocketChannelClientFactoryBrowser`.
* `rpcClientTests` connects to `ws://localhost:9999`: it fails if something
  listens there.
* `bin/rpc_server_io.dart` and `example/rpc_client_menu.dart` are
  [`tekartik_app_dev_menu`](https://github.com/tekartik/app_common_utils.dart)
  menus to serve and call a live connection by hand from a checkout.

More in the [package skill](skills/tekartik-rpc-test-suite/SKILL.md).
