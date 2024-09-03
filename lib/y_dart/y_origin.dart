part of 'all.dart';

abstract class YOrigin {
  Uint8List toBytes();
}

class YOriginBytes extends YOrigin {
  final Uint8List bytes;

  YOriginBytes(this.bytes);

  @override
  Uint8List toBytes() => bytes;
}

class YOriginString extends YOrigin {
  final String string;

  YOriginString(this.string);

  @override
  Uint8List toBytes() => Uint8List.fromList(string.codeUnits);
}
