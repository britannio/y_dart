part of 'y_dart.dart';

final class YXmlFragment extends YType {
  YXmlFragment._(this._doc, ffi.Pointer<gen.Branch> branch) : super._(branch);

  final YDoc _doc;
}

interface class YXmlType {}

final class YXmlElement extends YType implements YXmlType {
  YXmlElement._(this._doc, ffi.Pointer<gen.Branch> branch) : super._(branch);

  final YDoc _doc;

  String get tag {
    final tagPtr = _bindings.yxmlelem_tag(_branch);
    final result = tagPtr.cast<Utf8>().toDartString();
    _bindings.ystring_destroy(tagPtr);
    return result;
  }
}

final class YXmlText extends YType implements YXmlType {
  YXmlText._(this._doc, ffi.Pointer<gen.Branch> branch) : super._(branch);

  final YDoc _doc;

  YXmlType? nextSibling() {
    return null;
  }

  YXmlType? prevSibling() {
    return null;
  }

  @override
  String toString() {
    final ptr = _doc._transaction(
      (txn) => _bindings.yxmltext_string(_branch, txn),
    );
    final result = ptr.cast<Utf8>().toDartString();
    _bindings.ystring_destroy(ptr);
    return result;
  }
}
