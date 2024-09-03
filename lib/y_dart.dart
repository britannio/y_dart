library y_dart;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'y_dart_bindings_generated.dart' as gen;

const String _libName = 'y_dart';

/// The dynamic library in which the symbols for [YDartBindings] can be found.
final ffi.DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return ffi.DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final gen.YDartBindings _bindings = gen.YDartBindings(_dylib);

typedef NativeSubscription = ffi.Pointer<gen.YSubscription> Function(
    ffi.Pointer<ffi.Void> state);
typedef NativeDocObserveCallback = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Pointer<ffi.Char>);

typedef NativeTextObserveCallback = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<gen.YTextEvent>);

mixin _YObservable {
  static bool shouldEmit(ffi.Pointer<ffi.Void> idPtr) {
    final id = idPtr.cast<ffi.Uint64>().value;
    return _subscriptions.containsKey(id) && !_subscriptions[id]!.isPaused;
  }

  static int _nextObserveId = 0;
  static final Map<int, StreamController<dynamic>> _subscriptions = {};

  static StreamController<T> controller<T>(ffi.Pointer<ffi.Void> idPtr) {
    final id = idPtr.cast<ffi.Uint64>().value;
    if (!_subscriptions.containsKey(id)) {
      throw StateError('No subscription found for id: $id');
    }
    final streamController = _subscriptions[id]!;
    return streamController as StreamController<T>;
  }

  StreamSubscription<T> _listen<T>(
    void Function(T) callback,
    NativeSubscription subscribe,
  ) {
    final observeId = _nextObserveId++;
    final observeIdPtr = malloc<ffi.Uint64>()..value = observeId;

    final ySubscription = subscribe(observeIdPtr.cast<ffi.Void>());
    final streamController = StreamController<T>(
      onCancel: () {
        _bindings.yunobserve(ySubscription);
        _subscriptions.remove(observeId);
        malloc.free(observeIdPtr);
      },
      sync: true,
    );

    _subscriptions[observeId] = streamController;
    return streamController.stream.listen(callback);
  }
}

class YDoc with _YObservable {
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
    return YDoc._(doc);
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

  YArray getArray(String name) {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final branchPtr = _bindings.yarray(_doc, namePtr);
    malloc.free(namePtr);
    return YArray._(this, branchPtr);
  }

  YMap getMap(String name) {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final branchPtr = _bindings.ymap(_doc, namePtr);
    malloc.free(namePtr);
    return YMap._(this, branchPtr);
  }

  YXml getXml(String name) {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final branchPtr = _bindings.yxmlfragment(_doc, namePtr);
    malloc.free(namePtr);
    return YXml._(this, branchPtr);
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

      // We could avoid a copy if we had a NativeFinalizer to provide to
      // asTypedList that performed the equivalent of ybinary_destroy.
      result = Uint8List.fromList(
        stateVecBinaryPtr.cast<ffi.Uint8>().asTypedList(len),
      );
      _bindings.ybinary_destroy(stateVecBinaryPtr, len);
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

      // We could avoid a copy if we had a NativeFinalizer to provide to
      // asTypedList that performed the equivalent of ybinary_destroy.
      result = Uint8List.fromList(
        diffPtr.cast<ffi.Uint8>().asTypedList(diffLen),
      );
      _bindings.ybinary_destroy(diffPtr, diffLen);
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
    if (!_YObservable.shouldEmit(idPtr)) return;
    final streamController = _YObservable.controller<Uint8List>(idPtr);
    // don't use _bindings.ybinary_destroy as we don't own the pointer
    final buffer = data.cast<ffi.Uint8>().asTypedList(dataLen);
    final bufferCopy = Uint8List.fromList(buffer);
    streamController.add(bufferCopy);
  }

  StreamSubscription<Uint8List> listen(void Function(Uint8List) callback) {
    final callbackPtr =
        ffi.Pointer.fromFunction<NativeDocObserveCallback>(_observeCallback);

    return _listen<Uint8List>(
      callback,
      (state) => _bindings.ydoc_observe_updates_v1(_doc, state, callbackPtr),
    );

    // final subscription = _bindings.ydoc_observe_updates_v1(
    //   _doc,
    //   observeIdPtr.cast<ffi.Void>(),
    //   callbackPtr,
    // );
    // final streamController = StreamController<Uint8List>(
    //   onCancel: () {
    //     _bindings.yunobserve(subscription);
    //     _observeSubscriptions.remove(observeId);
    //     malloc.free(observeIdPtr);
    //   },
    //   // Should be safe as we only add to the stream in the last line of the
    //   // callback
    //   sync: true,
    // );

    // _observeSubscriptions[observeId] = (streamController, false);

    // return streamController.stream.listen(callback);
  }

  void transaction(void Function() callback, {Uint8List? origin}) {
    void innterTxn() {
      // If we are inside a transaction, we do not need to create a new one.
      if (YTransaction._fromZoneNullable() != null) {
        // Note that this ignores origin!
        // Would it be better to store the origin in a zoneValue so we could
        // nest origins while maintaining the same transaction?
        callback();
        return;
      }

      final txn = YTransaction._(this, origin);
      runZoned(() {
        callback();
        txn._commit();
      }, zoneValues: {YTransaction: txn});
    }

    if (origin != null) {
      runZoned(() => innterTxn(), zoneValues: {#y_crdt_txn_origin: origin});
    } else {
      innterTxn();
    }
  }

  void _transaction(
    void Function(ffi.Pointer<gen.TransactionInner> txn) callback,
  ) {
    transaction(() {
      final txn = YTransaction._fromZone();
      callback(txn._txn);
    });
  }

  void destroy() {
    _bindings.ydoc_destroy(_doc);
  }
}

sealed class YTextChange {}

class YTextDeleted extends YTextChange {
  final int index;

  YTextDeleted(this.index);
}

class YTextInserted extends YTextChange {
  final String value;
  final List<(String, Object)> attributes;

  YTextInserted(this.value, this.attributes);
}

class YTextRetained extends YTextChange {
  final int index;
  final List<(String, Object)> attributes;

  YTextRetained(this.index, this.attributes);
}

final class YText {
  YText._(this._branch, this._doc);
  // TODO free this once closed
  final ffi.Pointer<gen.Branch> _branch;
  final YDoc _doc;

  int _nextObserveId = 0;
  static final Map<int, (StreamController<Uint8List> sc, bool paused)>
      _observeSubscriptions = {};

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

  // static void _observeCallback(
  //   ffi.Pointer<ffi.Void> idPtr,
  //   ffi.Pointer<gen.YTextEvent> event,
  // ) {
  //   final observeId = idPtr.cast<ffi.Uint64>().value;
  //   if (!_observeSubscriptions.containsKey(observeId)) return;
  //   final (streamController, paused) = _observeSubscriptions[observeId]!;
  //   if (paused) return;
  //   final deltaLenPtr = malloc<ffi.Uint32>();
  //   final delta = _bindings.ytext_event_delta(event, deltaLenPtr);
  //   final deltaLen = deltaLenPtr.value;
  //   malloc.free(deltaLenPtr);
  // }

  // Stream<YTextChange> listen() {
  //   final callbackPtr =
  //       ffi.Pointer.fromFunction<NativeTextObserveCallback>(_observeCallback);
  //   final observeId = _nextObserveId++;
  //   final observeIdPtr = malloc<ffi.Uint64>()..value = observeId;

  //   final subscription = _bindings.ytext_observe(
  //     _branch,
  //     observeIdPtr.cast<ffi.Void>(),
  //     callbackPtr,
  //   );
  //   final streamController = StreamController<YTextChange>(
  //     onListen: () {},
  //     onCancel: () {
  //       _bindings.yunobserve(subscription);
  //       // _observeSubscriptions.remove(observeId);
  //       malloc.free(observeIdPtr);
  //     },
  //     sync: true,
  //   );
  // }

  // void _observe(void Function() callback) {
  //   _observeRaw((_, event) {
  //     // What can we do with YTextEvent?
  //     callback();
  //   });
  // }

  // void _observeRaw(void Function(ffi.Pointer<ffi.Void>, ffi.Pointer<gen.YTextEvent>) callback) {
  //   final callbackPointer = ffi.Pointer.fromFunction<ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Pointer<gen.YTextEvent>)>(callback);
  //   final subscription = _bindings.ytext_observe(_branch, ffi.nullptr, callbackPointer);
  //   // TODO: Handle subscription cleanup
  // }

  // Does this make sense for fomatted text?
  // String operator [](int index);

  @override
  String toString() {
    late final String result;
    _doc._transaction((txn) {
      final ptr = _bindings.ytext_string(_branch, txn);
      try {
        result = ptr.cast<Utf8>().toDartString();
      } finally {
        _bindings.ystring_destroy(ptr);
      }
    });
    return result;
  }
}

final class YTransaction {
  final ffi.Pointer<gen.TransactionInner> _txn;
  final bool writable;
  final Uint8List? origin;

  YTransaction._init(this._txn, this.writable, this.origin);

  factory YTransaction._(YDoc doc, Uint8List? origin) {
    final originLen = origin?.length ?? 0;
    final originPtr = malloc<ffi.Uint8>(originLen);
    originPtr.asTypedList(originLen).setAll(0, origin ?? []);

    final txn = _bindings.ydoc_write_transaction(
      doc._doc,
      originLen,
      origin != null ? originPtr.cast<ffi.Char>() : ffi.nullptr,
    );
    const writable = true; // _bindings.ytransaction_writeable(txn) == 1;
    return YTransaction._init(txn, writable, origin);
  }

  void _commit() {
    _bindings.ytransaction_commit(_txn);
  }

  static YTransaction _fromZone() => Zone.current[YTransaction] as YTransaction;
  static YTransaction? _fromZoneNullable() =>
      Zone.current[YTransaction] as YTransaction?;
}

final class YUndoManager {
  // Constructor with the shared type to manage
  // optionalloy a Set of tracked origins??
  void undo() {}
  void redo() {}
  void stopCapturing() {}
}

final class YArray extends DelegatingList<Object> {
  YArray._(
    this._doc,
    this._branch,
  ) : super([]);
  final YDoc _doc;
  final ffi.Pointer<gen.Branch> _branch;
}

final class YMap extends DelegatingMap<Object, Object> {
  YMap._(
    this._doc,
    this._branch,
  ) : super({});

  final YDoc _doc;
  final ffi.Pointer<gen.Branch> _branch;
}

final class YXml {
  YXml._(this._doc, this._branch);

  final YDoc _doc;
  final ffi.Pointer<gen.Branch> _branch;
}
