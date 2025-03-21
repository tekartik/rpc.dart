import 'package:tekartik_rpc/rpc.dart';

import 'rpc_client.dart';

/// Service client
class RpcServiceClient {
  final RpcClient _client;

  /// Service name
  final String name;

  /// Constructor
  RpcServiceClient(this._client, this.name);

  /// Service request
  Future<T> sendRequest<T>(RpcMethodCall methodCall) {
    return _client.sendServiceRequest(
        name, methodCall.method, methodCall.arguments);
  }
}
