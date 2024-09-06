part of 'all.dart';

typedef NativeSubscription = ffi.Pointer<gen.YSubscription> Function(
    ffi.Pointer<ffi.Void> state);

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
    final ffi.Pointer<ffi.Uint64> observeIdPtr = malloc<ffi.Uint64>();
    observeIdPtr.value = observeId;

    final ySubscription = subscribe(observeIdPtr.cast());
    final streamController = StreamController<T>(
      onCancel: () {
        gen.yunobserve(ySubscription);
        _subscriptions.remove(observeId);
        malloc.free(observeIdPtr);
      },
      sync: true,
    );

    _subscriptions[observeId] = streamController;
    return streamController.stream.listen(callback);
  }
}
