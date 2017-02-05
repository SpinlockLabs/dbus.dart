part of dbus.common;

abstract class DObject {
  String get type;
  dynamic get value;
  String toString();
  dynamic get normalized => value;
}

class DObjectPath extends DObject {
  @override
  final String type = "objpath";

  final String value;

  DObjectPath(this.value);

  @override
  String toString() => value;
}

class DBoolean extends DObject {
  @override
  final String type = "boolean";

  final bool value;

  DBoolean(this.value);

  @override
  String toString() => value.toString();
}

class DInteger extends DObject {
  final String type;
  final int value;

  DInteger(this.value, {this.type: "int32"});

  @override
  String toString() => value.toString();
}

class DArray extends DObject {
  final String elementType;
  final List<DObject> value;

  DArray(this.elementType, this.value);

  @override
  dynamic get normalized {
    if (value.every((x) => x is DEntry)) {
      var m = {};
      for (var e in value) {
        m[(e as DEntry).key.normalized] = (e as DEntry).val.normalized;
      }
      return m;
    } else {
      return value.map((obj) {
        return obj.normalized;
      }).toList();
    }
  }

  @override
  String get type => "array:${elementType}";

  @override
  String toString() => normalized.toString();
}

class DDouble extends DObject {
  final String type = "double";

  final double value;

  DDouble(this.value);

  @override
  String toString() => value.toString();
}

class DString extends DObject {
  @override
  final String type = "string";

  final String value;

  DString(this.value);

  @override
  String toString() => value;
}

class DNull extends DObject {
  final String type;

  DNull([this.type = "null"]);

  final dynamic value = null;

  @override
  String toString() => "null";
}

class DEntry extends DObject {
  @override
  final String type = "dict entry";

  @override
  dynamic get value => [key, val];

  @override
  dynamic get normalized => [key.normalized, val.normalized];

  final DObject key;
  final DObject val;

  DEntry(this.key, this.val);

  @override
  String toString() => "${key}:${val}";
}

DObject parseDObjectFromString(String input) {
  var trimmed = input.trim();
  var n = num.parse(trimmed, (_) => null);

  if (n != null) {
    if (n is double) {
      return new DDouble(n);
    } else if (n is int) {
      return new DInteger(n);
    } else {
      throw new Exception("Unknown number type: ${n}");
    }
  }

  if (trimmed == "boolean true") {
    return new DBoolean(true);
  } else if (trimmed == "boolean false") {
    return new DBoolean(false);
  } else if (trimmed == "null") {
    return new DNull();
  } else if (trimmed.startsWith("array [")) {
    if (trimmed.contains("\n")) {
      var lines = trimmed.split("\n");
      var buffs = [];
      var str = "";
      var inLevel = (input.codeUnits
        .takeWhile((x) => x == 32)
        .length) + 3;
      if (inLevel == 0) {
        inLevel = lines[0].codeUnits.takeWhile((x) => x == 32).length * 2;
      }

      var fparts = [];
      for (var line in lines.sublist(1, lines.length - 1)) {
        if ((line.codeUnits
          .takeWhile((x) => x == 32)
          .length > inLevel) || (const [']', ')']).contains(line.trim())) {
          str += "\n${line}";
        } else {
          if (str.trim().isNotEmpty) {
            buffs.add(parseDObjectFromString(str));
          }
          str = line;
        }
      }

      if (str.trim().isNotEmpty) {
        buffs.add(parseDObjectFromString(str));
        fparts.add(str);
      }

      return new DArray("variant", buffs);
    }

    if (trimmed == "array [") {
      return new DArray("variant", []);
    }

    var look = trimmed.substring("array [".length, trimmed.length - 1);
    List<DObject> items = look.trim().split("    ")
      .map(parseDObjectFromString).toList();
    if (items.isEmpty) {
      return new DArray("variant", []);
    }
    var type = items[0].type;
    return new DArray(type, items);
  } else if (trimmed.startsWith("dict entry(")) {
    var lines = trimmed.split("\n");

    if (lines.length <= 1) {
      return new DNull();
    }

    var firstLine = lines[1];

    String rest;

    if (lines.length > 2) {
      rest = lines.sublist(2, lines.length - 1).join("\n");
    } else {
      rest = "null";
    }

    return new DEntry(
      parseDObjectFromString(firstLine),
      parseDObjectFromString(rest)
    );
  } else if (trimmed.startsWith("variant    ")) {
    trimmed = trimmed.substring(7);
    return parseDObjectFromString(trimmed);
  } else if (trimmed.startsWith("string   ") || trimmed.startsWith('string "')) {
    trimmed = trimmed.substring(6);
    return parseDObjectFromString(trimmed);
  } else if (trimmed.startsWith('"')) {
    return parseDObjectFromString(trimmed.substring(1, trimmed.length - 1));
  } else if (trimmed.startsWith("object path ")) {
    return parseDObjectFromString(trimmed.substring(13, trimmed.length - 1));
  } else if (const [
    "uint64",
    "uint32",
    "int32",
    "int64",
    "int16",
    "uint16",
    "double"
  ].any((x) => trimmed.startsWith(x))) {
    return parseDObjectFromString(trimmed.split(" ").skip(1).join(" "));
  }

  return new DString(trimmed);
}
