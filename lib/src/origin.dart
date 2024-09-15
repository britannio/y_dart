part of 'y_dart.dart';

sealed class YOrigin {
  YOrigin._(this.bytes);
  final Uint8List bytes;

  factory YOrigin.fromString(String string) => _YOriginString(string);
  factory YOrigin.fromBytes(Uint8List bytes) => _YOriginBytes(bytes);

  static YOrigin? fromFfi(ffi.Pointer<ffi.Char> ptr, int length) {
    if (ptr == ffi.nullptr || length <= 0) return null;
    // We make a copy as the origin is valid for the duration of the transaction
    // where it was supplied. Observers callbacks on YDoc other Y types are
    // called after the transaction is complete when the origin is no longer
    // valid.
    final bytes = Uint8List.fromList(ptr.cast<ffi.Uint8>().asTypedList(length));
    return YOrigin.fromBytes(bytes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YOrigin && listEquals(bytes, other.bytes);

  @override
  int get hashCode => bytes.hashCode;
}

class _YOriginBytes extends YOrigin {
  _YOriginBytes(super.bytes) : super._();
}

class _YOriginString extends YOrigin {
  _YOriginString(this.string) : super._(utf8.encode(string));
  final String string;
}

// Copied from flutter collections.dart
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}
