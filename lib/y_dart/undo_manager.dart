part of 'all.dart';

final class YUndoManager implements ffi.Finalizable {
  YUndoManager._(this._undoManager) {
    YFree.undoManagerFinalizer.attach(this, _undoManager.cast<ffi.Void>());
  }
  final ffi.Pointer<gen.YUndoManager> _undoManager;

  // Constructor with the shared type to manage
  // optionalloy a Set of tracked origins??
  void undo() {
    _bindings.yundo_manager_undo(_undoManager);
  }

  void redo() {
    _bindings.yundo_manager_redo(_undoManager);
  }

  void stopCapturing() {
    // Should it actually be called 'commit' or 'freeze'
    _bindings.yundo_manager_stop(_undoManager);
  }

  void addOrigin(YOrigin origin) {
    final originBytes = origin.toBytes();
    final originPtr = malloc<ffi.Uint8>(originBytes.length);
    originPtr.asTypedList(originBytes.length).setAll(0, originBytes);
    _bindings.yundo_manager_add_origin(
      _undoManager,
      originBytes.length,
      originPtr.cast<ffi.Char>(),
    );
    malloc.free(originPtr);
  }

  void removeOrigin(YOrigin origin) {
    final originBytes = origin.toBytes();
    final originPtr = malloc<ffi.Uint8>(originBytes.length);
    originPtr.asTypedList(originBytes.length).setAll(0, originBytes);
    _bindings.yundo_manager_remove_origin(
      _undoManager,
      originBytes.length,
      originPtr.cast<ffi.Char>(),
    );
    malloc.free(originPtr);
  }

  void addScope(YType type) =>
      _bindings.yundo_manager_add_scope(_undoManager, type._branch);

  void clear() => _bindings.yundo_manager_clear(_undoManager);

  int get undoStackLen => _bindings.yundo_manager_undo_stack_len(_undoManager);

  int get redoStackLen => _bindings.yundo_manager_redo_stack_len(_undoManager);
}
