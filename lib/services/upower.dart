library dbus.services.upower;

import "dart:async";

import "package:dbus/dbus.dart";
export "common.dart";

abstract class PowerEvent {
}

class DeviceAttachedEvent extends PowerEvent {
  final Device device;

  DeviceAttachedEvent(this.device);
}

class DeviceRemovedEvent {
  final String name;

  DeviceRemovedEvent(this.name);
}

class PowerService {
  final Bus bus;

  Service _service;
  Interface _power;

  PowerService(this.bus) {
    _service = bus.getService("org.freedesktop.UPower");
    _power = _service.getInterface("/", "org.freedesktop.UPower");
  }

  Future<Device> getDeviceByName(String name) async {
    var device = new Device(
      await _service
        .getObject("/org/freedesktop/UPower/devices/${name}")
        .verify()
    );

    return device;
  }

  Future<List<Device>> listDevices() async {
    var children = await _service.listChildrenNames(
      "/org/freedesktop/UPower/devices",
      interface: "org.freedesktop.UPower.Device"
    );

    var list = <Device>[];
    for (var child in children) {
      list.add(await getDeviceByName(child));
    }

    return list;
  }

  Future<bool> isOnBattery() async => await _power.readProperty("OnBattery");
  Future<bool> isLidClosed() async => await _power.readProperty("LidIsClosed");
  Future<bool> isLidPresent() async => await _power.readProperty("LidIsPresent");
}

class Device {
  final ServiceObject object;

  Interface _device;

  Device(this.object) {
    _device = object.getInterface("org.freedesktop.UPower.Device");
  }

  Future<String> getNativePath() async => await _device.readProperty("NativePath");
  Future<int> getPercentage() async => await _device.readProperty("Percentage");
  Future<bool> isOnline() async => await _device.readProperty("Online");
  Future<bool> isPowerSupply() async => await _device.readProperty("PowerSupply");
}
