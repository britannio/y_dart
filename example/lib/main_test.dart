import 'package:y_dart/y_dart.dart';

void main() {
  final d1 = YDoc();
  final text = d1.getText('test');
  text.append('Hello, world!');

  final d2 = YDoc();
  final d2StateVector = d2.encodeStateVector();
  final diff = d1.encodeStateAsUpdate(d2StateVector);
  d2.applyUpdate(diff);

  print(d2.getText('test').toString());
}
