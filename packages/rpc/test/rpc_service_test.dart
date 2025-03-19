import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_rpc/rpc_client.dart';
import 'package:tekartik_rpc/rpc_server.dart';
import 'package:tekartik_web_socket/web_socket.dart';
import 'package:test/test.dart';

const simpleRcpServiceName = 'simple';

class SimpleRpcService extends RpcServiceBase {
  SimpleRpcService() : super(simpleRcpServiceName);

  @override
  FutureOr<Object?> onCall(
      RpcServerChannel channel, RpcMethodCall methodCall) async {
    var method = methodCall.method;
    if (method == 'ping') {
      return 'pong';
    }
    if (method == 'param') {
      return methodCall.arguments;
    }
    if (method == 'throw') {
      throw RpcException('throw', 'Throwing', const {});
    }
    if (method == 'throw_any') {
      throw StateError('Throwing any');
    }
    return super.onCall(channel, methodCall);
  }
}

void main() {
  // debugRpcClient = devWarning(true);
  // debugRpcServer = devWarning(true);
  WebSocketChannelFactory factory = webSocketChannelFactoryMemory;
  group('simple_service', () {
    late RpcServer rpcServer;
    late RpcClient rpcClient;
    setUpAll(() async {
      rpcServer = await RpcServer.serve(
          webSocketChannelServerFactory: factory.server,
          services: [SimpleRpcService()]);
      rpcClient = await RpcClient.connect(
        Uri.parse(rpcServer.url),
        webSocketChannelClientFactory: factory.client,
      );
    });
    tearDownAll(() async {
      await rpcServer.close();
    });
    test('ping', () async {
      var result = await rpcClient.sendServiceRequest<String>(
          simpleRcpServiceName, 'ping', null);
      expect(result, 'pong');
    });
    test('param', () async {
      var result = await rpcClient.sendServiceRequest<Object?>(
          simpleRcpServiceName, 'param', 1);
      expect(result, 1);
      result = await rpcClient.sendServiceRequest<Object?>(
          simpleRcpServiceName, 'param', {'test': 1});
      expect(result, {'test': 1});
      result = await rpcClient.sendServiceRequest(
          simpleRcpServiceName, 'param', null);
      expect(result, isNull);
    });
    test('dummy', () async {
      try {
        await rpcClient.sendServiceRequest<void>(
            simpleRcpServiceName, 'dummy', null);
      } on RpcException catch (e) {
        // RpcException(rpc_exception_unsupported, simple: onCall(dummy) not supported
        expect(e.code, 'rpc_exception_unsupported');
        // 'simple: onCall(dummy) not supported'
        expect(e.message, contains('supported'));
      }
    });
    test('throw', () async {
      try {
        await rpcClient.sendServiceRequest<void>(
            simpleRcpServiceName, 'throw', null);
      } on RpcException catch (e) {
        // RpcException(throw, Throwing, {})
        expect(e.code, 'throw');
        expect(e.message, 'Throwing');
        // ignore: inference_failure_on_collection_literal
        expect(e.arguments, {});
      }
    });

    test('throw_any', () async {
      try {
        await rpcClient.sendServiceRequest<void>(
            simpleRcpServiceName, 'throw_any', null);
      } on RpcException catch (e) {
        //   'data': {
        //               'full': 'Bad state: Throwing any',
        //               'stack': 'test/rpc_service_test.dart 24:7
        //               'request': {
        //                 'jsonrpc': '2.0',
        //                 'method': 'service',
        //                 'id': 1,
        //                 'params': {'service': 'simple', 'method': 'throw_any', 'data': null}
        //               }
        expect(e.code, 'rpc_exception_json');
        expect(e.message, contains('Throwing any'));
        expect((e.arguments as Map)['data'], isNotNull);
      }
    });
  });
}
