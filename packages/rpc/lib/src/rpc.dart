//import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// An command object representing the invocation of a named method.
@immutable
class MethodCall
//
//    implements
//        MethodCall
//
{
  /// Creates a [MethodCall] representing the invocation of [method] with the
  /// specified [arguments].
  const MethodCall(this.method, [this.arguments]);

  /// The name of the method to be called.
  final String method;

  /// The arguments for the method.
  ///
  /// Must be a valid value for the [MethodCodec] used.
  final Object? arguments;

  @override
  String toString() =>
      '$runtimeType($method${arguments == null ? '' : ', $arguments'})';
}

@immutable
abstract class RpcException implements Exception {
  /// Exception code
  String get code;

  /// Exception message
  String get message;

  /// The arguments for the exceptions.
  Object? get arguments;
}
