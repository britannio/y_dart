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

/// A native function with a single pointer argument.
typedef NativeFreeFn
    = ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>;

typedef FreeFn = ffi.Pointer<NativeFreeFn>;

abstract final class YFree {
  static final FreeFn undoManager =
      _dylib.lookup<NativeFreeFn>('yundo_manager_destroy');
  static final FreeFn yDoc = _dylib.lookup<NativeFreeFn>('ydoc_destroy');
  static final FreeFn binary =
      _dylib.lookup<NativeFreeFn>('ybinary_destroy_struct');
}

extension PointerCharX on ffi.Pointer<ffi.Char> {
  Uint8List asTypedListFinalized(int length) {
    final finalizerToken = _bindings.ybinary_destroy_struct();
    finalizerToken.ref.binary_ptr = this;
    finalizerToken.ref.binary_len = length;
    return cast<ffi.Uint8>().asTypedList(
      length,
      finalizer: YFree.binary,
      token: finalizerToken.cast<ffi.Void>(),
    );
  }
}
