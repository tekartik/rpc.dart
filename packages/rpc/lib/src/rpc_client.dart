import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:synchronized/synchronized.dart';
import 'package:tekartik_common_utils/future_utils.dart';
import 'package:tekartik_rpc/src/constant.dart';
import 'package:tekartik_rpc/src/rpc_core_service_client.dart';
import 'package:tekartik_rpc/src/rpc_exception.dart';
import 'package:tekartik_rpc/src/rpc_service_client.dart';
import 'package:tekartik_rpc/src/web_socket_factory.dart';
import 'package:tekartik_web_socket/web_socket_client.dart';

import 'log_utils.dart';

/// Debug flag
var debugRpcClient = false;
void _log(Object? message) {
  log('rpc_client', message);
}

/// Rpc client
typedef RpcClientOnConnect = FutureOr<void> Function(RpcClient client);

/// Auto connect rpc client
abstract class AutoConnectRpcClient implements RpcClient {
  /// Connect, should not fail
  factory AutoConnectRpcClient.autoConnect(
    Uri uri, {
    WebSocketChannelClientFactory? webSocketChannelClientFactory,

    /// One connect callback
    RpcClientOnConnect? onConnect,
  }) {
    webSocketChannelClientFactory ??= rpcWebSocketChannelClientFactoryUniversal;

    return _AutoConnectRpcClient(
        uri: uri,
        webSocketChannelClientFactory: webSocketChannelClientFactory,
        onConnect: onConnect);
  }
}

class _AutoConnectRpcClient
    with RpcClientMixin
    implements AutoConnectRpcClient {
  final WebSocketChannelClientFactory webSocketChannelClientFactory;
  final RpcClientOnConnect? onConnect;
  final _lock = Lock();
  final Uri uri;

  /// Preveent reconnect
  var _forceClosed = false;

  Future<RpcClient> connect() async {
    if (innerRpcClient == null) {
      return _lock.synchronized(() async {
        if (innerRpcClient != null) {
          return innerRpcClient!;
        }
        var rpcClient = innerRpcClient = await RpcClient.connect(uri,
            onConnect: onConnect,
            webSocketChannelClientFactory: webSocketChannelClientFactory);
        rpcClient.done.then((_) {
          if (debugRpcClient) {
            _log('innerRpcClient disconnected');
          }
          innerRpcClient = null;
        }).unawait();
        return rpcClient;
      });
    } else {
      return innerRpcClient!;
    }
  }

  RpcClient? innerRpcClient;

  _AutoConnectRpcClient(
      {required this.uri,
      required this.webSocketChannelClientFactory,
      required this.onConnect});
  @override
  Future<void> close() async {
    _forceClosed = true;
    await innerRpcClient?.close();
    innerRpcClient = null;
    setDone();
  }

  final delays = <int>[100, 200, 400, 800, 1600, 3200, 6400, 12800];

  Future<T> _try<T>(Future<T> Function(RpcClient rpcClient) action) async {
    RpcClientConnectionException? lastError;
    for (var delay in delays) {
      try {
        if (_forceClosed) {
          throw RpcClientConnectionException._('Closed');
        }
        var rpcClient = await connect();
        return await action(rpcClient);
      } on RpcClientConnectionException catch (e) {
        lastError = e;
        _log('Failed to connect $e');

        await Future<void>.delayed(Duration(milliseconds: delay));
      } on StateError catch (e) {
        lastError = RpcClientConnectionException._(e);
        _log('Bad state $e');
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
      innerRpcClient = null;
    }
    if (lastError != null) {
      throw lastError;
    }
    throw RpcClientConnectionException._(TimeoutException('Retry failed'));
  }

  @override
  Future<T> sendRequest<T>(String method, Object? param) {
    return _try<T>((rpcClient) async {
      return await rpcClient.sendRequest<T>(method, param);
    });
  }

  @override
  Future<T> sendServiceRequest<T>(
      String service, String method, Object? param) async {
    return _try<T>((rpcClient) async {
      return await rpcClient.sendServiceRequest<T>(service, method, param);
    });
  }
}

/// Mixin to add done future and more
mixin RpcClientMixin {
  final _doneCompleter = Completer<void>();

  /// done future
  Future<void> get done => _doneCompleter.future;

  /// Mark done
  void setDone() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}

class _RpcClient with RpcClientMixin implements RpcClient {
  final json_rpc.Client client;
  _RpcClient({required this.client});

  Future<T> _wrapException<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on json_rpc.RpcException catch (e) {
      /// Convert json rpc exception to our world
      if (e.code == jsonRpcExceptionIntCodeService) {
        var jsonRpcExceptionData = e.data as Map;
        var code = jsonRpcExceptionData[keyCode] as String;
        var data = jsonRpcExceptionData[keyData];
        throw RpcException(code, e.message, data);
      }
      throw RpcException(rpcExceptionCodeJsonRpc, e.message,
          {keyData: e.data, keyCode: e.code});
    }
  }

  /// Send a request, get a response
  @override
  Future<T> sendRequest<T>(String method, Object? param) async {
    T t;
    try {
      if (debugRpcClient) {
        _log('sendRequest: $method $param');
      }
      t = await _wrapException(() => client.sendRequest(method, param)) as T;

      /// Debug helper
      if (debugRpcClient) {
        _log('sendRequest result: $t');
      }
    } on json_rpc.RpcException catch (e) {
      // devPrint('ERROR ${e.runtimeType} $e ${e.message} ${e.data}');
      throw RpcException(rpcExceptionCodeJsonRpc, e.message, e.data);
    }
    return t;
  }

  /// New!
  @override
  Future<T> sendServiceRequest<T>(
      String service, String method, Object? param) {
    return sendRequest<T>(jsonRpcMethodService,
        {keyService: service, keyMethod: method, keyData: param});
  }

  /// Close the client
  @override
  Future<void> close() => client.close();
}

/// Exception
abstract class RpcClientException implements Exception {}

/// Failure to connect
class RpcClientConnectionException implements RpcClientException {
  final Object _cause;

  /// Constructor
  RpcClientConnectionException._(this._cause);
  @override
  String toString() {
    return 'RpcClientConnectionException(cause: $_cause)';
  }
}

/// Instance of a server
abstract class RpcClient {
  /// Returns a [Future] that completes when the underlying connection is
  /// closed.
  ///
  /// This is the same future that's returned by [listen] and [close]. It may
  /// complete before [close] is called if the remote endpoint closes the
  /// connection.
  Future<void> get done;

  /// Connect to a server, throws RpcClientConnectionException on error
  static Future<RpcClient> connect(
    Uri url, {
    WebSocketChannelClientFactory? webSocketChannelClientFactory,
    RpcClientOnConnect? onConnect,
  }) async {
    webSocketChannelClientFactory ??= rpcWebSocketChannelClientFactoryUniversal;
    WebSocketChannel<String> webSocketChannel;
    try {
      webSocketChannel =
          webSocketChannelClientFactory.connect<String>(url.toString());
      await webSocketChannel.ready;
    } catch (e) {
      throw RpcClientConnectionException._(e);
    }
    var jsonRpcClient = json_rpc.Client(webSocketChannel);

    unawaited(jsonRpcClient.listen());

    var rpcClient = _RpcClient(client: jsonRpcClient);
    var coreServiceClient =
        RpcCoreServiceClient(RpcServiceClient(rpcClient, coreServiceName));
    await coreServiceClient.init();
    await onConnect?.call(rpcClient);
    jsonRpcClient.done.then((_) {
      rpcClient.setDone();
    }).unawait();
    return rpcClient;
  }

  /// Send a request, get a response
  Future<T> sendRequest<T>(String method, Object? param);

  /// New!
  Future<T> sendServiceRequest<T>(String service, String method, Object? param);

  /// Close the client
  Future<void> close();
}
