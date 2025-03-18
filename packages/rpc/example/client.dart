// ignore_for_file: avoid_print

import 'dart:async';

import 'package:tekartik_rpc/rpc_client.dart';

import 'server.dart';

Future<void> main() async {
  var rpcClient = await RpcClient.connect(Uri.parse('ws://localhost:8060'));
  print('connected');
  print(await rpcClient.sendServiceRequest(simpleRcpServiceName, 'ping', null));
  await rpcClient.close();
}
