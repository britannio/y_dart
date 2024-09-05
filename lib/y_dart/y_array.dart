part of 'all.dart';

final class YArrayIterator<T> implements Iterator<T> {
// This doesn't make use of the ffi iterator methods but the performance might
// be similar anyway
  YArrayIterator(this._array);
  final YArray _array;
  int _index = 0;

  @override
  T get current => _array[_index];

  @override
  bool moveNext() {
    _index++;
    return _index < _array.length;
  }
}

final class YArray<T> extends YType {
  YArray._(this._doc, ffi.Pointer<gen.Branch> branch) : super._(branch);
  final YDoc _doc;

  int get length => _bindings.yarray_len(_branch);

  // List<T> operator +(List<T> other) {
  //   // TODO: implement +
  //   throw UnimplementedError();
  // }

  T operator [](int index) {
    late T result;
    _doc._transaction((txn) {
      final outputPtr = _bindings.yarray_get(_branch, txn, index);
      if (outputPtr == ffi.nullptr) {
        throw IndexError.withLength(index, length);
      }
      result = _YOutput.toObject(outputPtr, _doc);
    });
    return result;
  }

  void operator []=(int index, T value) {
    _doc._transaction((txn) {
      /// This is forced to stay alive because it implements [ffi.Finalizable]
      final yInput = _YInput._(value);
      final input = yInput._input;
      final inputPtr = malloc<gen.YInput>();
      inputPtr.ref = input;
      _bindings.yarray_insert_range(_branch, txn, index, inputPtr, 1);
      malloc.free(inputPtr);
    });
  }

  void add(T value) => insert(length, value);

  // void addAll(Iterable<T> iterable) => insertAll(length, iterable);

  bool any(bool Function(T element) test) {
    for (var i = 0; i < length; i++) {
      if (test(this[i])) return true;
    }
    return false;
  }

  Map<int, T> asMap() {
    final result = <int, T>{};
    for (var i = 0; i < length; i++) {
      result[i] = this[i];
    }
    return result;
  }

  void clear() => removeRange(0, length);

  T elementAt(int index) => this[index];

  void insert(int index, T element) {
    // TODO: implement insert
  }

  // void insertAll(int index, Iterable<T> iterable) {
  //   _doc._transaction((txn) {
  //     final inputs = iterable.map((e) => _YInput._(e)).toList();
  //     final inputsPtr = malloc<gen.YInput>(inputs.length);
  //     for (var i = 0; i < inputs.length; i++) {
  //       inputsPtr[i] = inputs[i]._input;
  //     }
  //     // I think a GC could occur in this gap
  //     _bindings.yarray_insert_range(
  //       _branch,
  //       txn,
  //       index,
  //       inputsPtr,
  //       inputs.length,
  //     );
  //     malloc.free(inputsPtr);
  //   });
  // }

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  Iterator<T> get iterator => YArrayIterator<T>(this);

  void removeAt(int index) {
    _doc._transaction(
        (txn) => _bindings.yarray_remove_range(_branch, txn, index, index + 1));
  }

  void removeLast() => removeAt(length - 1);

  void removeRange(int start, int end) {
    _doc._transaction(
        (txn) => _bindings.yarray_remove_range(_branch, txn, start, end));
  }

  void move(int source, int target) {
    _doc._transaction((txn) {
      _bindings.yarray_move(_branch, txn, source, target);
    });
  }

  List<T> toList() {
    final result = <T>[];
    final iter = iterator;
    while (iter.moveNext()) {
      result.add(iter.current);
    }
    return result;
  }

  // @override
  // Set<T> toSet() {
  //   // TODO: implement toSet
  //   throw UnimplementedError();
  // }

  Iterable<T> where(bool Function(T element) test) sync* {
    final iter = iterator;
    while (iter.moveNext()) {
      if (test(iter.current)) yield iter.current;
    }
  }

  Iterable<T> whereType<T>() sync* {
    final iter = iterator;
    while (iter.moveNext()) {
      if (iter.current is T) yield iter.current as T;
    }
  }
}
