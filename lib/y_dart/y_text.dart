part of 'all.dart';

typedef NativeTextObserveCallback = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<gen.YTextEvent>);

final class YText extends YType with _YObservable {
  YText._(super._branch, this._doc) : super._();
  final YDoc _doc;

  void append(String text) => insert(index: length, text: text);

  void insert({required int index, required String text}) {
    // TODO support text attributes
    _doc._transaction((txn) {
      final textPtr = text.toNativeUtf8().cast<ffi.Char>();
      _bindings.ytext_insert(_branch, txn, index, textPtr, ffi.nullptr);
      malloc.free(textPtr);
    });
  }

  int get length {
    late int len;
    // Technically only need a read transaction here.
    _doc._transaction((txn) {
      len = _bindings.ytext_len(_branch, txn);
    });
    return len;
  }

  void removeRange({required int start, required int length}) {
    _doc._transaction((txn) {
      _bindings.ytext_remove_range(_branch, txn, start, length);
    });
  }

  static YTextChange _convertDeltaOut(ffi.Pointer<gen.YDeltaOut> delta) {
    // TODO implement this
    final ref = delta.ref;
    switch (ref.tag) {
      case gen.Y_EVENT_CHANGE_ADD:
      // return YTextInserted(ref.insert.toDartString(), ref.attributes);
      case gen.Y_EVENT_CHANGE_DELETE:
      // return YTextDeleted(ref.len);
      case gen.Y_EVENT_CHANGE_RETAIN:
      // return YTextRetained(ref.len, ref.attributes);
      default:
        throw Exception('Unknown YDeltaOutTag: $ref.tag');
    }
  }

  static void _observeCallback(
    ffi.Pointer<ffi.Void> idPtr,
    ffi.Pointer<gen.YTextEvent> event,
  ) {
    if (!_YObservable._shouldEmit(idPtr)) return;

    final deltaLenPtr = malloc<ffi.Uint32>();
    final delta = _bindings.ytext_event_delta(event, deltaLenPtr);
    final deltaLen = deltaLenPtr.value;
    malloc.free(deltaLenPtr);
    final textChange = _convertDeltaOut(delta);
    _bindings.ytext_delta_destroy(delta, deltaLen);

    final streamController = _YObservable._controller<YTextChange>(idPtr);
    streamController.add(textChange);
  }

  StreamSubscription<YTextChange> listen(void Function(YTextChange) callback) {
    final callbackPtr =
        ffi.Pointer.fromFunction<NativeTextObserveCallback>(_observeCallback);

    return _listen<YTextChange>(
      callback,
      (state) => _bindings.ytext_observe(_branch, state, callbackPtr),
    );
  }

  // Does this make sense for fomatted text?
  // String operator [](int index);

  @override
  String toString() {
    final ptr = _doc._transaction(
      (txn) => _bindings.ytext_string(_branch, txn),
    );
    final result = ptr.cast<Utf8>().toDartString();
    _bindings.ystring_destroy(ptr);
    return result;
  }
}
