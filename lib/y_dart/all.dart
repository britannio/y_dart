import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'ffi/y_dart_bindings_generated.dart' as gen;

part 'ffi/ffi.dart';

part 'undo_manager.dart';
part 'y_array.dart';
part 'y_doc.dart';
part 'y_map.dart';
part 'y_xml.dart';
// part 'y_output.dart';
part 'y_text.dart';
// part 'y_type.dart';
part 'y_origin.dart';

typedef NativeSubscription = ffi.Pointer<gen.YSubscription> Function(
    ffi.Pointer<ffi.Void> state);
typedef NativeDocObserveCallback = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Pointer<ffi.Char>);

typedef NativeTextObserveCallback = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<gen.YTextEvent>);

mixin _YObservable {
  static bool _shouldEmit(ffi.Pointer<ffi.Void> idPtr) {
    final id = idPtr.cast<ffi.Uint64>().value;
    return _subscriptions.containsKey(id) && !_subscriptions[id]!.isPaused;
  }

  static int _nextObserveId = 0;
  static final Map<int, StreamController<dynamic>> _subscriptions = {};

  static StreamController<T> _controller<T>(ffi.Pointer<ffi.Void> idPtr) {
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

sealed class YTextChange {}

class YTextDeleted extends YTextChange {
  final int length;

  YTextDeleted(this.length);
}

class YTextInserted extends YTextChange {
  final String value;
  final Map<String, Object> attributes;

  YTextInserted(this.value, this.attributes);
}

class YTextRetained extends YTextChange {
  final int length;
  final Map<String, Object> attributes;

  YTextRetained(this.length, this.attributes);
}

abstract class YType {
  // TODO free this once closed
  final ffi.Pointer<gen.Branch> _branch;
  YType._(this._branch);
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

sealed class YValue {}

final class YOutput extends YValue {
  YOutput._();

  factory YOutput.fromFfi(gen.YOutput output) {
    return YOutput._();
  }
}

final class YInput extends YValue {
  // TODO implement this
  gen.YInput get _input => _bindings.yinput_null();
}
