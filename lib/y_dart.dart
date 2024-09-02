// import 'dart:async';
import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
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

/// The bindings to the native functions in [_dylib].˝
final gen.YDartBindings _bindings = gen.YDartBindings(_dylib);

class YDoc {
  YDoc._(this._doc);

  // Generates a doc with a random id.
  // TODO create other constructors.
  factory YDoc() {
    final doc = _bindings.ydoc_new();
    return YDoc._(doc);
  }

  factory YDoc.clone(YDoc doc) {
    final clonedDocPtr = _bindings.ydoc_clone(doc._doc);
    return YDoc._(clonedDocPtr);
  }

  final ffi.Pointer<gen.YDoc> _doc;

  late final int id = _bindings.ydoc_id(_doc);

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
    try {
      final branchPtr = _bindings.ytext(_doc, namePtr);
      return YText._(branchPtr, this);
    } finally {
      malloc.free(namePtr);
    }
  }

  void transaction(void Function() callback) {
    // If we are inside a transaction, we do not need to create a new one.
    if (YTransaction._fromZoneNullable() != null) {
      callback();
      return;
    }

    final txn = YTransaction._(this);
    runZoned(() {
      callback();
      txn._commit();
    }, zoneValues: {YTransaction: txn});
  }

  void _transaction(void Function(YTransaction txn) callback) {
    transaction(() {
      final txn = YTransaction._fromZone();
      callback(txn);
    });
  }

  void destroy() {
    _bindings.ydoc_destroy(_doc);
  }

  // getArray(String name) {
  //   // TODO free pointers!
  //   final namePtr = name.toNativeUtf8().cast<Char>();
  //   final branchPtr = _bindings.yarray(_doc, namePtr);
  //   // return YArray(array);
  // }
}

final class YText {
  // TODO free this once closed
  final ffi.Pointer<gen.Branch> _branch;
  final YDoc _doc;

  YText._(this._branch, this._doc);

  void append(String text) => insert(index: length, text: text);

  void insert({required int index, required String text}) {
    // TODO support text attributes
    _doc._transaction((txn) {
      final textPtr = text.toNativeUtf8().cast<ffi.Char>();
      try {
        _bindings.ytext_insert(_branch, txn._txn, index, textPtr, ffi.nullptr);
      } finally {
        malloc.free(textPtr);
      }
    });
  }

  int get length {
    late int len;
    _doc._transaction((txn) {
      len = _bindings.ytext_len(_branch, txn._txn);
    });
    return len;
  }

  void removeRange({required int start, required int length}) {
    _doc._transaction((txn) {
      _bindings.ytext_remove_range(_branch, txn._txn, start, length);
    });
  }

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
      final ptr = _bindings.ytext_string(_branch, txn._txn);
      try {
        result = ptr.cast<Utf8>().toDartString();
      } finally {
        _bindings.ystring_destroy(ptr);
      }
    });
    return result;
  }
}

class YTransaction {
  final ffi.Pointer<gen.TransactionInner> _txn;
  final bool writable;

  YTransaction._init(this._txn, this.writable);

  factory YTransaction._(YDoc doc) {
    // Note that there's a read transaction too
    final txn = _bindings.ydoc_write_transaction(doc._doc, 0, ffi.nullptr);
    const writable = true; // _bindings.ytransaction_writeable(txn) == 1;
    return YTransaction._init(txn, writable);
  }

  void _commit() {
    _bindings.ytransaction_commit(_txn);
  }

  static YTransaction _fromZone() => Zone.current[YTransaction] as YTransaction;
  static YTransaction? _fromZoneNullable() =>
      Zone.current[YTransaction] as YTransaction?;
}

class YUndoManager {}

/// A very short-lived native function.
///
/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
// int sum(int a, int b) => _bindings.sum(a, b);

int random() => _bindings.random();

/// A longer lived native function, which occupies the thread calling it.
///
/// Do not call these kind of native functions in the main isolate. They will
/// block Dart execution. This will cause dropped frames in Flutter applications.
/// Instead, call these native functions on a separate isolate.
///
/// Modify this to suit your own use case. Example use cases:
///
/// 1. Reuse a single isolate for various different kinds of requests.
/// 2. Use multiple helper isolates for parallel execution.
// Future<int> sumAsync(int a, int b) async {
//   final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
//   final int requestId = _nextSumRequestId++;
//   final _SumRequest request = _SumRequest(requestId, a, b);
//   final Completer<int> completer = Completer<int>();
//   _sumRequests[requestId] = completer;
//   helperIsolateSendPort.send(request);
//   return completer.future;
// }



/*

/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _SumRequest {
  final int id;
  final int a;
  final int b;

  const _SumRequest(this.id, this.a, this.b);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _SumResponse {
  final int id;
  final int result;

  const _SumResponse(this.id, this.result);
}

/// Counter to identify [_SumRequest]s and [_SumResponse]s.
int _nextSumRequestId = 0;

/// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _SumResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _sumRequests[data.id]!;
        _sumRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _SumRequest) {
          final int result = _bindings.sum_long_running(data.a, data.b);
          final _SumResponse response = _SumResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();


*/