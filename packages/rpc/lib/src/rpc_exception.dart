import 'package:meta/meta.dart';

/// We user error 1 for services
const jsonRpcExceptionIntCodeService = 1;

/// Exception code for jsonRpc
const rpcExceptionCodeUnsupported = 'rpc_exception_unsupported';
const rpcExceptionCodeJsonRpc = 'rpc_exception_json';

@immutable
abstract class RpcException implements Exception {
  /// Exception code
  String get code;

  /// Exception message
  String get message;

  /// The arguments for the exceptions.
  Object? get arguments;

  /// New exception
  factory RpcException(String code, [String? message, Object? arguments]) {
    return _RpcException(code, message ?? 'RpcException', arguments);
  }
}

class _RpcException implements RpcException {
  @override
  final String code;

  @override
  final String message;

  @override
  final Object? arguments;

  _RpcException(this.code, this.message, this.arguments);

  @override
  String toString() =>
      'RpcException($code, $message${arguments == null ? '' : ', $arguments'}';
}
