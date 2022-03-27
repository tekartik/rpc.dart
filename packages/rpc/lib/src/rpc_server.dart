import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:tekartik_rpc/rpc.dart';
import 'package:tekartik_rpc/src/constant.dart';
import 'package:tekartik_rpc/src/rpc_core_service.dart';
import 'package:tekartik_rpc/src/rpc_exception.dart';
import 'package:tekartik_rpc/src/rpc_service.dart';

import 'import.dart';

typedef SqfliteServerNotifyCallback = void Function(
    bool response, String method, Object? params);

/// Web socket server
class RpcServer {
  final Map<String, RpcService> _servicesMap;

  RpcService? _serviceByName(String name) => _servicesMap[name];

  RpcServer._(
      this._webSocketChannelServer, this._notifyCallback, this._servicesMap) {
    _webSocketChannelServer.stream.listen((WebSocketChannel<String> channel) {
      _channels.add(RpcServerChannel(this, channel));
    });
  }

  final SqfliteServerNotifyCallback? _notifyCallback;
  final List<RpcServerChannel> _channels = [];
  final WebSocketChannelServer<String> _webSocketChannelServer;

  static Future<RpcServer> serve(
      {WebSocketChannelServerFactory? webSocketChannelServerFactory,
      Object? address,
      int? port,
      SqfliteServerNotifyCallback? notifyCallback,
      required List<RpcService> services}) async {
    // Check services argument
    var servicesMap = <String, RpcService>{};
    void _registerService(RpcService service) {
      var name = service.name;
      assert(!servicesMap.containsKey(name));
      servicesMap[name] = service;
    }

    // Add core service
    _registerService(RpcCoreService());
    for (var service in services) {
      _registerService(service);
    }

    webSocketChannelServerFactory ??= webSocketChannelServerFactoryIo;
    var webSocketChannelServer = await webSocketChannelServerFactory
        .serve<String>(address: address, port: port);

    return RpcServer._(webSocketChannelServer, notifyCallback, servicesMap);
  }

  Future close() => _webSocketChannelServer.close();

  String get url => _webSocketChannelServer.url;

  int get port => _webSocketChannelServer.port;
}

/// We have one channer per client
class RpcServerChannel {
  RpcServerChannel(this._rpcServer, WebSocketChannel<String> channel)
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
          result = await service.onCall(RpcMethodCall(method, data));
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
      print('done');
    });
  }

  final RpcServer _rpcServer;
  final json_rpc.Server _jsonRpcServer;

  SqfliteServerNotifyCallback? get _notifyCallback =>
      _rpcServer._notifyCallback;
}
