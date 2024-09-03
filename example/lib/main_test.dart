import 'dart:developer';
import 'package:y_dart/y_dart.dart';

void main() {
  final d1 = YDoc();
  final text = d1.getText('test');
  final sub = d1.listen((event) {
    log('Received update of length: ${event.length}');
    // log(event.toString());
  });
  text.append('Hello, world!');
  // sub.pause();

  text.append(' second');
  sub.resume();

  final d2 = YDoc();
  final d2Version = d2.state();
  final diff = d1.diff(d2Version);
  log(diff.length.toString());
  d2.sync(diff);

  log(d2.getText('test').toString());
}
