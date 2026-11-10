/// Rpc client: [RpcClient.connect] (one connection) and
/// [AutoConnectRpcClient.autoConnect] (reconnects), calling the services of
/// an rpc server with [RpcClient.sendServiceRequest]. Runs on every platform.
library;

export 'package:tekartik_web_socket/web_socket_client.dart'
    show WebSocketChannelClientFactory;

export 'rpc.dart';
export 'src/rpc_client.dart'
    show
        RpcClient,
        AutoConnectRpcClient,
        debugRpcClient,
        RpcClientOnConnect,
        RpcClientException,
        RpcClientConnectionException;
export 'src/web_socket_factory.dart'
    show rpcWebSocketChannelClientFactoryUniversal;
