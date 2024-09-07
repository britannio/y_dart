part of 'all.dart';

typedef NativeArrayObserveCallback = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<gen.YArrayEvent>);

final class YArray<T> extends YType with _YObservable {
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
      /// yInput is forced to stay alive because it implements [ffi.Finalizable]
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
    _doc._transaction((txn) {
      final input = _YInput._(element);
      final inputPtr = malloc<gen.YInput>();
      inputPtr.ref = input._input;
      _bindings.yarray_insert_range(_branch, txn, index, inputPtr, 1);
      malloc.free(inputPtr);
    });
  }

  void insertAll(int index, Iterable<T> iterable) {
    _doc._transaction((txn) {
      final inputs = iterable.map((e) => _YInput._(e)).toList();
      final inputsPtr = malloc<gen.YInput>(inputs.length);
      for (var i = 0; i < inputs.length; i++) {
        inputsPtr[i] = inputs[i]._input;
      }
      _bindings.yarray_insert_range(
        _branch,
        txn,
        index,
        inputsPtr,
        inputs.length,
      );
      // Here to prevent the GC from deeming the wrapping input objects to be
      // dead & thus destroying their native resources before we perform the
      // native operation
      for (final input in inputs) {
        input.dispose();
      }
      malloc.free(inputsPtr);
    });
  }

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

  static void _observeCallback(
    ffi.Pointer<ffi.Void> idPtr,
    ffi.Pointer<gen.YArrayEvent> event,
  ) {
    if (!_YObservable._shouldEmit(idPtr)) return;

    final deltaLenPtr = malloc<ffi.Uint32>();
    final delta = _bindings.yarray_event_delta(event, deltaLenPtr);
    final deltaLen = deltaLenPtr.value;
    malloc.free(deltaLenPtr);

    final changes =
        List.generate(deltaLen, (i) => YArrayChange.fromEvent(delta[i]));

    _bindings.yevent_delta_destroy(delta, deltaLen);

    final streamController =
        _YObservable._controller<List<YArrayChange>>(idPtr);
    streamController.add(changes);
  }

  StreamSubscription<List<YArrayChange>> listen(
    void Function(List<YArrayChange>) callback,
  ) {
    final callbackPtr =
        ffi.Pointer.fromFunction<NativeArrayObserveCallback>(_observeCallback);

    return _listen<List<YArrayChange>>(
      callback,
      (state) => _bindings.yarray_observe(_branch, state, callbackPtr),
    );
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

  Iterable<V> whereType<V>() sync* {
    final iter = iterator;
    while (iter.moveNext()) {
      if (iter.current is V) yield iter.current as V;
    }
  }

  @override
  String toString() {
    return toList().toString();
  }
}

final class YArrayIterator<T> implements Iterator<T> {
  YArrayIterator(this._array);
  final YArray _array;
  int _index = -1;

  @override
  T get current => _array[_index];

  @override
  bool moveNext() {
    _index++;
    return _index < _array.length;
  }
}

sealed class YArrayChange {
  static YArrayChange fromEvent(gen.YEventChange event) {
    switch (event.tag) {
      case gen.Y_EVENT_CHANGE_ADD:
        final values = List.generate(
          event.len,
          (i) => _YOutput.toObjectInner(event.values[i]),
        );
        return YArrayInserted(event.len, values);
      case gen.Y_EVENT_CHANGE_DELETE:
        return YArrayDeleted(event.len);
      case gen.Y_EVENT_CHANGE_RETAIN:
        return YArrayRetained(event.len);
      default:
        throw Exception('Unknown event change tag: ${event.tag}');
    }
  }

  static List<YArrayChange> fromEvents(List<gen.YEventChange> events) {
    return events.map(fromEvent).toList();
  }
}

class YArrayDeleted extends YArrayChange {
  final int length;

  YArrayDeleted(this.length);

  @override
  String toString() => '{ delete: $length }';
}

class YArrayInserted extends YArrayChange {
  final int length;
  final List<Object?> values;

  YArrayInserted(this.length, this.values);

  @override
  String toString() => '{ insert: $length, values: $values }';
}

class YArrayRetained extends YArrayChange {
  final int length;

  YArrayRetained(this.length);

  @override
  String toString() => '{ retain: $length }';
}
