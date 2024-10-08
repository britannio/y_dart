part of 'y_dart.dart';

typedef NativeTextObserveCallback = ffi.Void Function(ffi.Pointer<ffi.Void>,
    ffi.Pointer<gen.YTextEvent>, ffi.Uint32, ffi.Pointer<ffi.Char>);

final class YText extends YType with _YObservable<YTextChanges> {
  YText._(super._branch, this.doc) : super._();
  final YDoc doc;

  void append(
    String text, {
    Map<String, Object> attributes = const {},
  }) =>
      insert(
        index: length,
        text: text,
        attributes: attributes,
      );

  void insert({
    required int index,
    required String text,
    Map<String, Object> attributes = const {},
  }) {
    doc._transaction((txn) {
      final textPtr = text.toNativeUtf8().cast<ffi.Char>();
      final attrs = YInputJsonMap(attributes);
      final attrsPtr = malloc<gen.YInput>();
      attrsPtr.ref = attrs._input;
      _bindings.ytext_insert(_branch, txn, index, textPtr, attrsPtr);
      malloc.free(attrsPtr);
      malloc.free(textPtr);
      attrs.dispose();
    });
  }

  int get length {
    // Technically only need a read transaction here.
    return doc._transaction((txn) => _bindings.ytext_len(_branch, txn));
  }

  void removeRange({required int start, required int length}) {
    doc._transaction((txn) {
      _bindings.ytext_remove_range(_branch, txn, start, length);
    });
  }

  void format(
    int index,
    int length, {
    required Map<String, Object> attributes,
  }) {
    final input = YInputJsonMap(attributes);
    final attrsPtr = malloc<gen.YInput>()..ref = input._input;
    doc._transaction((txn) {
      _bindings.ytext_format(_branch, txn, index, length, attrsPtr);
    });
    input.dispose();
    malloc.free(attrsPtr);
  }

  static YTextChange _convertDeltaOut(gen.YDeltaOut delta) {
    final len = delta.len;

    final Map<String, Object> attributes = {};
    if (delta.attributes != ffi.nullptr && delta.attributes_len > 0) {
      for (int i = 0; i < delta.attributes_len; i++) {
        final attr = delta.attributes[i];
        final key = attr.key.cast<Utf8>().toDartString();
        final value = _YOutput.toObjectInner(attr.value);
        if (value == null) continue;
        attributes[key] = value;
      }
    }

    switch (delta.tag) {
      case gen.Y_EVENT_CHANGE_ADD:
        final str = StringBuffer();
        for (int i = 0; i < len; i++) {
          final yOut = delta.insert[i];
          assert(yOut.tag == gen.Y_JSON_STR);
          str.write(yOut.value.str.cast<Utf8>().toDartString());
        }
        return YTextInserted(str.toString(), attributes);
      case gen.Y_EVENT_CHANGE_DELETE:
        return YTextDeleted(delta.len);
      case gen.Y_EVENT_CHANGE_RETAIN:
        return YTextRetained(delta.len, attributes);
      default:
        throw Exception('Unknown YDeltaOutTag: $delta.tag');
    }
  }

  static void _observeCallback(
    ffi.Pointer<ffi.Void> idPtr,
    ffi.Pointer<gen.YTextEvent> event,
    int originLen,
    ffi.Pointer<ffi.Char> origin,
  ) {
    if (!_YObservable._shouldEmit(idPtr)) return;

    final deltaLenPtr = malloc<ffi.Uint32>();
    final delta = _bindings.ytext_event_delta(event, deltaLenPtr);
    final deltaLen = deltaLenPtr.value;
    malloc.free(deltaLenPtr);

    final changes = List.generate(deltaLen, (i) => _convertDeltaOut(delta[i]));
    final yOrigin = YOrigin._fromFfi(origin, originLen);
    final changesWithOrigin = YTextChanges(changes: changes, origin: yOrigin);

    _bindings.ytext_delta_destroy(delta, deltaLen);

    final streamController = _YObservable._controller<YTextChanges>(idPtr);
    streamController.add(changesWithOrigin);
  }

  StreamSubscription<YTextChanges> listen(
    void Function(YTextChanges) callback,
  ) {
    final callbackPtr =
        ffi.Pointer.fromFunction<NativeTextObserveCallback>(_observeCallback);

    return _listen(
      callback,
      (state) => _bindings.ytext_observe(_branch, state, callbackPtr),
    );
  }

  // Does this make sense for fomatted text?
  // String operator [](int index);

  @override
  String toString() {
    final ptr = doc._transaction(
      (txn) => _bindings.ytext_string(_branch, txn),
    );
    final result = ptr.cast<Utf8>().toDartString();
    _bindings.ystring_destroy(ptr);
    return result;
  }

  List<YTextInserted> toDelta() {
    return doc._transaction((txn) {
      final chunksLenPtr = malloc<ffi.Uint32>();
      final chunksPtr = _bindings.ytext_chunks(_branch, txn, chunksLenPtr);
      final chunksLen = chunksLenPtr.value;
      malloc.free(chunksLenPtr);

      final deltas = <YTextInserted>[];
      for (int i = 0; i < chunksLen; i++) {
        final chunk = chunksPtr[i];
        // Assuming that the chunk content is a string but this may not be true??
        final content = _YOutput.toObjectInner(chunk.data);
        final attrs = <String, Object>{};
        for (int j = 0; j < chunk.fmt_len; j++) {
          final attr = chunk.fmt[j];
          final key = attr.key.cast<Utf8>().toDartString();
          final value = _YOutput.toObjectInner(attr.value.ref);
          if (value == null) continue;
          attrs[key] = value;
        }
        deltas.add(YTextInserted(content as String, attrs));
      }
      _bindings.ychunks_destroy(chunksPtr, chunksLen);
      return deltas;
    });
  }
}
