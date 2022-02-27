import 'package:tekartik_rpc/rpc.dart';

import 'rpc_client.dart';

class RpcServiceClient {
  final RpcClient _client;
  final String name;

  RpcServiceClient(this._client, this.name);

  // New!
  Future<T> sendRequest<T>(RpcMethodCall methodCall) {
    return _client.sendServiceRequest(
        name, methodCall.method, methodCall.arguments);
  }
}
