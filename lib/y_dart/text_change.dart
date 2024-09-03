part of 'all.dart';

sealed class YTextChange {}

class YTextDeleted extends YTextChange {
  final int length;

  YTextDeleted(this.length);
}

class YTextInserted extends YTextChange {
  final String value;
  final Map<String, Object> attributes;

  YTextInserted(this.value, this.attributes);
}

class YTextRetained extends YTextChange {
  final int length;
  final Map<String, Object> attributes;

  YTextRetained(this.length, this.attributes);
}
