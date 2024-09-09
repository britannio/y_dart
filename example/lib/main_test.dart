// ignore_for_file: avoid_print

import 'dart:developer';
import 'package:y_dart/y_dart.dart';

void main() {
  demo9Map();
}

void demo1() {
  print('demo1');
  final d1 = YDoc();
  final text = d1.getText('test');
  d1.listen((event) {
    log('Received update of length: ${event.diff.length}');
    log(event.toString());
    d1.transaction(() {});
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
  log(diff.diff.length.toString());
  d2.sync(diff);

  log(d2.getText('test').toString());

  // final map = d2.getMap('test');
  // final res = map[null];
}

void demo2() async {
  final d1 = YDoc();
  final d2 = YDoc();

  d1.listen((update) {
    d2.sync(update);
  });

  d2.listen((update) {
    d1.sync(update);
  });

  d1.getText('test').append('Hello, world!');
  print(d2.getText('test').toString());
}

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

void demo4Array() {
  final d = YDoc();
  final ls = d.getArray<String>('my-array');

  for (int i = 0; i < 5; i++) {
    ls[i] = '$i';
  }
  log(ls.toString());
  log('len: ${ls.length}');
}

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

Future<void> demo8ArraySubWithYType() async {
  // If we cache a YType produced by the listen callback, is it still valid
  // later on?

  final d = YDoc();
  final arr = d.getArray<YText>('my-array');
  late YText afterListen;
  arr.listen((changes) {
    print('in callback');
    print("listen: $changes");
    for (final change in changes) {
      switch (change) {
        case YArrayDeleted(length: var length):
          log("deleted: $length");
          break;
        case YArrayInserted(length: var length, values: var values):
          afterListen = values.first as YText;
          log("inserted: $length");
          break;
        case YArrayRetained(length: var length):
          log("retained: $length");
          break;
      }
    }
  });

  final text = d.getText('my-text');
  text.append('hello');

  arr.add(text);
  await Future.delayed(Duration.zero);

  print('after listen');
  print(afterListen.toString());
}

Future<void> demo9Map() async {
  final d = YDoc();
  final map = d.getMap<YText>('my-map');
  map.listen((changes) {
    print("listen: $changes");

    final first = changes.first;
    if (first is YMapChangeAdded) {
      final txt = first.value as YText;
      txt.append('from listener');
      print(txt);
    }
  });

  final text = d.getText('my-text');
  final text2 = d.getText('my-text2');
  text.append('hello');
  text2.append('world');

  await Future.delayed(Duration.zero);
  print(text);
  print(map);
  print('before: $map');
  map['my-text'] = text;
  await Future.delayed(Duration.zero);
  print('after: $map');
  map['my-text'] = text2;
  map.remove('my-text');
  await Future.delayed(Duration.zero);

  print('after listen');
  print(map.toString());
}
