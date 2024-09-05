part of 'all.dart';

sealed class YValue {}

final class _YOutput extends YValue {
  /// Invoked from [YArray], [YMap]
  static T toObject<T extends Object?>(
    /// Takes ownership of this pointer.
    ffi.Pointer<gen.YOutput> yOutPtr,
    YDoc doc, {
    /// Used to prevent double free of nested types.
    bool disableFree = false,
    ffi.Pointer<gen.YMapEntry>? yMapEntryPtr,
  }) {
    late Object? result;
    final yOut = yOutPtr.ref;

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
        result = YText._(yOut.value.y_type, doc);
        break;
      case gen.Y_ARRAY:
        result = YArray._(doc, yOut.value.y_type);
        break;
      case gen.Y_MAP:
        result = YMap._(doc, yOut.value.y_type);
        break;
      case gen.Y_XML_ELEM:
        result = YXml._(doc, yOut.value.y_type);
        break;
      case gen.Y_XML_TEXT:
        // TODO implement this
        // result = YXmlText._(_doc, _yOutput.value.y_type);
        break;
      case gen.Y_DOC:
        result = YDoc._(yOut.value.y_doc);
        break;
      default:
        throw Exception('Unsupported value type: ${yOut.tag}');
    }

    if ((result is YType || result is YDoc)) {
      if (result is! ffi.Finalizable) {
        throw Exception('Result is not finalizable');
      }
      if (yMapEntryPtr != null) {
        // In rust, YMapEntry implements the Drop trait and calls drop on the
        // value so the outputFinalizer is unnecessary.
        YFree.mapEntryFinalizer.attach(result, yMapEntryPtr.cast<ffi.Void>());
      } else {
        YFree.outputFinalizer.attach(result, yOutPtr.cast<ffi.Void>());
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
    // TODO complete this
    if (value == null) {
      return YInputNull();
    } else if (value is bool) {
      return YInputBool(value);
    } else if (value is double) {
      return YInputFloat(value);
    } else if (value is int) {
      return YInputLong(value);
    } else if (value is String) {
      return YInputString(value);
    } else if (value is Map) {
      // return YInputJsonMap(value);
    }
    throw Exception('Unsupported value type: ${value.runtimeType}');
  }
  gen.YInput get _input;

  void dispose() {}
}

final class YInputNull extends _YInput {
  YInputNull() : super._internal();

  @override
  gen.YInput get _input => _bindings.yinput_null();
}

final class YInputBool extends _YInput {
  YInputBool(this.value) : super._internal();
  final bool value;

  @override
  gen.YInput get _input => _bindings.yinput_bool(value ? 1 : 0);
}

final class YInputFloat extends _YInput {
  YInputFloat(this.value) : super._internal();
  final double value;

  @override
  gen.YInput get _input => _bindings.yinput_float(value);
}

final class YInputLong extends _YInput {
  YInputLong(this.value) : super._internal();
  final int value;

  @override
  gen.YInput get _input => _bindings.yinput_long(value);
}

final class YInputString extends _YInput {
  YInputString(this.value) : super._internal() {
    YFree.mallocFinalizer.attach(this, _ptr.cast<ffi.Void>(), detach: this);
  }
  final String value;

  late final _ptr = value.toNativeUtf8().cast<ffi.Char>();
  @override
  late final gen.YInput _input = _bindings.yinput_string(_ptr);

  @override
  void dispose() {
    YFree.mallocFinalizer.detach(this);
    malloc.free(_ptr);
  }
}

final class YInputJson extends _YInput {
  YInputJson(this.value) : super._internal() {
    YFree.mallocFinalizer.attach(
      this,
      _ptr.cast(),
      externalSize: _ptr.length + 1,
      detach: this,
    );
  }
  final Object value;

  late final _ptr = jsonEncode(value).toNativeUtf8();

  // TODO will we preemptively free before we're done with _input?
  @override
  late final gen.YInput _input = _bindings.yinput_json(_ptr.cast());

  @override
  void dispose() {
    YFree.mallocFinalizer.detach(this);
    malloc.free(_ptr);
  }
}

final class YInputBinary extends _YInput {
  YInputBinary(this.value) : super._internal() {
    YFree.mallocFinalizer.attach(
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
    YFree.mallocFinalizer.detach(this);
    malloc.free(_ptr);
  }
}

final class YInputJsonArray extends _YInput {
  YInputJsonArray(this.value) : super._internal();
  final List<YInputJson> value;

  @override
  late final gen.YInput _input = () {
    final inputs = value.map((e) => e._input).toList();
    final inputPtr = malloc<gen.YInput>(inputs.length);
    for (int i = 0; i < inputs.length; i++) {
      inputPtr[i] = inputs[i];
    }
    final input = _bindings.yinput_json_array(inputPtr, inputs.length);
    malloc.free(inputPtr);
    return input;
  }();
}

final class YInputJsonMap extends _YInput {
  YInputJsonMap(this.value) : super._internal();
  final Map<String, Object?> value;

  @override
  late final gen.YInput _input = () {
    final inputs = value.entries.map((e) {
      final k = e.key;
      final v = e.value;
      final keyPtr = k.toNativeUtf8().cast<ffi.Char>();
      YFree.mallocFinalizer.attach(this, keyPtr.cast<ffi.Void>());
      // Be considerate about keeping these YInput objects alive!
      final valueYInput = _YInput._(v);
      return (keyPtr: keyPtr, value: valueYInput);
    }).toList();

    final keysPtr = malloc<ffi.Pointer<ffi.Char>>(inputs.length);
    YFree.mallocFinalizer.attach(this, keysPtr.cast<ffi.Void>());
    final valuesPtr = malloc<gen.YInput>(inputs.length);
    YFree.mallocFinalizer.attach(this, valuesPtr.cast<ffi.Void>());
    inputs.forEachIndexed((i, pv) {
      keysPtr[i] = pv.keyPtr;
      valuesPtr[i] = pv.value._input;
    });

    final input = _bindings.yinput_json_map(keysPtr, valuesPtr, inputs.length);
    // Manual disposal here prevents `inputs` from being GCd before we call
    // yinput_json_map.
    for (final input in inputs) {
      input.value.dispose();
    }
    return input;
  }();
}

// final class YInputYArray implements YInput {
//   YInputYArray(this.value);
//   final List<YArray> value;

//   @override
//   late final gen.YInput _input = () {
//     final inputs = value.map((e) => e._input).toList();
//     return _bindings.yinput_yarray(inputs);
//   }();
// }

// Float, long, string, json, binary (Uint8List), json_array, json_map, y_array, y_map, y_text, y_doc, weak
