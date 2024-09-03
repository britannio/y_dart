part of 'all.dart';

final class YXml {
  YXml._(this._doc, this._branch);

  final YDoc _doc;
  final ffi.Pointer<gen.Branch> _branch;
}
