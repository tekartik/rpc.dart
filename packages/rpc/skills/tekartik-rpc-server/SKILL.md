---
name: tekartik-rpc-server
description: >-
  Use when exposing methods over a WebSocket JSON-RPC server with
  tekartik_rpc: RpcServer.serve, RpcService, RpcServiceBase, onCall,
  RpcMethodCall, RpcServerChannel, channels/url/port/uri,
  onClientConnected/onClientDisconnected, throwing RpcException from a
  service, debugRpcServer, webSocketChannelServerFactoryIo and the
  package:tekartik_rpc/rpc_server.dart import, plus serving on a memory
  factory in tests.
---

# tekartik_rpc server side (tekartik_rpc)

`tekartik_rpc` is a thin abstraction over `json_rpc_2` running on a
`tekartik_web_socket` channel. A server is a list of named services; a client
calls `service.method(data)` and gets a JSON value back. The server library
pulls in `dart:io`, so it runs on the VM (or Flutter native), never in a
browser.

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
* Import `package:tekartik_rpc/rpc_server.dart`. It re-exports
  `package:tekartik_rpc/rpc.dart` (`RpcMethodCall`, `RpcException`), the
  server API (`RpcServer`, `RpcServerChannel`, `RpcService`,
  `RpcServiceBase`, `debugRpcServer`) and, from `tekartik_web_socket_io`,
  `WebSocketChannelServerFactory` and `webSocketChannelServerFactoryIo`.
  Do not import `src/` files.
* A service is a class extending `RpcServiceBase(name)` that overrides
  `onCall(RpcServerChannel channel, RpcMethodCall methodCall)`. Dispatch on
  `methodCall.method`, read `methodCall.arguments`, and always end with
  `return super.onCall(channel, methodCall);` so unknown methods raise the
  standard `RpcException` with code `rpc_exception_unsupported`.
* Start with `await RpcServer.serve(services: [MyService()], port: 8060)`.
  All parameters but `services` are optional: `webSocketChannelServerFactory`
  (defaults to `webSocketChannelServerFactoryIo`), `address`, `port` (omit or
  `null` for a free port), `notifyCallback`, `onClientConnected`,
  `onClientDisconnected`.
* Read back `rpcServer.url` (a `ws://host:port` string), `rpcServer.uri`,
  `rpcServer.port`; `rpcServer.channels` is the live list of
  `RpcServerChannel` (one per connected client, `channel.id` is an
  incrementing int, `channel.close()` drops that one client).
  `rpcServer.close()` stops the server and completes every client's
  `RpcClient.done`.
* A `tekartik_rpc` server only registers the single JSON-RPC method
  `service`; there is no API to register a bare JSON-RPC method. Everything
  goes through `RpcService.onCall`, and clients must use
  `sendServiceRequest`, not `sendRequest`.
* Arguments and results must be JSON-encodable (`null`, num, String, bool,
  `List`, `Map<String, Object?>`); they cross `json_rpc_2` untouched. Encode
  model objects yourself (`toMap()` / `cv` models) before returning them.
* Errors: throw `RpcException(code, message, arguments)` for an error the
  client should recognise - it arrives client-side as an `RpcException` with
  the same `code`, `message` and `arguments`. Any other thrown object is
  wrapped with code `rpc_exception_json`, a message containing the original
  text and an `arguments` map holding `data` (full text, stack, request).
  Prefer explicit `RpcException`s for anything the client branches on.
* Service names are unique: `RpcServer.serve` asserts on duplicates, and the
  name `tekartik_rpc` is reserved for the built-in core service used by the
  client handshake.
* `debugRpcServer = true` prints every channel event on stdout; pair it with
  `debugRpcClient` when debugging a connection. Leave both false in
  committed code.
* Testing: pass `webSocketChannelFactoryMemory.server` (from
  `package:tekartik_web_socket/web_socket.dart`) as
  `webSocketChannelServerFactory` to run client and server in-process with no
  socket at all - these tests then also run on the browser. The shared suites
  of `tekartik_rpc_test` (`rpcTests(factory)`) are described in the
  `tekartik-rpc-test-suite` skill.
* Client-side usage (connecting, auto-reconnect, catching `RpcException`) is
  in [../tekartik-rpc-client/SKILL.md](../tekartik-rpc-client/SKILL.md).

## Examples

### A service and a server on a fixed port

```dart
import 'dart:async';

import 'package:tekartik_rpc/rpc_server.dart';

const simpleRpcServiceName = 'simple';

class SimpleRpcService extends RpcServiceBase {
  SimpleRpcService() : super(simpleRpcServiceName);

  @override
  FutureOr<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
    switch (methodCall.method) {
      case 'ping':
        return 'pong ${channel.id}';
      case 'add':
        var args = (methodCall.arguments as Map).cast<String, Object?>();
        return (args['a'] as num) + (args['b'] as num);
    }
    return super.onCall(channel, methodCall);
  }
}

Future<void> main() async {
  var rpcServer = await RpcServer.serve(
    services: [SimpleRpcService()],
    port: 8060,
  );
  print('listening on ${rpcServer.url}');
}
```

### Reporting errors the client can branch on

```dart
import 'dart:async';

import 'package:tekartik_rpc/rpc_server.dart';

class UserRpcService extends RpcServiceBase {
  UserRpcService() : super('user');

  final _users = <String, Object?>{'1': 'alex'};

  @override
  FutureOr<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
    if (methodCall.method == 'get') {
      var id = methodCall.arguments as String;
      var user = _users[id];
      if (user == null) {
        // Client side: catch RpcException, e.code == 'user_not_found'.
        throw RpcException('user_not_found', 'No user $id', {'id': id});
      }
      return user;
    }
    return super.onCall(channel, methodCall);
  }
}
```

### Tracking connected clients and pushing a shutdown

```dart
import 'package:tekartik_rpc/rpc_server.dart';

Future<RpcServer> serveOnFreePort() async {
  var rpcServer = await RpcServer.serve(
    services: [],
    onClientConnected: (channel) => print('connected ${channel.id}'),
    onClientDisconnected: (channel) => print('disconnected ${channel.id}'),
  );
  print('serving on ${rpcServer.uri} (port ${rpcServer.port})');
  return rpcServer;
}

Future<void> disconnectEveryone(RpcServer rpcServer) async {
  for (var channel in rpcServer.channels) {
    await channel.close();
  }
}
```

### Server and client in memory, in a test

```dart
import 'package:tekartik_rpc/rpc_client.dart';
import 'package:tekartik_rpc/rpc_server.dart';
import 'package:tekartik_web_socket/web_socket.dart';
import 'package:test/test.dart';

class EchoRpcService extends RpcServiceBase {
  EchoRpcService() : super('echo');

  @override
  Future<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
    if (methodCall.method == 'echo') {
      return methodCall.arguments;
    }
    return super.onCall(channel, methodCall);
  }
}

void main() {
  test('echo', () async {
    var factory = webSocketChannelFactoryMemory;
    var rpcServer = await RpcServer.serve(
      webSocketChannelServerFactory: factory.server,
      services: [EchoRpcService()],
    );
    var rpcClient = await RpcClient.connect(
      Uri.parse(rpcServer.url),
      webSocketChannelClientFactory: factory.client,
    );
    expect(
      await rpcClient.sendServiceRequest<Object?>('echo', 'echo', {'a': 1}),
      {'a': 1},
    );
    await rpcClient.close();
    await rpcServer.close();
  });
}
```

## Common mistakes

* Importing `rpc_server.dart` from web code: it drags `dart:io` in.
* Forgetting `return super.onCall(channel, methodCall)` - unknown methods
  then silently return `null` instead of an `rpc_exception_unsupported`
  error.
* Returning a non JSON-encodable object (a model instance, a `DateTime`) from
  `onCall`.
* Expecting `client.sendRequest('myMethod', ...)` to reach a service: only
  `sendServiceRequest(service, method, data)` is routed.
* Registering two services with the same `name`, or reusing the reserved
  `tekartik_rpc` name.
