part of 'all.dart';

final class YMap<T extends Object?> extends YType {
  YMap._(this._doc, ffi.Pointer<gen.Branch> branch) : super._(branch);

  final YDoc _doc;

  T? operator [](String key) {
    return _doc._transaction((txn) {
      final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
      final outputPtr = _bindings.ymap_get(_branch, txn, keyPtr);
      malloc.free(keyPtr);
      if (outputPtr == ffi.nullptr) return null;
      return _YOutput.toObject<T?>(outputPtr, _doc);
    });
  }

  void operator []=(String key, T? value) {
    _doc._transaction((txn) {
      final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
      final inputPtr = malloc<gen.YInput>();
      // yInput needs to be a variable with type ffi.Finalizable to delay it's
      // destruction until the end of this block scope.
      final yInput = _YInput._(value);
      inputPtr.ref = yInput._input;
      _bindings.ymap_insert(_branch, txn, keyPtr, inputPtr);
      malloc.free(keyPtr);
      malloc.free(inputPtr);
    });
  }

  void addAll(Map<String, T> other) => addEntries(other.entries);

  void addEntries(Iterable<MapEntry<String, T>> newEntries) {
    for (final entry in newEntries) {
      this[entry.key] = entry.value;
    }
  }

  void clear() =>
      _doc._transaction((txn) => _bindings.ymap_remove_all(_branch, txn));

  // Iterator<MapEntry<String, T?>> get iterator => _YMapIterator<T?>(this, _doc);

  Iterable<MapEntry<String, T?>> get entries {
    // We aren't using yield and sync* as we need to guarantee that the
    // transaction will be commited.
    final result = <MapEntry<String, T?>>[];
    _doc._transaction((txn) {
      final iterator = _YMapIterator<T?>(this, _doc);
      while (iterator.moveNext()) {
        result.add(iterator.current);
      }
    });
    return result;
  }

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  Iterable<String> get keys sync* {
    for (final entry in entries) {
      yield entry.key;
    }
  }

  Iterable<T?> get values sync* {
    for (final entry in entries) {
      yield entry.value;
    }
  }

  int get length =>
      _doc._transaction((txn) => _bindings.ymap_len(_branch, txn));

  void remove(String key) {
    final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
    _doc._transaction((txn) => _bindings.ymap_remove(_branch, txn, keyPtr));
    malloc.free(keyPtr);
  }

  // bool containsKey(String key) => this[key] != null;
}

typedef YMapEntry<T> = MapEntry<String, T>;

final class _YMapIterator<T extends Object?>
    implements Iterator<YMapEntry<T?>>, ffi.Finalizable {
  _YMapIterator(this._map, this._doc) {
    final txn = YTransaction._fromZoneNullable()?._txn;
    if (txn == null) {
      // We must use a transaction that outlives this iterator as iter_next
      // is only valid using the same transaction provided to ymap_iter.
      throw Exception('No transaction found');
    }
    _iter = _bindings.ymap_iter(_map._branch, txn);
    // This is safe even if we create new YTypes as freeing the iterator does
    // not drop the rest of the data.
    YFree.mapIterFinalizer.attach(this, _iter.cast<ffi.Void>());
  }
  final YMap<T> _map;
  final YDoc _doc;
  late final ffi.Pointer<gen.YMapIter> _iter;
  YMapEntry<T?>? _current;

  @override
  YMapEntry<T?> get current {
    if (_current == null) {
      throw StateError('Iterator has not been moved to the first element');
    }
    return _current!;
  }

  @override
  bool moveNext() {
    final mapEntryPtr = _bindings.ymap_iter_next(_iter);
    if (mapEntryPtr == ffi.nullptr) return false;
    final key = mapEntryPtr.ref.key.cast<Utf8>().toDartString();
    final value = _YOutput.toObject<T?>(
      mapEntryPtr.ref.value,
      _doc,
      yMapEntryPtr: mapEntryPtr,
    );
    _current = MapEntry(key, value);
    return true;
  }
}
