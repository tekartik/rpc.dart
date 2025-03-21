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
  log('rpc_client', message);
}

/// Notify callback
typedef RpcServerNotifyCallback = void Function(
    bool response, String method, Object? params);

/// Web socket server
class RpcServer {
  final Map<String, RpcService> _servicesMap;

  RpcService? _serviceByName(String name) => _servicesMap[name];

  RpcServer._(
      this._webSocketChannelServer, this._notifyCallback, this._servicesMap) {
    _webSocketChannelServer.stream.listen((WebSocketChannel<String> channel) {
      _channels.add(_RpcServerChannel(this, channel));
    });
  }

  final RpcServerNotifyCallback? _notifyCallback;
  final List<RpcServerChannel> _channels = [];
  final WebSocketChannelServer<String> _webSocketChannelServer;

  /// Serve
  static Future<RpcServer> serve(
      {WebSocketChannelServerFactory? webSocketChannelServerFactory,
      Object? address,
      int? port,
      RpcServerNotifyCallback? notifyCallback,
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
    return RpcServer._(webSocketChannelServer, notifyCallback, servicesMap);
  }

  /// Close
  Future close() => _webSocketChannelServer.close();

  /// Url
  String get url => _webSocketChannelServer.url;

  /// Port
  int get port => _webSocketChannelServer.port;
}

/// Server channel (one per client)
abstract class RpcServerChannel {
  /// Id (incremental)
  int get id;
}

/// We have one channel per client
class _RpcServerChannel implements RpcServerChannel {
  @override
  final int id = ++_lastChannelId;

  static var _lastChannelId = 0;

  /// Constructor
  _RpcServerChannel(this._rpcServer, WebSocketChannel<String> channel)
      : _jsonRpcServer = json_rpc.Server(channel) {
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
      }
    });
  }

  final RpcServer _rpcServer;
  final json_rpc.Server _jsonRpcServer;

  RpcServerNotifyCallback? get _notifyCallback => _rpcServer._notifyCallback;
}
