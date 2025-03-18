import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:tekartik_rpc/src/constant.dart';
import 'package:tekartik_rpc/src/rpc_core_service_client.dart';
import 'package:tekartik_rpc/src/rpc_exception.dart';
import 'package:tekartik_rpc/src/rpc_service_client.dart';
import 'package:tekartik_web_socket_io/web_socket_io.dart';
import 'log_utils.dart';

/// Debug flag
var debugRpcClient = false;
void _log(Object? message) {
  log('rpc_client', message);
}

/// Instance of a server
class RpcClient {
  RpcClient._(this._client);

  final json_rpc.Client _client;

  /// Connect to a server
  static Future<RpcClient> connect(
    Uri url, {
    WebSocketChannelClientFactory? webSocketChannelClientFactory,
  }) async {
    webSocketChannelClientFactory ??= webSocketChannelClientFactoryIo;
    var webSocketChannel =
        webSocketChannelClientFactory.connect<String>(url.toString());
    var jsonRpcClient = json_rpc.Client(webSocketChannel);

    unawaited(jsonRpcClient.listen());

    var rpcClient = RpcClient._(jsonRpcClient);
    var coreServiceClient =
        RpcCoreServiceClient(RpcServiceClient(rpcClient, coreServiceName));
    await coreServiceClient.init();
    /*
    try {
      var serverInfo = await rpcClient.sendRequest(methodInit) as Map;
      if (serverInfo[keyName] != serverInfoName) {
        throw 'invalid name in $serverInfo';
      }
      var version = Version.parse(serverInfo[keyVersion] as String);
      if (version < serverInfoMinVersion) {
        throw 'SQFlite server version $version not supported, >=$serverInfoMinVersion expected';
      }
      var rawContext = serverInfo[keyContext] as Map;
      _serverInfo = DevshContext.fromJsonMap(rawContext);
    } catch (e) {
      await rpcClient.close();
      rethrow;
    }

     */
    return rpcClient;
  }

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
  Future<T> sendRequest<T>(String method, Object? param) async {
    T t;
    try {
      if (debugRpcClient) {
        _log('sendRequest: $method $param');
      }
      t = await _wrapException(() => _client.sendRequest(method, param)) as T;

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
  Future<T> sendServiceRequest<T>(
      String service, String method, Object? param) {
    return sendRequest<T>(jsonRpcMethodService,
        {keyService: service, keyMethod: method, keyData: param});
  }

  /// Close the client
  Future<void> close() => _client.close();
}
