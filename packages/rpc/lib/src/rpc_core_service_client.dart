import 'package:tekartik_rpc/rpc.dart';
import 'package:tekartik_rpc/src/constant.dart';
import 'package:tekartik_rpc/src/rpc_service_client.dart';

class RpcCoreServiceClient {
  final RpcServiceClient client;

  RpcCoreServiceClient(this.client);

  Future<void> init() async {
    await client.sendRequest<void>(RpcMethodCall(coreServiceMethodeInit));
  }
}
