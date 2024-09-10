part of 'y_dart.dart';

typedef NativeSubscription = ffi.Pointer<gen.YSubscription> Function(
    ffi.Pointer<ffi.Void> state);

mixin _YObservable<T extends Object> {
  static bool _shouldEmit(ffi.Pointer<ffi.Void> idPtr) {
    final id = idPtr.cast<ffi.Uint64>().value;
    return _subscriptions.containsKey(id) && !_subscriptions[id]!.isPaused;
  }

  static int _nextObserveId = 0;
  static final Map<int, StreamController<dynamic>> _subscriptions = {};
  static final Map<int, Object> _customData = {};

  static StreamController<T> _controller<T>(ffi.Pointer<ffi.Void> idPtr) {
    final id = idPtr.cast<ffi.Uint64>().value;
    if (!_subscriptions.containsKey(id)) {
      throw StateError('No subscription found for id: $id');
    }
    final streamController = _subscriptions[id]!;
    return streamController as StreamController<T>;
  }

  static Object? _getCustomData(ffi.Pointer<ffi.Void> idPtr) {
    final id = idPtr.cast<ffi.Uint64>().value;
    return _customData[id];
  }

  StreamSubscription<T> _listen(
    void Function(T) callback,
    NativeSubscription subscribe, {
    Object Function()? customDataCallback,
  }) {
    final observeId = _nextObserveId++;
    final ffi.Pointer<ffi.Uint64> observeIdPtr = malloc<ffi.Uint64>();
    observeIdPtr.value = observeId;

    final ySubscription = subscribe(observeIdPtr.cast());
    // This cannot be a sync stream or else `callback` will be run before the
    // static Dart callback invoked from rust finishes. On the rust side, its
    // opening a transaction that gets comitted once the static Dart callback
    // finishes so if we invoke `callback` during this period, user code
    // won't be able to open a transaction, even a read-only one.
    final streamController = StreamController<T>(
      onCancel: () {
        _bindings.yunobserve(ySubscription);
        _subscriptions.remove(observeId);
        malloc.free(observeIdPtr);
      },
    );

    _subscriptions[observeId] = streamController;
    if (customDataCallback != null) {
      _customData[observeId] = customDataCallback();
    }
    return streamController.stream.listen(callback);
  }
}
