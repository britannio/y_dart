part of 'all.dart';

final class YArrayIterator implements Iterator<YOutput> {
// This doesn't make use of the ffi iterator methods but the performance might
// be similar anyway
  YArrayIterator(this._array);
  final YArray _array;
  int _index = 0;

  @override
  YOutput get current => _array[_index];

  @override
  bool moveNext() {
    _index++;
    return _index < _array.length;
  }
}

final class YArray extends YType {
  YArray._(this._doc, ffi.Pointer<gen.Branch> branch) : super._(branch);
  final YDoc _doc;

  int get length => _bindings.yarray_len(_branch);

  List<YOutput> operator +(List<YOutput> other) {
    // TODO: implement +
    throw UnimplementedError();
  }

  YOutput operator [](int index) {
    late YOutput result;
    _doc._transaction((txn) {
      final outputPtr = _bindings.yarray_get(_branch, txn, index);
      if (outputPtr == ffi.nullptr) {
        throw IndexError.withLength(index, length);
      }
      result = YOutput.fromFfi(outputPtr.ref);
      _bindings.youtput_destroy(outputPtr);
    });
    return result;
  }

  void operator []=(int index, YInput value) {
    _doc._transaction((txn) {
      final input = value._input;
      final inputPtr = malloc<gen.YInput>();
      inputPtr.ref = input;
      _bindings.yarray_insert_range(_branch, txn, index, inputPtr, 1);
    });
  }

  void add(YInput value) => insert(length, value);

  void addAll(Iterable<YInput> iterable) => insertAll(length, iterable);

  bool any(bool Function(YOutput element) test) {
    for (var i = 0; i < length; i++) {
      if (test(this[i])) return true;
    }
    return false;
  }

  Map<int, YOutput> asMap() {
    final result = <int, YOutput>{};
    for (var i = 0; i < length; i++) {
      result[i] = this[i];
    }
    return result;
  }

  void clear() => removeRange(0, length);

  YOutput elementAt(int index) => this[index];

  void insert(int index, YInput element) {
    // TODO: implement insert
  }

  void insertAll(int index, Iterable<YInput> iterable) {
    _doc._transaction((txn) {
      final inputs = iterable.map((e) => e._input).toList();
      final inputsPtr = malloc<gen.YInput>(inputs.length);
      for (var i = 0; i < inputs.length; i++) {
        inputsPtr[i] = inputs[i];
      }
      _bindings.yarray_insert_range(
          _branch, txn, index, inputsPtr, inputs.length);
    });
  }

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  Iterator<YOutput> get iterator => YArrayIterator(this);

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

  List<YOutput> toList() {
    final result = <YOutput>[];
    final iter = iterator;
    while (iter.moveNext()) {
      result.add(iter.current);
    }
    return result;
  }

  // @override
  // Set<YOutput> toSet() {
  //   // TODO: implement toSet
  //   throw UnimplementedError();
  // }

  Iterable<YOutput> where(bool Function(YOutput element) test) sync* {
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
