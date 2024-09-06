import 'dart:developer';

import 'package:flutter_test/flutter_test.dart';
import 'package:y_dart/y_dart.dart';
// import 'package:y_dart/y_dart/ffi/y_dart_bindings_generated.dart' as gen;

void main() {
  test('1', () {
    demo1();
  });

  test('2', () {
    final d1 = YDoc();
    final d2 = YDoc();

    d1.listen((update) {
      d2.sync(update);
    });

    d2.listen((update) {
      d1.sync(update);
    });

    final text = d1.getText('test');
    text.append('Hello, world!');
    // print(text);
    // print(d2.getText('test').toString());
  });

  test('3', () {
    demo3UndoManager();
  });

  test('4', () {
    print('started');
    final d = YDoc();
    // final ls = d.getArray<String>('my-array');

    // for (int i = 0; i < 5; i++) {
    //   ls[i] = '$i';
    // }
    // log(ls.toString());
    // log('len: ${ls.length}');
  });

  test('5', () {
    demo5Array();
  });

  test('6', () {
    demo6TextSubscription();
  });

  test('7', () {
    demo7ArraySubscription();
  });
}

void demo1() {
  final d1 = YDoc();
  final text = d1.getText('test');
  d1.listen((event) {
    log('Received update of length: ${event.length}');
    // log(event.toString());
  });

  // Updates in a transaction are batched!
  d1.transaction(() {
    text.append('Hello, world!');
    text.append(' second');
    // sub.resume();
  });

  final d2 = YDoc();
  final d2Version = d2.state();
  final diff = d1.diff(d2Version);
  log(diff.length.toString());
  d2.sync(diff);

  log(d2.getText('test').toString());

  // final map = d2.getMap('test');
  // final res = map[null];
}

void demo2() async {}

void demo3UndoManager() {
  final d1 = YDoc();
  final undoManager = d1.getUndoManager();
  final origin = YOrigin.fromString('alice');
  undoManager.addOrigin(origin);

  final t = d1.getText('test');
  undoManager.addScope(t);
  t.append('Hello, world!');
  d1.transaction(() => t.append('second'), origin: origin);
  t.append('third');

  undoManager.undo();
  undoManager.undo(); // Redundant.
  log(t.toString());
}

void demo4Array() {}

void demo5Array() {
  final d = YDoc();
  final ls = d.getArray<YDoc>('my-array');

  for (int i = 0; i < 5; i++) {
    ls[i] = YDoc();
  }
  log(ls.toString());
  log('len: ${ls.length}');
}

void demo6TextSubscription() {
  final d = YDoc();
  final text = d.getText('main');
  text.listen((change) {
    log("listen: $change");
  });

  log('subscribe');

  // d.transaction(() {
  text.append('the');
  text.append(' quick');
  text.append(' brown', attributes: {'bold': true});
  text.append(' fox');
  text.append(' fumps');
  text.removeRange(start: 20, length: 1);
  text.insert(index: 20, text: 'j');
  text.append(' over');
  text.format(0, 3, attributes: {'italic': 'true'});
  // });

  log(text.toString());

  log(text.toDelta().toString());
}

void demo7ArraySubscription() {
  final d = YDoc();
  final arr = d.getArray<String>('my-array');
  arr.listen((change) {
    log("listen: $change");
  });

  arr.add('1');
  arr.add('2');
  arr.add('3');
  arr.add('4');
  arr.add('5');
  arr.add('6');
  arr.add('7');
  arr.add('8');
  arr.add('9');
  arr.add('10');

  log(arr.toString());
}
