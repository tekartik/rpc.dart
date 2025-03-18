import 'package:tekartik_rpc/rpc.dart';
import 'package:tekartik_rpc/src/constant.dart';
import 'package:tekartik_rpc/src/rpc_service_client.dart';

/// Core service client
class RpcCoreServiceClient {
  /// Service client
  final RpcServiceClient client;

  /// Constructor
  RpcCoreServiceClient(this.client);

  /// Init
  Future<void> init() async {
    await client.sendRequest<void>(const RpcMethodCall(coreServiceMethodeInit));
  }
}
