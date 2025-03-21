import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tekartik_web_socket_browser/web_socket_browser.dart';
import 'package:tekartik_web_socket_io/web_socket_io.dart';

/// The best platform web socket client factory
WebSocketChannelClientFactory get rpcWebSocketChannelClientFactoryUniversal =>
    kDartIsWeb
        ? webSocketChannelClientFactoryBrowser
        : webSocketChannelClientFactoryIo;
