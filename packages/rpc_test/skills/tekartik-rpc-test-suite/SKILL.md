---
name: tekartik-rpc-test-suite
description: >-
  Use when running the shared tekartik_rpc conformance tests against a
  WebSocket implementation, or when writing tests around an RPC server:
  rpcTests(WebSocketChannelFactory) from
  package:tekartik_rpc_test/rpc_server_test.dart,
  rpcClientTests(WebSocketChannelClientFactory) from
  package:tekartik_rpc_test/rpc_client_test.dart, the PingRpcService and
  RpcTestContext helpers, and picking webSocketChannelFactoryMemory,
  webSocketChannelFactoryIo or webSocketChannelClientFactoryBrowser per
  platform.
---

# tekartik_rpc shared test suite (tekartik_rpc_test)

`tekartik_rpc_test` holds the conformance tests for `tekartik_rpc`: two
`void` functions that declare groups of tests, parameterised by a
`tekartik_web_socket` factory. Depend on it to check that a WebSocket
implementation (io, browser, memory, or your own) behaves correctly under
`RpcServer`/`RpcClient`, and to reuse its small service/context helpers in
your own tests.

## Guidelines

* Dev dependency (git only, not on pub.dev); add the factory packages you
  actually test with:
  ```yaml
  dev_dependencies:
    tekartik_rpc_test:
      git:
        url: https://github.com/tekartik/rpc.dart
        path: packages/rpc_test
    tekartik_web_socket:
      git:
        url: https://github.com/tekartik/web_socket.dart
        path: web_socket
    tekartik_web_socket_io:
      git:
        url: https://github.com/tekartik/web_socket.dart
        path: web_socket_io
    test: '>=1.31.0'
  ```
* Two entry points, no `src/`:
  * `package:tekartik_rpc_test/rpc_server_test.dart` exports
    `rpcTests(WebSocketChannelFactory factory)` - the full suite (connect,
    `onConnect` callback, ping through a service, auto-connect across a
    server restart, close from the server) - plus the helpers
    `PingRpcService` and `RpcTestContext`.
  * `package:tekartik_rpc_test/rpc_client_test.dart` exports
    `rpcClientTests(WebSocketChannelClientFactory clientFactory)` - the
    client-only suite (currently: connecting to a dead port throws
    `RpcClientConnectionException`).
* Call them from `main()`, usually inside a `group(...)` naming the platform.
  They declare their own `group`/`test` entries, so nothing must be awaited.
* `rpcTests` needs a full `WebSocketChannelFactory` (it serves), so it is VM
  only in practice: use `webSocketChannelFactoryIo` under `@TestOn('vm')`, or
  `webSocketChannelFactoryMemory` which also runs on the browser.
  `rpcClientTests` only needs a client factory, so it is the one to run under
  `@TestOn('browser')` with `webSocketChannelClientFactoryBrowser`.
* Factory imports: `webSocketChannelFactoryMemory` and
  `webSocketChannelClientFactoryMemory` from
  `package:tekartik_web_socket/web_socket.dart`;
  `webSocketChannelFactoryIo` and `webSocketChannelClientFactoryIo` from
  `package:tekartik_web_socket_io/web_socket_io.dart`;
  `webSocketChannelClientFactoryBrowser` from
  `package:tekartik_web_socket_browser/web_socket_browser.dart`.
* `PingRpcService` is an `RpcServiceBase` named `ping_service` answering
  `ping` with `'pong'`; reuse it as the trivial service in your own server
  tests instead of redefining one.
* `RpcTestContext(factory)` is a tiny fixture: `await ctx.setUp()` serves an
  empty `RpcServer` (field `ctx.rpcServer`) and checks that a client can
  connect; `await ctx.tearDown()` closes the server. It keeps no client, so
  connect your own from `ctx.rpcServer.url`.
* The io suite binds real local ports, including rebinding the same port
  after a restart; do not run it in a sandbox without loopback networking.
  The memory factory needs none and is the fastest default.
* Run with `dart test` (VM) and `dart test -p chrome` for the browser
  variant; the repo's own `test/rpc_io_test.dart`, `test/rpc_memory_test.dart`
  and `test/rpc_browser_test.dart` in `packages/rpc` are the reference
  wiring.
* The package also ships two interactive dev-menu apps used to debug a live
  connection by hand: `bin/rpc_server_io.dart` (serve, list/close channels)
  and `example/rpc_client_menu.dart` (connect, auto connect, ping). They are
  `tekartik_app_dev_menu` menus, run them from a checkout of the repo.
* Writing the services and the client under test is covered by the
  `tekartik-rpc-server` and `tekartik-rpc-client` skills of `tekartik_rpc`.

## Examples

### Memory: both suites, runs everywhere

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

### io: real sockets, VM only

```dart
@TestOn('vm')
library;

import 'package:tekartik_rpc_test/rpc_client_test.dart';
import 'package:tekartik_rpc_test/rpc_server_test.dart';
import 'package:tekartik_web_socket_io/web_socket_io.dart';
import 'package:test/test.dart';

void main() {
  group('rpc_io', () {
    rpcTests(webSocketChannelFactoryIo);
    rpcClientTests(webSocketChannelClientFactoryIo);
  });
}
```

### Browser: client suite only

```dart
@TestOn('browser')
library;

import 'package:tekartik_rpc_test/rpc_client_test.dart';
import 'package:tekartik_web_socket_browser/web_socket_browser.dart';
import 'package:test/test.dart';

void main() {
  group('rpc_browser', () {
    rpcClientTests(webSocketChannelClientFactoryBrowser);
  });
}
```

### Reusing PingRpcService and RpcTestContext

```dart
import 'package:tekartik_rpc/rpc_client.dart';
import 'package:tekartik_rpc/rpc_server.dart';
import 'package:tekartik_rpc_test/rpc_server_test.dart';
import 'package:tekartik_web_socket/web_socket.dart';
import 'package:test/test.dart';

void main() {
  group('my_server', () {
    late RpcTestContext ctx;

    setUpAll(() async {
      ctx = RpcTestContext(webSocketChannelFactoryMemory);
      await ctx.setUp();
    });
    tearDownAll(() async {
      await ctx.tearDown();
    });

    test('empty server has no service', () async {
      var rpcClient = await RpcClient.connect(
        Uri.parse(ctx.rpcServer.url),
        webSocketChannelClientFactory: ctx.webSocketChannelFactory.client,
      );
      try {
        await rpcClient.sendServiceRequest<String>('ping_service', 'ping', null);
        fail('should fail');
      } on RpcException catch (e) {
        expect(e.code, 'rpc_exception_unsupported');
      }
      await rpcClient.close();
    });

    test('ping service answers', () async {
      var rpcServer = await RpcServer.serve(
        webSocketChannelServerFactory: webSocketChannelFactoryMemory.server,
        services: [PingRpcService()],
      );
      var rpcClient = await RpcClient.connect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: webSocketChannelFactoryMemory.client,
      );
      expect(
        await rpcClient.sendServiceRequest<String>('ping_service', 'ping', null),
        'pong',
      );
      await rpcClient.close();
      await rpcServer.close();
    });
  });
}
```

## Common mistakes

* Calling `rpcTests` in a browser test: it serves, so it needs the memory or
  io factory on the VM; use `rpcClientTests` on the browser.
* Awaiting `rpcTests(...)` or calling it inside a `test(...)` body - it only
  declares groups, call it at `main()` level.
* Passing a client factory where a `WebSocketChannelFactory` (client +
  server) is expected.
* Depending on `tekartik_rpc_test` as a regular dependency: it is a test-only
  package and pulls `dev_test` and the dev menu in.
