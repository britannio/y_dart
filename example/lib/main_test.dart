// ignore_for_file: avoid_print

import 'dart:developer';
import 'package:y_dart/y_dart.dart';

void main() {
  demo11ReversedSync();
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
  arr.listen((event) {
    print('in callback');
    print("listen: $event");
    for (final change in event.changes) {
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
  map.listen((event) {
    print("listen: $event");

    final first = event.changes.first;
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

void demo10DoubleInit() {
  final d1 = YDoc();
  final d2 = YDoc();

  d1.getText('test').append('hello');
  d2.getText('test').append('world');

  d1.sync(d2.diff(d1.state()));
  d2.sync(d1.diff(d2.state()));

  log(d1.getText('test').toString());
  log(d2.getText('test').toString());
}

Future<void> flushMicrotasks() async {
  await Future.delayed(Duration.zero);
}

Future<void> demo11ReversedSync() async {
  final d1 = YDoc();
  final d2 = YDoc();

  final d1Diffs = <YDiff>[];
  final d2Diffs = <YDiff>[];

  d1.listen((diff) {
    d1Diffs.add(diff);
    print('diff1: ${diff.diff.length}');
  });
  d2.listen(d2Diffs.add);

  final d1Text = d1.getText('test');
  d1Text.append('a');
  d1Text.append('bc');
  d1Text.append('def');

  d1Text.listen((changes) {
    print('listen: $changes');
  });

  final d2Text = d2.getText('test');
  d2Text.append('g');
  d2Text.append('hi');
  d2Text.append('jkl');

  // d1.sync(d2.diff(d1.state()));
  // d2.sync(d1.diff(d2.state()));

  await flushMicrotasks();

  d1Diffs.forEach(d2.sync);
  d2Diffs.forEach(d1.sync);

  // await flushMicrotasks();

  // d1.sync(d2.diff(d1.state()));
  // d2.sync(d1.diff(d2.state()));

  print(d1Diffs);

  log("d1: ${d1.getText('test')}");
  log("d2: ${d2.getText('test')}");

  for (int i = 0; i < 10; i++) {
    d2.sync(d1Diffs.first);
  }
}
