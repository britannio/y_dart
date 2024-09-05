part of 'all.dart';

abstract class YType implements ffi.Finalizable {
  // Freed by the owning YDoc or other creator.
  final ffi.Pointer<gen.Branch> _branch;
  YType._(this._branch);
}
