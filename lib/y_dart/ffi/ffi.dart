// ignore_for_file: non_constant_identifier_names

part of '../all.dart';

/// A native function with a single pointer argument.
typedef NativeFreeFn = ffi.NativeFinalizerFunction;

typedef FreeFn = ffi.Pointer<ffi.NativeFinalizerFunction>;

typedef NativeFfi = ffi.Void Function(ffi.Pointer<ffi.Void>);

@ffi.Native<NativeFfi>()
external void yundo_manager_destroy(ffi.Pointer<ffi.Void> mgr);

@ffi.Native<NativeFfi>()
external void ydoc_destroy(ffi.Pointer<ffi.Void> value);

@ffi.Native<NativeFfi>()
external void ybinary_destroy_from_struct(ffi.Pointer<ffi.Void> input);

@ffi.Native<NativeFfi>()
external void ymap_iter_destroy(ffi.Pointer<ffi.Void> iter);

@ffi.Native<NativeFfi>()
external void yarray_iter_destroy(ffi.Pointer<ffi.Void> iter);

@ffi.Native<NativeFfi>()
external void ymap_entry_destroy(ffi.Pointer<ffi.Void> value);

@ffi.Native<NativeFfi>()
external void youtput_destroy(ffi.Pointer<ffi.Void> val);

abstract final class YFree {
  static final mallocFinalizer = ffi.NativeFinalizer(malloc.nativeFree);

  static final undoManagerFinalizer =
      ffi.NativeFinalizer(ffi.Native.addressOf(yundo_manager_destroy));

  static final yDocFinalizer =
      ffi.NativeFinalizer(ffi.Native.addressOf(ydoc_destroy));

  static final binary =
      ffi.Native.addressOf<NativeFreeFn>(ybinary_destroy_from_struct);
  static final binaryFinalizer =
      ffi.NativeFinalizer(ffi.Native.addressOf(ybinary_destroy_from_struct));

  static final mapIterFinalizer =
      ffi.NativeFinalizer(ffi.Native.addressOf(ymap_iter_destroy));

  static final arrayIterFinalizer =
      ffi.NativeFinalizer(ffi.Native.addressOf(yarray_iter_destroy));

  static final mapEntryFinalizer =
      ffi.NativeFinalizer(ffi.Native.addressOf(ymap_entry_destroy));

  static final outputFinalizer =
      ffi.NativeFinalizer(ffi.Native.addressOf(youtput_destroy));
}

extension PointerCharX on ffi.Pointer<ffi.Char> {
  Uint8List asTypedListFinalized(int length) {
    final finalizerToken = gen.ybinary_destroy_struct();
    finalizerToken.ref.binary_ptr = this;
    finalizerToken.ref.binary_len = length;
    return cast<ffi.Uint8>().asTypedList(
      length,
      finalizer: YFree.binary,
      token: finalizerToken.cast<ffi.Void>(),
    );
  }
}
