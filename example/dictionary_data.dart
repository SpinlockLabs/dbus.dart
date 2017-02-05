import "package:dbus/dbus.dart";

const String _input = """
""";

main() {
  var list = parseDObjectFromString(_input).normalized;
  print(list);
}
