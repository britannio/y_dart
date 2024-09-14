part of 'y_dart.dart';

sealed class YOrigin {
  YOrigin._(this.bytes);
  final Uint8List bytes;

  factory YOrigin.fromString(String string) => _YOriginString(string);
  factory YOrigin.fromBytes(Uint8List bytes) => _YOriginBytes(bytes);

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
