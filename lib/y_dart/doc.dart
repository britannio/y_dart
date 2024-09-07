part of 'all.dart';

typedef NativeDocObserveCallback = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Pointer<ffi.Char>);

class YDoc with _YObservable<Uint8List> implements ffi.Finalizable {
  YDoc._(this._doc);

  factory YDoc({
    int? id,
    String? guid,
    String? collectionId,
    bool? skipGc,
    bool? autoLoad,
    bool? shouldLoad,
  }) {
    final options = _bindings.yoptions();

    options.id = id ?? options.id;

    final guidPtr = guid?.toNativeUtf8().cast<ffi.Char>();
    options.guid = guidPtr ?? options.guid;

    final collectionIdPtr = collectionId?.toNativeUtf8().cast<ffi.Char>();
    options.collection_id = collectionIdPtr ?? options.collection_id;

    options.skip_gc = skipGc == null ? options.skip_gc : (skipGc ? 1 : 0);
    options.auto_load =
        autoLoad == null ? options.auto_load : (autoLoad ? 1 : 0);
    options.should_load =
        shouldLoad == null ? options.should_load : (shouldLoad ? 1 : 0);

    final doc = _bindings.ydoc_new_with_options(options);
    if (guidPtr != null) malloc.free(guidPtr);
    if (collectionIdPtr != null) malloc.free(collectionIdPtr);
    final yDoc = YDoc._(doc);
    YFree.yDocFinalizer.attach(yDoc, doc.cast<ffi.Void>());
    return yDoc;
  }

  factory YDoc.clone(YDoc doc) {
    final clonedDocPtr = _bindings.ydoc_clone(doc._doc);
    return YDoc._(clonedDocPtr);
  }

  final ffi.Pointer<gen.YDoc> _doc;

  /// A unique client identifier for the document.
  late final int id = _bindings.ydoc_id(_doc);

  /// A unique identifier for the document.
  late final String guid = () {
    final ptr = _bindings.ydoc_guid(_doc);
    final String result = ptr.cast<Utf8>().toDartString();
    _bindings.ystring_destroy(ptr);
    return result;
  }();

  late final ffi.Pointer<ffi.Char> _collectionId =
      _bindings.ydoc_collection_id(_doc);

  late final String? collectionId = _collectionId == ffi.nullptr
      ? null
      : _collectionId.cast<Utf8>().toDartString();

  YText getText(String name) {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final branchPtr = _bindings.ytext(_doc, namePtr);
    malloc.free(namePtr);
    return YText._(branchPtr, this);
  }

  YArray<T> getArray<T extends Object>(String name) {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final branchPtr = _bindings.yarray(_doc, namePtr);
    malloc.free(namePtr);
    return YArray._(this, branchPtr);
  }

  YMap<T> getMap<T>(String name) {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final branchPtr = _bindings.ymap(_doc, namePtr);
    malloc.free(namePtr);
    return YMap._(this, branchPtr);
  }

  YXmlFragment getXmlFragment(String name) {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final branchPtr = _bindings.yxmlfragment(_doc, namePtr);
    malloc.free(namePtr);
    return YXmlFragment._(this, branchPtr);
  }

  YUndoManager getUndoManager({int captureTimeoutMillis = 0}) {
    final options = calloc<gen.YUndoManagerOptions>();
    options.ref.capture_timeout_millis = captureTimeoutMillis;
    final undoManagerPtr = _bindings.yundo_manager(_doc, options);
    calloc.free(options);
    return YUndoManager._(undoManagerPtr);
  }

  Uint8List state() {
    late Uint8List result;
    _transaction((txn) {
      final ffi.Pointer<ffi.Uint32> lenPtr = malloc<ffi.Uint32>();
      final stateVecBinaryPtr = _bindings.ytransaction_state_vector_v1(
        txn,
        lenPtr,
      );
      final len = lenPtr.value;
      malloc.free(lenPtr);

      result = stateVecBinaryPtr.asTypedListFinalized(len);
    });
    return result;
  }

  Uint8List diff(Uint8List? stateVector) {
    final sv = stateVector ?? Uint8List.fromList([0]);
    late Uint8List result;
    _transaction((txn) {
      final ffi.Pointer<ffi.Uint32> lenPtr = malloc<ffi.Uint32>();
      final stateVecPtr = malloc<ffi.Uint8>(sv.length);
      stateVecPtr.asTypedList(sv.length).setAll(0, sv);

      final diffPtr = _bindings.ytransaction_state_diff_v1(
        txn,
        stateVecPtr.cast<ffi.Char>(),
        sv.length,
        lenPtr,
      );
      malloc.free(stateVecPtr);
      final diffLen = lenPtr.value;
      malloc.free(lenPtr);

      result = diffPtr.asTypedListFinalized(diffLen);
    });
    return result;
  }

  void sync(Uint8List update) {
    _transaction((txn) {
      // Copy the buffer into native memory.
      final updatePtr = malloc<ffi.Uint8>(update.length);
      updatePtr.asTypedList(update.length).setAll(0, update);

      _bindings.ytransaction_apply(
        txn,
        updatePtr.cast<ffi.Char>(),
        update.length,
      );
      malloc.free(updatePtr);
    });
  }

  static void _observeCallback(
    ffi.Pointer<ffi.Void> idPtr,
    int dataLen,
    ffi.Pointer<ffi.Char> data,
  ) {
    if (!_YObservable._shouldEmit(idPtr)) return;
    final streamController = _YObservable._controller<Uint8List>(idPtr);
    // don't use _bindings.ybinary_destroy as we don't own the pointer
    final buffer = data.cast<ffi.Uint8>().asTypedList(dataLen);
    final bufferCopy = Uint8List.fromList(buffer);
    streamController.add(bufferCopy);
  }

  StreamSubscription<Uint8List> listen(void Function(Uint8List) callback) {
    final callbackPtr =
        ffi.Pointer.fromFunction<NativeDocObserveCallback>(_observeCallback);

    return _listen(
      callback,
      (state) => _bindings.ydoc_observe_updates_v1(_doc, state, callbackPtr),
    );
  }

  T transaction<T>(
    T Function() callback, {
    YOrigin? origin,
  }) {
    T innerTxn() {
      // If we are inside a transaction, we do not need to create a new one.
      if (YTransaction._fromZoneNullable() != null) {
        return callback();
      }

      final txn = YTransaction._(this, origin);
      return Zone.current.fork(zoneValues: {YTransaction: txn}).run(
        () {
          final result = callback();
          txn._commit();
          return result;
        },
      );
    }

    final currentOrigin = Zone.current[#y_crdt_txn_origin];
    if (origin != null && currentOrigin != origin) {
      return Zone.current.fork(
        zoneValues: {
          #y_crdt_txn_origin: origin,
        },
      ).run(() => innerTxn());
    } else {
      return innerTxn();
    }
  }

  T _transaction<T>(
    T Function(ffi.Pointer<gen.TransactionInner> txn) callback,
  ) {
    return transaction(() {
      final txn = YTransaction._fromZone();
      return callback(txn._txn);
    });
  }
}
