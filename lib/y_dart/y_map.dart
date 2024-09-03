part of 'all.dart';

final class YMap {
  YMap._(this._doc, this._branch);

  final YDoc _doc;
  final ffi.Pointer<gen.Branch> _branch;

  YOutput? operator [](String key) {
    late final YOutput? value;
    _doc._transaction((txn) {
      final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
      final outputPtr = _bindings.ymap_get(_branch, txn, keyPtr);
      malloc.free(keyPtr);
      value = outputPtr == ffi.nullptr ? null : YOutput.fromFfi(outputPtr.ref);
      // safe for null pointers
      _bindings.youtput_destroy(outputPtr);
    });
    return value;
  }

  void operator []=(String key, YInput value) {
    _doc._transaction((txn) {
      final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
      final inputPtr = malloc<gen.YInput>();
      inputPtr.ref = value._input;
      _bindings.ymap_insert(_branch, txn, keyPtr, inputPtr);
      malloc.free(keyPtr);
      malloc.free(inputPtr);
    });
  }

  void addAll(Map<String, YValue> other) => addEntries(other.entries);

  void addEntries(Iterable<MapEntry<String, YValue>> newEntries) {
    newEntries
        .where((e) => e.value is YInput)
        .forEach((e) => this[e.key] = e.value as YInput);
  }

  void clear() =>
      _doc._transaction((txn) => _bindings.ymap_remove_all(_branch, txn));

  // @override
  // bool containsKey(Object? key) {
  //   if (key is! String) return false;
  //   final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
  //   late bool result;
  //   _doc._transaction((txn) {
  //     final outputPtr = _bindings.ymap_get(_branch, txn, keyPtr);
  //     result = outputPtr != ffi.nullptr;
  //     _bindings.youtput_destroy(outputPtr);
  //   });
  //   malloc.free(keyPtr);
  //   return result;
  // }

  Iterable<MapEntry<String, YOutput>> get entries sync* {
    // Note that it's more efficient to create an Iterator: https://github.com/dart-lang/sdk/issues/51806
    late ffi.Pointer<gen.YMapIter> iter;
    _doc._transaction((txn) => iter = _bindings.ymap_iter(_branch, txn));
    late ffi.Pointer<gen.YMapEntry> outputPtr;
    while ((outputPtr = _bindings.ymap_iter_next(iter)) != ffi.nullptr) {
      final entry = outputPtr.ref;
      final key = entry.key.cast<Utf8>().toDartString();
      final value = YOutput.fromFfi(entry.value.ref);
      yield MapEntry(key, value);
    }
    // Will this always run once we're done or only after iterating all elements?
    _bindings.ymap_iter_destroy(iter);
  }

  void forEach(void Function(String key, YOutput value) action) {
    for (final entry in entries) {
      action(entry.key, entry.value);
    }
  }

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  Iterable<String> get keys sync* {
    for (final entry in entries) {
      yield entry.key;
    }
  }

  Iterable<YOutput> get values sync* {
    for (final entry in entries) {
      yield entry.value;
    }
  }

  int get length {
    late int len;
    _doc._transaction((txn) => len = _bindings.ymap_len(_branch, txn));
    return len;
  }

  YOutput? remove(Object? key) {
    if (key is! String) return null;
    final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
    late YOutput? value;
    _doc._transaction((txn) {
      value = this[key];
      _bindings.ymap_remove(_branch, txn, keyPtr);
    });
    malloc.free(keyPtr);
    return value;
  }
}
