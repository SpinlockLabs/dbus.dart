import "package:dbus/dbus.dart";
import "package:dbus/services/bluez.dart";

final Bus bus = new Bus(useSystemBus: true);

main() async {
  var bluez = new BluetoothService(bus);
  var adapter = await bluez.getDefaultAdapter();

  adapter.events().listen((AdapterEvent event) async {
    if (event is DeviceAddedEvent) {
      var address = await event.device.getAddress();
      print("Device Added: ${address}");
    } else if (event is DeviceRemovedEvent) {
      print("Device Removed: ${event.address}");
    } else if (event is AdapterDiscoveringStateChangedEvent) {
      if (event.isDiscovering) {
        print("Discovering...");
      } else {
        print("Discovering Complete.");
      }
    } else if (event is DeviceConnectionStateChangedEvent) {
      var state = event.isConnected;

      if (state) {
        print("Device Connected: ${await event.device.getAddress()}");
      } else {
        print("Device Disconnected: ${await event.device.getAddress()}");
      }
    }
  });
}
