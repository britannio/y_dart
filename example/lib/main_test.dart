import 'dart:developer';
import 'package:y_dart/y_dart.dart';

void main() {
  final d1 = YDoc();
  final text = d1.getText('test');
  text.append('Hello, world!');

  final d2 = YDoc();
  final d2Version = d2.state();
  final diff = d1.diff(d2Version);
  print(diff);
  d2.sync(diff);

  log(d2.getText('test').toString());
}
