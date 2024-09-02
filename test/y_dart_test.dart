import 'package:flutter_test/flutter_test.dart';
import 'package:y_dart/y_dart.dart';

void main() {
  test('test', () {
    final d1 = YDoc();
    final text = d1.getText('test');
    text.append('Hello, world!');
    print(text.toString());
  });
}
