import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:tekartik_rpc/rpc.dart';
import 'package:tekartik_rpc/src/constant.dart';
import 'package:tekartik_rpc/src/rpc_core_service.dart';
import 'package:tekartik_rpc/src/rpc_exception.dart';
import 'package:tekartik_rpc/src/rpc_service.dart';
import 'package:tekartik_web_socket_io/web_socket_io.dart';

import 'import.dart';
import 'log_utils.dart';

/// Debug flag
var debugRpcServer = false;

void _log(Object? message) {
  log('rpc_server', message);
}

/// Server channel connection/disconnection callback
typedef RpcServerChannelConnectionCallback = FutureOr<void> Function(
    RpcServerChannel channel);

/// Notify callback
typedef RpcServerNotifyCallback = void Function(
    bool response, String method, Object? params);

/// Web socket server
abstract class RpcServer {
  /// Close
  Future<void> close();

  /// Connected channels (one per client)
  List<RpcServerChannel> get channels;

  /// Uri (to prefer over url)
  Uri get uri;

  /// Url
  String get url;

  /// Port
  int get port;

  /// Serve
  static Future<RpcServer> serve(
      {WebSocketChannelServerFactory? webSocketChannelServerFactory,
      Object? address,
      int? port,
      RpcServerNotifyCallback? notifyCallback,
      RpcServerChannelConnectionCallback? onClientConnected,
      RpcServerChannelConnectionCallback? onClientDisconnected,
      required List<RpcService> services}) async {
    // Check services argument
    var servicesMap = <String, RpcService>{};
    void registerService(RpcService service) {
      var name = service.name;
      assert(!servicesMap.containsKey(name));
      servicesMap[name] = service;
    }

    // Add core service
    registerService(RpcCoreService());
    for (var service in services) {
      registerService(service);
    }

    webSocketChannelServerFactory ??= webSocketChannelServerFactoryIo;
    var webSocketChannelServer = await webSocketChannelServerFactory
        .serve<String>(address: address, port: port);

    if (debugRpcServer) {
      _log('listening on ${webSocketChannelServer.url}');
    }
    return _RpcServer(webSocketChannelServer, notifyCallback, servicesMap,
        onClientConnected: onClientConnected,
        onClientDisconnected: onClientDisconnected);
  }
}

class _RpcServer implements RpcServer {
  final Map<String, RpcService> _servicesMap;
  final RpcServerChannelConnectionCallback? onClientConnected;
  final RpcServerChannelConnectionCallback? onClientDisconnected;
  RpcService? _serviceByName(String name) => _servicesMap[name];

  _RpcServer(
      this._webSocketChannelServer, this._notifyCallback, this._servicesMap,
      {required this.onClientConnected, required this.onClientDisconnected}) {
    _webSocketChannelServer.stream.listen((WebSocketChannel<String> channel) {
      var rpcServerChannel = _RpcServerChannel(this, channel);
      _channels.add(rpcServerChannel);
      onClientConnected?.call(rpcServerChannel);
    });
  }

  void removeChannel(_RpcServerChannel channel) {
    _channels.remove(channel);
    onClientDisconnected?.call(channel);
  }

  final RpcServerNotifyCallback? _notifyCallback;
  final List<RpcServerChannel> _channels = [];
  final WebSocketChannelServer<String> _webSocketChannelServer;

  /// Close
  @override
  Future<void> close() => _webSocketChannelServer.close();

  /// Url
  @override
  String get url => _webSocketChannelServer.url;

  /// Port
  @override
  int get port => _webSocketChannelServer.port;

  @override
  Uri get uri => Uri.parse(url);

  @override
  List<RpcServerChannel> get channels => _channels.toList(growable: false);
}

/// Server channel (one per client)
abstract class RpcServerChannel {
  /// Id (incremental)
  int get id;

  /// Close the corresponding channel
  Future<void> close();
}

/// We have one channel per client
class _RpcServerChannel implements RpcServerChannel {
  @override
  final int id = ++_lastChannelId;

  static var _lastChannelId = 0;

  /// Constructor
  _RpcServerChannel(this._rpcServer, WebSocketChannel<String> channel)
      : _jsonRpcServer = json_rpc.Server(channel) {
    if (debugRpcServer) {
      _log('new channel $id');
    }
    // Specific method for getting server info upon start
    _jsonRpcServer.registerMethod(jsonRpcMethodService,
        (json_rpc.Parameters parameters) async {
      try {
        if (_notifyCallback != null) {
          _notifyCallback!(false, jsonRpcMethodService, parameters.value);
        }

        Object? result;
        var map = parameters.asMap;
        var serviceName = map[keyService] as String;
        var service = _rpcServer._serviceByName(serviceName);
        if (service == null) {
          throw RpcException(rpcExceptionCodeUnsupported);
        } else {
          var method = map[keyMethod] as String;
          var data = map[keyData];
          result = await service.onCall(this, RpcMethodCall(method, data));
        }
        if (_notifyCallback != null) {
          _notifyCallback!(true, jsonRpcMethodService, result);
        }
        return result;
      } on RpcException catch (e) {
        /// RpcException to json_rpc
        throw json_rpc.RpcException(jsonRpcExceptionIntCodeService, e.message,
            data: {keyData: e.arguments, keyCode: e.code});
      } catch (e) {
        // devPrint('### Unhandled: $e');
        rethrow;
      }
    });

    _jsonRpcServer.listen();

    // Cleanup
    // close opened database
    _jsonRpcServer.done.then((_) async {
      if (debugRpcServer) {
        _log('done');
        _rpcServer.removeChannel(this);
      }
    });
  }

  final _RpcServer _rpcServer;
  final json_rpc.Server _jsonRpcServer;

  RpcServerNotifyCallback? get _notifyCallback => _rpcServer._notifyCallback;

  @override
  Future<void> close() async {
    if (debugRpcServer) {
      _log('closing channel $id');
    }
    await _jsonRpcServer.close();
  }
}
