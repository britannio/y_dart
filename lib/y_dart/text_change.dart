part of 'all.dart';

sealed class YTextChange {}

class YTextDeleted extends YTextChange {
  final int length;

  YTextDeleted(this.length);

  @override
  String toString() {
    return '{ delete: $length }';
  }
}

class YTextInserted extends YTextChange {
  final String value;
  final Map<String, Object> attributes;

  YTextInserted(this.value, this.attributes);

  @override
  String toString() {
    final attrsStr = attributes.isEmpty ? "" : ", attributes: $attributes";
    return "{ insert: '$value'$attrsStr }";
  }
}

class YTextRetained extends YTextChange {
  final int length;
  final Map<String, Object> attributes;

  YTextRetained(this.length, this.attributes);

  @override
  String toString() {
    return '{ retain: $length }';
  }
}
