import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'ffi/y_dart_bindings_generated.dart' as gen;

part 'ffi/ffi.dart';
part 'undo_manager.dart';
part 'y_array.dart';
part 'doc.dart';
part 'y_map.dart';
part 'y_xml.dart';
part 'y_type.dart';
part 'text_change.dart';
part 'y_text.dart';
part 'observable.dart';
part 'origin.dart';
part 'transaction.dart';
part 'value.dart';

void arrayIterRepro() {
  final doc = gen.ydoc_new();
  final arrayName = 'my-array'.toNativeUtf8();
  final array = gen.yarray(doc, arrayName.cast());
  malloc.free(arrayName);

  var txn = gen.ydoc_write_transaction(doc, 0, ffi.nullptr);
  final inputPtr = malloc<gen.YInput>();
  inputPtr.ref = gen.yinput_long(1);
  print('before insert_range');
  gen.yarray_insert_range(array, txn, 0, inputPtr, 1);
  print('after insert_range');
  gen.ytransaction_commit(txn);
  malloc.free(inputPtr);
  print('after transaction_commit');

  txn = gen.ydoc_write_transaction(doc, 0, ffi.nullptr);
  print('before iter');
  final iter = gen.yarray_iter(array, txn);
  print('after iter');
  gen.ytransaction_commit(txn);
  print('after transaction_commit');

  print('before next1');
  final next1 = gen.yarray_iter_next(iter);
  print('after next1');
  print('before next2');
  final next2 = gen.yarray_iter_next(iter);
  print('after next2');
  print(next1);
  print(next2);
}
