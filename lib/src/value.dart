part of 'y_dart.dart';

sealed class YValue {}

final class _YOutput extends YValue {
  static T? toObjectInner<T extends Object>(gen.YOutput yOut, [YDoc? doc]) {
    late Object? result;
    assert(
      yOut.tag <= 0 || doc != null,
      'must provide doc when parsing YTypes',
    );

    switch (yOut.tag) {
      case gen.Y_JSON_BOOL:
        result = yOut.value.flag == 1;
        break;
      case gen.Y_JSON_NUM:
        result = yOut.value.num;
        break;
      case gen.Y_JSON_INT:
        result = yOut.value.integer;
        break;
      case gen.Y_JSON_STR:
        result = yOut.value.str.cast<Utf8>().toDartString();
        break;
      case gen.Y_JSON_BUF:
        final buf = yOut.value.buf.cast<ffi.Uint8>().asTypedList(yOut.len);
        result = Uint8List.fromList(buf);
        break;
      case gen.Y_JSON_ARR:
        result = List.generate(
          yOut.len,
          (i) => _YOutput.toObject(
            yOut.value.array + i,
            doc,
            disableFree: true,
          ),
        );
        break;
      case gen.Y_JSON_MAP:
        final map = <String, Object?>{};
        for (int i = 0; i < yOut.len; i++) {
          final key = yOut.value.map[i].key.cast<Utf8>().toDartString();
          final value = _YOutput.toObject(
            yOut.value.map[i].value,
            doc,
            disableFree: true,
          );
          map[key] = value;
        }
        result = map;
        break;
      case gen.Y_JSON_NULL:
      case gen.Y_JSON_UNDEF:
        result = null;
        break;
      case gen.Y_TEXT:
        result = YText._(yOut.value.y_type, doc!);
        break;
      case gen.Y_ARRAY:
        result = YArray._(doc!, yOut.value.y_type);
        break;
      case gen.Y_MAP:
        result = YMap._(doc!, yOut.value.y_type);
        break;
      case gen.Y_XML_ELEM:
        result = YXmlElement._(doc!, yOut.value.y_type);
        break;
      case gen.Y_XML_TEXT:
        result = YXmlText._(doc!, yOut.value.y_type);
        break;
      case gen.Y_DOC:
        result = YDoc._(yOut.value.y_doc);
        break;
      default:
        throw Exception('Unsupported value type: ${yOut.tag}');
    }
    return result as T?;
  }

  /// Invoked from [YArray], [YMap]
  static T toObject<T extends Object?>(
    /// Takes ownership of this pointer.
    ffi.Pointer<gen.YOutput> yOutPtr,
    // Required if the type is a YDoc or YType
    YDoc? doc, {
    /// Used to prevent double free of nested types.
    bool disableFree = false,
    ffi.Pointer<gen.YMapEntry>? yMapEntryPtr,
  }) {
    final result = toObjectInner(yOutPtr.ref, doc);

    if ((result is YType || result is YDoc)) {
      if (result is! ffi.Finalizable) {
        throw Exception('Result is not finalizable');
      }
      if (yMapEntryPtr != null) {
        // In rust, YMapEntry implements the Drop trait and calls drop on the
        // value so the outputFinalizer is unnecessary.
        _YFree.mapEntryFinalizer.attach(result, yMapEntryPtr.cast<ffi.Void>());
      } else {
        _YFree.outputFinalizer.attach(result, yOutPtr.cast<ffi.Void>());
      }
    } else {
      // The YValue is a JSON object and thus we converted it to entirely live
      // on the Dart heap so we are safe to free, unless this is a reentrant
      // call.
      if (!disableFree) {
        if (yMapEntryPtr != null) {
          // In rust, YMapEntry implements the Drop trait and calls drop on the
          // value so youtput_destroy is unnecessary.
          _bindings.ymap_entry_destroy(yMapEntryPtr);
        } else {
          _bindings.youtput_destroy(yOutPtr);
        }
      }
    }

    return result as T;
  }
}

abstract class _YInput extends YValue implements ffi.Finalizable {
  _YInput._internal();
  factory _YInput._(Object? value) {
    // TODO note that this misses Y_JSON
    if (value is bool) {
      return YInputJsonBool(value);
    } else if (value is double) {
      return YInputJsonNum(value);
    } else if (value is int) {
      return YInputJsonInt(value);
    } else if (value is String) {
      // Technically could be a Y_JSON??? i.e. a string that is valid JSON
      return YInputJsonString(value);
    } else if (value is Uint8List) {
      return YInputJsonBinary(value);
    } else if (value is List) {
      // list of json like objects
      return YInputJsonArray(value.map(_YInput._).toList());
    } else if (value is Map) {
      // Should this be value.cast<>()?
      return YInputJsonMap(value as Map<String, Object?>);
    } else if (value == null) {
      return YInputJsonNull();
    } else if (value is YArray) {
      return YInputYArray(value);
    } else if (value is YMap) {
      return YInputYMap(value);
    } else if (value is YDoc) {
      return YInputYDoc(value);
    } else if (value is YText) {
      return YInputYText(value);
    } else if (value is YXmlElement) {
      return YInputYXmlElem(value);
    } else if (value is YXmlText) {
      return YInputYXmlText(value);
    } else {
      throw Exception('Unsupported value type: ${value.runtimeType}');
    }
    // TODO handle YWeakLink
  }
  gen.YInput get _input;

  final Set<_YInput> _liveInputs = {};

  void dispose() {
    if (_liveInputs.isEmpty) return;
    for (final input in _liveInputs) {
      input.dispose();
    }
    _liveInputs.clear();
  }
}

final class YInputJsonNull extends _YInput {
  YInputJsonNull() : super._internal();

  @override
  gen.YInput get _input => _bindings.yinput_null();
}

final class YInputJsonBool extends _YInput {
  YInputJsonBool(this.value) : super._internal();
  final bool value;

  @override
  gen.YInput get _input => _bindings.yinput_bool(value ? 1 : 0);
}

final class YInputJsonNum extends _YInput {
  YInputJsonNum(this.value) : super._internal();
  final double value;

  @override
  gen.YInput get _input => _bindings.yinput_float(value);
}

final class YInputJsonInt extends _YInput {
  YInputJsonInt(this.value) : super._internal();
  final int value;

  @override
  gen.YInput get _input => _bindings.yinput_long(value);
}

final class YInputJsonString extends _YInput {
  YInputJsonString(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(this, _ptr.cast<ffi.Void>(), detach: this);
  }
  final String value;

  late final _ptr = value.toNativeUtf8().cast<ffi.Char>();
  @override
  late final gen.YInput _input = _bindings.yinput_string(_ptr);

  @override
  void dispose() {
    super.dispose();
    _YFree.mallocFinalizer.detach(this);
    malloc.free(_ptr);
  }
}

// final class YInputJson extends _YInput {
//   YInputJson(this.value) : super._internal() {
//     YFree.mallocFinalizer.attach(
//       this,
//       _ptr.cast(),
//       externalSize: _ptr.length + 1,
//       detach: this,
//     );
//   }
//   final Object value;

//   late final _ptr = jsonEncode(value).toNativeUtf8();

//   @override
//   late final gen.YInput _input = _bindings.yinput_json(_ptr.cast());

//   @override
//   void dispose() {
//     YFree.mallocFinalizer.detach(this);
//     malloc.free(_ptr);
//   }
// }

final class YInputJsonBinary extends _YInput {
  YInputJsonBinary(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(
      this,
      _ptr.cast<ffi.Void>(),
      externalSize: value.length,
      detach: this,
    );
  }
  final Uint8List value;

  late final _ptr = malloc<ffi.Uint8>(value.length);

  @override
  late final gen.YInput _input = () {
    _ptr.asTypedList(value.length).setAll(0, value);
    return _bindings.yinput_binary(_ptr.cast<ffi.Char>(), value.length);
  }();

  @override
  void dispose() {
    super.dispose();
    _YFree.mallocFinalizer.detach(this);
    malloc.free(_ptr);
  }
}

final class YInputJsonArray extends _YInput {
  YInputJsonArray(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(
      this,
      _inputPtr.cast<ffi.Void>(),
      detach: this,
    );
  }
  final List<Object?> value;
  late final _inputPtr = malloc<gen.YInput>(value.length);

  @override
  late final gen.YInput _input = () {
    final inputs = value.map(_YInput._).toList();
    // keeps the inputs alive for the duration of this input
    _liveInputs.addAll(inputs);
    for (int i = 0; i < value.length; i++) {
      _inputPtr[i] = inputs[i]._input;
    }
    final input = _bindings.yinput_json_array(_inputPtr, inputs.length);
    return input;
  }();

  @override
  void dispose() {
    // Dispose in reverse order of attachment
    _YFree.mallocFinalizer.detach(this);
    malloc.free(_inputPtr);
    super.dispose();
  }
}

final class YInputJsonMap extends _YInput {
  YInputJsonMap(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(
      this,
      _keysPtr.cast<ffi.Void>(),
      detach: this,
    );
    _YFree.mallocFinalizer.attach(
      this,
      _valuesPtr.cast<ffi.Void>(),
      detach: this,
    );
    for (final keyPtr in _keysPtrList) {
      _YFree.mallocFinalizer
          .attach(this, keyPtr.cast<ffi.Void>(), detach: this);
    }
  }

  final Map<String, Object?> value;
  late final _keysPtr = malloc<ffi.Pointer<ffi.Char>>(value.length);
  late final _valuesPtr = malloc<gen.YInput>(value.length);
  late final _keysPtrList = value //
      .keys
      .map((e) => e.toNativeUtf8().cast<ffi.Char>())
      .toList();

  @override
  late final gen.YInput _input = () {
    final inputs = value.entries.mapIndexed((i, e) {
      final value = e.value;
      final valueYInput = _YInput._(value);
      // keeps the inputs alive for the duration of this input
      _liveInputs.add(valueYInput);
      return (keyPtr: _keysPtrList[i], value: valueYInput);
    }).toList();

    inputs.forEachIndexed((i, pv) {
      _keysPtr[i] = pv.keyPtr;
      _valuesPtr[i] = pv.value._input;
    });

    final input = _bindings.yinput_json_map(
      _keysPtr,
      _valuesPtr,
      inputs.length,
    );
    return input;
  }();

  @override
  void dispose() {
    super.dispose();
    _YFree.mallocFinalizer.detach(this);
    _keysPtrList.forEach(malloc.free);
    malloc.free(_valuesPtr);
    malloc.free(_keysPtr);
  }
}

final class YInputYArray extends _YInput {
  YInputYArray(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(this, _valuesPtr.cast(), detach: this);
  }
  final YArray value;

  late final _valuesPtr = malloc<gen.YInput>(value.length);

  @override
  late final gen.YInput _input = () {
    // Could we skip over the intermediate dart objects and convert YOutput
    // structs from yarray_iter_next() into YInput structs?

    final iterator = value.iterator;
    while (iterator.moveNext()) {
      final value = _YInput._(iterator.current);
      _valuesPtr.ref = value._input;
      // keeps the inputs alive for the duration of this input
      _liveInputs.add(value);
    }

    return _bindings.yinput_yarray(_valuesPtr, value.length);
  }();

  @override
  void dispose() {
    super.dispose();
    malloc.free(_valuesPtr);
  }
}

final class YInputYMap extends _YInput {
  YInputYMap(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(this, _keysPtr.cast(), detach: this);
    _YFree.mallocFinalizer.attach(this, _valuesPtr.cast(), detach: this);
    for (final keyPtr in _keysPtrList) {
      _YFree.mallocFinalizer.attach(this, keyPtr.cast(), detach: this);
    }
  }
  final YMap value;

  late final _keysPtr = malloc<ffi.Pointer<ffi.Char>>(value.length);
  late final _valuesPtr = malloc<gen.YInput>(value.length);
  late final _keysPtrList = value //
      .entries
      .map((e) => e.key.toNativeUtf8().cast<ffi.Char>())
      .toList();

  @override
  late final gen.YInput _input = () {
    value.entries.forEachIndexed((index, e) {
      _keysPtr[index] = _keysPtrList[index];
      final valueInput = _YInput._(e.value);
      _liveInputs.add(valueInput);
      _valuesPtr[index] = valueInput._input;
    });

    return _bindings.yinput_ymap(_keysPtr, _valuesPtr, value.length);
  }();

  @override
  void dispose() {
    super.dispose();
    _keysPtrList.forEach(malloc.free);
    malloc.free(_valuesPtr);
    malloc.free(_keysPtr);
  }
}

final class YInputYDoc extends _YInput {
  YInputYDoc(this.value) : super._internal();
  final YDoc value;

  @override
  late final gen.YInput _input = _bindings.yinput_ydoc(value._doc);
}

final class YInputYXmlElem extends _YInput {
  YInputYXmlElem(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(this, _tagPtr.cast(), detach: this);
  }
  final YXmlElement value;

  late final _tagPtr = value.tag.toNativeUtf8();

  @override
  gen.YInput get _input => _bindings.yinput_yxmlelem(_tagPtr.cast());

  @override
  void dispose() {
    super.dispose();
    _YFree.mallocFinalizer.detach(this);
    malloc.free(_tagPtr);
  }
}

final class YInputYXmlText extends _YInput {
  YInputYXmlText(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(this, _ptr.cast(), detach: this);
  }
  final YXmlText value;
  late final _ptr = value.toString().toNativeUtf8();

  @override
  gen.YInput get _input => _bindings.yinput_yxmltext(_ptr.cast());

  @override
  void dispose() {
    super.dispose();
    _YFree.mallocFinalizer.detach(this);
    malloc.free(_ptr);
  }
}

final class YInputYText extends _YInput {
  YInputYText(this.value) : super._internal() {
    _YFree.mallocFinalizer.attach(this, _ptr.cast(), detach: this);
  }
  final YText value;
  late final _ptr = value.toString().toNativeUtf8();
  @override
  gen.YInput get _input => _bindings.yinput_ytext(_ptr.cast());

  @override
  void dispose() {
    super.dispose();
    _YFree.mallocFinalizer.detach(this);
    malloc.free(_ptr);
  }
}
