import 'dart:async';

import 'package:tekartik_app_dev_menu/dev_menu.dart';
import 'package:tekartik_rpc/rpc_client.dart';

export 'package:tekartik_app_dev_menu/dev_menu.dart';

var _defaultPort = 4995;
var urlKv = '4338988.url'.kvFromVar(
  defaultValue: 'ws://localhost:${_defaultPort.toString()}',
);

int? get urlKvPort => int.tryParse((urlKv.value ?? '').split(':').last);

RpcClient? rpcClientOrNull;
RpcClient get rpcClient => rpcClientOrNull!;

const simpleRcpServiceName = 'simple';

Future<void> main(List<String> args) async {
  await mainMenu(args, () {
    rpcMainMenu();
  });
}

void rpcMainMenu() {
  menu('client', () {
    item('auto connect', () async {
      await rpcClientOrNull?.close();
      write('auto connecting to ${urlKv.value}');
      rpcClientOrNull = await AutoConnectRpcClient.autoConnect(
        Uri.parse(urlKv.value!),
      );
      write('auto connected');
    });
    item('connect', () async {
      await rpcClientOrNull?.close();
      write('connecting to ${urlKv.value}');
      rpcClientOrNull = await RpcClient.connect(Uri.parse(urlKv.value!));
      write('connected');
    });
    item('close', () async {
      await rpcClient.close();
      rpcClientOrNull = null;
      write('closed');
    });
    item('ping', () async {
      write(
        await rpcClient.sendServiceRequest(simpleRcpServiceName, 'ping', null),
      );
    });
    keyValuesMenu('kv', [urlKv]);
  });
}
