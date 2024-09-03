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
}

class _YOriginString extends YOrigin {
  final String string;

  _YOriginString(this.string) : super._();

  @override
  Uint8List toBytes() => Uint8List.fromList(string.codeUnits);
}
