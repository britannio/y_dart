part of 'all.dart';

final class YTransaction {
  final ffi.Pointer<gen.TransactionInner> _txn;
  final bool writable;

  YTransaction._init(this._txn, this.writable);

  factory YTransaction._(YDoc doc, YOrigin? yOrigin) {
    (ffi.Pointer<ffi.Char> ptr, int len) txnOriginPointer() {
      if (yOrigin == null) return (ffi.nullptr, 0);
      final origin = yOrigin.toBytes();
      final originLen = origin.length;
      final originPtr = malloc<ffi.Uint8>(originLen);
      originPtr.asTypedList(originLen).setAll(0, origin);
      return (originPtr.cast<ffi.Char>(), originLen);
    }

    final (ptr, originLen) = txnOriginPointer();
    final txn = _bindings.ydoc_write_transaction(doc._doc, originLen, ptr);
    malloc.free(ptr);
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
