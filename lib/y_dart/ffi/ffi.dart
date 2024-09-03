// import 'dart:ffi' as ffi;
// import 'dart:io';
// import 'package:y_dart/y_dart/ffi/y_dart_bindings_generated.dart' as gen;

part of '../all.dart';

const String _libName = 'y_dart';

/// The dynamic library in which the symbols for [YDartBindings] can be found.
final ffi.DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return ffi.DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final gen.YDartBindings _bindings = gen.YDartBindings(_dylib);
