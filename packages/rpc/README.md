# tekartik_rpc

Remote procedure calls over a WebSocket, on top of `json_rpc_2`: a server
exposes named services (`RpcService`), a client calls
`service.method(data)` and gets a JSON value back, or an `RpcException`.

## Getting started

Git package, not on pub.dev:

```yaml
dependencies:
  tekartik_rpc:
    git:
      url: https://github.com/tekartik/rpc.dart
      path: packages/rpc
```

A service, a server on a free port and a client calling it
([example/main.dart](example/main.dart), it runs with `dart run example/main.dart`):

```dart
import 'dart:async';

import 'package:tekartik_rpc/rpc_client.dart';
import 'package:tekartik_rpc/rpc_server.dart';

class GreetingService extends RpcServiceBase {
  GreetingService() : super('greeting');

  @override
  FutureOr<Object?> onCall(
    RpcServerChannel channel,
    RpcMethodCall methodCall,
  ) async {
    switch (methodCall.method) {
      case 'hello':
        return 'hello ${methodCall.arguments}';
    }
    // Unknown method: RpcException rpc_exception_unsupported
    return super.onCall(channel, methodCall);
  }
}

Future<void> main() async {
  var server = await RpcServer.serve(services: [GreetingService()]);
  var client = await RpcClient.connect(server.uri);
  try {
    print(await client.sendServiceRequest<String>('greeting', 'hello', 'you'));
  } finally {
    await client.close();
    await server.close();
  }
}
```

[example/server.dart](example/server.dart) and
[example/client.dart](example/client.dart) do the same in two processes
(port 8060).

## Platforms

* Client (`rpc_client.dart`): Dart VM, Flutter (mobile, desktop, web), browser
  (dart2js and dart2wasm). The WebSocket is picked at runtime
  (`rpcWebSocketChannelClientFactoryUniversal`: `dart:io` or browser).
* Server (`rpc_server.dart`): Dart VM and Flutter native
  (`webSocketChannelServerFactoryIo`, the default). With the memory factory
  (`webSocketChannelFactoryMemory.server`) server and client run in one
  isolate on every platform, for tests.

## What to use

| You want | Use |
|---|---|
| Expose methods | a class extending `RpcServiceBase(name)` overriding `onCall`, served by `RpcServer.serve(services: [...])` |
| One connection, fail when the server is down | `RpcClient.connect(uri)` (throws `RpcClientConnectionException`) |
| A long lived client surviving server restarts | `AutoConnectRpcClient.autoConnect(uri)` (connects on the first call, retries for about 25 s) |
| Call a service | `client.sendServiceRequest<T>(service, method, data)` |
| A business error the client can test | `throw RpcException(code, message, arguments)` in `onCall` |
| Tests without sockets | `webSocketChannelFactoryMemory` from `package:tekartik_web_socket/web_socket.dart` |

## Common pitfalls

* Use `sendServiceRequest`: the server only routes service calls,
  `sendRequest` is raw JSON-RPC.
* Arguments and results must be JSON values (`null`, `num`, `String`, `bool`,
  `List`, `Map` with `String` keys).
* End `onCall` with `return super.onCall(channel, methodCall);`, so that an
  unknown method fails with `rpc_exception_unsupported` instead of returning
  null.
* An error other than `RpcException` reaches the client as an `RpcException`
  with code `rpc_exception_json` whose `arguments` hold the error text and the
  server stack trace: throw `RpcException` for anything a client may see.
* `AutoConnectRpcClient` sends a request again when the connection dropped
  before the answer: a call may then run twice on the server (make the
  methods idempotent).
* When `onConnect` throws, `RpcClient.connect` closes the connection and
  throws that error (not an `RpcClientConnectionException`).
* Service names are unique (`tekartik_rpc` is the built-in core service). A
  duplicate is only checked by an assert: in release the last one wins.
* `onClientConnected`/`onClientDisconnected` are not awaited and their errors
  are not caught.

## Testing

```bash
dart test                      # vm and chrome (dart2js)
dart test -p chrome -c dart2wasm
```

The shared suites are in `tekartik_rpc_test` (`rpcTests(factory)`,
`rpcClientTests(clientFactory)`).
