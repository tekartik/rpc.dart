---
name: tekartik-rpc-client
description: >-
  Use when calling a tekartik_rpc WebSocket JSON-RPC server from Dart, Flutter
  or the browser: RpcClient.connect, AutoConnectRpcClient.autoConnect,
  sendServiceRequest, RpcClient.done/close, RpcClientOnConnect,
  RpcClientConnectionException, RpcClientException, catching RpcException
  codes, rpcWebSocketChannelClientFactoryUniversal,
  WebSocketChannelClientFactory, debugRpcClient and the
  package:tekartik_rpc/rpc_client.dart import.
---

# tekartik_rpc client side (tekartik_rpc)

`package:tekartik_rpc/rpc_client.dart` connects to a `tekartik_rpc` server
over a WebSocket and sends `service.method(data)` requests. Unlike the server
library it is platform-free: it picks a `dart:io` or a browser WebSocket at
runtime, so the same code runs in a Dart VM app, a Flutter app and on the web.

## Guidelines

* Dependency (git only, not on pub.dev):
  ```yaml
  dependencies:
    tekartik_rpc:
      git:
        url: https://github.com/tekartik/rpc.dart
        path: packages/rpc
      version: '>=0.1.0'
  ```
* Import `package:tekartik_rpc/rpc_client.dart` only. It re-exports
  `RpcMethodCall` and `RpcException` (from `rpc.dart`), `RpcClient`,
  `AutoConnectRpcClient`, `RpcClientOnConnect`, `RpcClientException`,
  `RpcClientConnectionException`, `debugRpcClient`, plus
  `WebSocketChannelClientFactory` and
  `rpcWebSocketChannelClientFactoryUniversal`. Never import
  `rpc_server.dart` from shared or web code: it depends on `dart:io`.
* One-shot connection: `await RpcClient.connect(Uri.parse('ws://host:port'))`.
  It performs a handshake against the built-in core service, then calls the
  optional `onConnect` callback. It throws `RpcClientConnectionException`
  (an `RpcClientException`) when the socket cannot be opened - wrap it in a
  `try`/`catch`, there is no retry.
* Resilient connection: `AutoConnectRpcClient.autoConnect(uri)` is
  synchronous and never fails at creation. Each request connects lazily and
  retries with a growing backoff (100ms up to 12.8s, 8 attempts) on
  connection errors and `StateError`, so it survives a server restart;
  `onConnect` runs again on every reconnection. After the last retry it
  throws `RpcClientConnectionException`.
* `webSocketChannelClientFactory` defaults to
  `rpcWebSocketChannelClientFactoryUniversal` (browser or io depending on
  `kDartIsWeb`). Pass `webSocketChannelFactoryMemory.client` (from
  `package:tekartik_web_socket/web_socket.dart`) in tests, or an explicit
  `webSocketChannelClientFactoryIo` / `webSocketChannelClientFactoryBrowser`
  when you must pin the platform.
* Call a server service with
  `await client.sendServiceRequest<T>(serviceName, method, data)`. `T` is the
  expected decoded JSON type (`String`, `int`, `Map<String, Object?>`,
  `Object?`, `void`); `data` must be JSON-encodable. `sendRequest(method,
  param)` talks raw JSON-RPC and a `tekartik_rpc` server does not register
  anything but the internal `service` method, so use `sendServiceRequest`.
* Errors from the server surface as `RpcException` with `code`, `message` and
  `arguments`. Branch on `e.code`: the codes a service throws itself, plus
  `rpc_exception_unsupported` (unknown service or method) and
  `rpc_exception_json` (the service threw something that was not an
  `RpcException`; `e.arguments` is then a map whose `data` entry holds the
  remote text and stack).
* `client.done` completes when the connection is closed from either side -
  useful to trigger a reconnect or to tear down a UI. `await client.close()`
  closes it; on an `AutoConnectRpcClient` it also stops any further retry.
* `debugRpcClient = true` logs every request and result to stdout; keep it
  off in committed code.
* Server-side services, `RpcServer.serve` and error contracts are in
  [../tekartik-rpc-server/SKILL.md](../tekartik-rpc-server/SKILL.md).

## Examples

### Connect, call, close

```dart
import 'package:tekartik_rpc/rpc_client.dart';

Future<void> main() async {
  var rpcClient = await RpcClient.connect(Uri.parse('ws://localhost:8060'));
  try {
    var pong = await rpcClient.sendServiceRequest<String>(
      'simple',
      'ping',
      null,
    );
    print(pong);
  } finally {
    await rpcClient.close();
  }
}
```

### Handling a failed connection and remote errors

```dart
import 'package:tekartik_rpc/rpc_client.dart';

Future<Object?> getUser(Uri uri, String id) async {
  RpcClient rpcClient;
  try {
    rpcClient = await RpcClient.connect(uri);
  } on RpcClientConnectionException catch (e) {
    print('server unreachable: $e');
    return null;
  }
  try {
    return await rpcClient.sendServiceRequest<Object?>('user', 'get', id);
  } on RpcException catch (e) {
    if (e.code == 'user_not_found') {
      return null;
    }
    if (e.code == 'rpc_exception_unsupported') {
      print('service or method missing on the server');
    }
    rethrow;
  } finally {
    await rpcClient.close();
  }
}
```

### Long-lived auto-reconnecting client

```dart
import 'package:tekartik_rpc/rpc_client.dart';

class RemoteApi {
  RemoteApi(Uri uri)
    : _client = AutoConnectRpcClient.autoConnect(
        uri,
        onConnect: (client) async {
          // Runs on the first connection and after each reconnection.
          await client.sendServiceRequest<void>('simple', 'ping', null);
        },
      );

  final RpcClient _client;

  Future<num> add(num a, num b) =>
      _client.sendServiceRequest<num>('simple', 'add', {'a': a, 'b': b});

  Future<void> close() => _client.close();
}
```

### Reacting to the server going away

```dart
import 'package:tekartik_rpc/rpc_client.dart';

Future<void> watch(Uri uri) async {
  var rpcClient = await RpcClient.connect(
    uri,
    webSocketChannelClientFactory: rpcWebSocketChannelClientFactoryUniversal,
  );
  unawaitedDone(rpcClient);
}

void unawaitedDone(RpcClient rpcClient) {
  rpcClient.done.then((_) {
    print('connection closed by the server');
  });
}
```

### Talking to a memory server in a test

```dart
import 'package:tekartik_rpc/rpc_client.dart';
import 'package:tekartik_web_socket/web_socket.dart';
import 'package:test/test.dart';

void main() {
  test('no server', () async {
    await expectLater(
      RpcClient.connect(
        Uri.parse('ws://localhost:9999'),
        webSocketChannelClientFactory: webSocketChannelFactoryMemory.client,
      ),
      throwsA(isA<RpcClientConnectionException>()),
    );
  });
}
```

## Common mistakes

* Using `sendRequest` instead of `sendServiceRequest`: a `tekartik_rpc`
  server routes service calls only.
* Letting `RpcClient.connect` throw uncaught at app start-up; use
  `AutoConnectRpcClient.autoConnect` when the server may not be up yet.
* Asking for a `T` that does not match the JSON the service returns (a
  `Map<String, Object?>` comes back as `Map<String, dynamic>`; ask for
  `Object?` or cast).
* Importing `package:tekartik_rpc/rpc_server.dart` in code that also targets
  the web.
* Reusing an `RpcClient` after `close()`.
