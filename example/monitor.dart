import "package:dbus/dbus.dart";

main() async {
  var bus = new Bus(useSystemBus: true);
  var monitor = new Monitor(bus);

  await for (var record in monitor.records) {
    print(record);
  }
}
