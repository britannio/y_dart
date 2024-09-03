part of 'all.dart';

sealed class YValue {}

final class YOutput extends YValue {
  YOutput._();

  factory YOutput.fromFfi(gen.YOutput output) {
    return YOutput._();
  }
}

final class YInput extends YValue {
  // TODO implement this
  gen.YInput get _input => _bindings.yinput_null();
}
