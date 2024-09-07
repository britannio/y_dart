part of 'all.dart';

abstract class YOrigin {
  Uint8List toBytes();
  YOrigin._();

  factory YOrigin.fromString(String string) => _YOriginString(string);
  factory YOrigin.fromBytes(Uint8List bytes) => _YOriginBytes(bytes);
}

class _YOriginBytes extends YOrigin {
  final Uint8List bytes;

  _YOriginBytes(this.bytes) : super._();

  @override
  Uint8List toBytes() => bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _YOriginBytes && listEquals(bytes, other.bytes);

  @override
  int get hashCode => bytes.hashCode;
}

class _YOriginString extends YOrigin {
  final String string;

  _YOriginString(this.string) : super._();

  @override
  Uint8List toBytes() => Uint8List.fromList(string.codeUnits);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _YOriginString && string == other.string;

  @override
  int get hashCode => string.hashCode;
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
