import "package:dbus/services/upower.dart";

main() async {
  var power = new PowerService(useSystemBus());
  for (var device in await power.listDevices()) {
    var percentage = await device.getPercentage();
    print("${device.object.name}: ${percentage}%");
  }
}
