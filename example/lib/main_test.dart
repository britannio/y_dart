import 'dart:developer';
import 'package:y_dart/y_dart.dart';

void main() {
  // demo1();
  demo3UndoManager();
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
