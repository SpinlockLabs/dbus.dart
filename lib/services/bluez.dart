library dbus.services.bluez;

import "dart:async";

import "package:dbus/dbus.dart";
export "common.dart";

class BluetoothService {
  final Service service;

  BluetoothService(Bus bus) : service = bus.getService("org.bluez");

  Future<BluetoothAdapter> getAdapterByName(String name) async {
    var adapterObject = await service
      .getObject("/org/bluez/${name}")
      .verify();

    var adapter = new BluetoothAdapter(adapterObject);

    if (!(await adapter.exists())) {
      throw new Exception("Adapter with name ${name} does not exist.");
    }

    return adapter;
  }

  Future<BluetoothAdapter> getDefaultAdapter() async {
    var adapters = await getAdapters();

    if (adapters.isEmpty) {
      throw new Exception("No adapter available.");
    }

    return adapters.first;
  }

  Future<List<BluetoothAdapter>> getAdapters() async {
    var children = await service.getObject("/org/bluez").listChildNames(
      interface: "org.bluez.Adapter1"
    );

    var list = <BluetoothAdapter>[];

    for (var name in children) {
      list.add(await getAdapterByName(name));
    }

    return list;
  }
}

abstract class AdapterEvent {
  final BluetoothAdapter adapter;

  AdapterEvent(this.adapter);
}

class DeviceAddedEvent extends AdapterEvent {
  final BluetoothDevice device;

  DeviceAddedEvent(BluetoothAdapter adapter, this.device) : super(adapter);
}

class DeviceRemovedEvent extends AdapterEvent {
  final String address;

  DeviceRemovedEvent(BluetoothAdapter adapter, this.address) : super(adapter);
}

class DeviceConnectionStateChangedEvent extends AdapterEvent {
  final BluetoothDevice device;
  final bool isConnected;

  DeviceConnectionStateChangedEvent(
    BluetoothAdapter adapter,
    this.device,
    this.isConnected) :
      super(adapter);
}

class MediaControlConnectionStateChangedEvent extends AdapterEvent {
  final BluetoothDevice device;
  final bool isConnected;

  MediaControlConnectionStateChangedEvent(
    BluetoothAdapter adapter,
    this.device,
    this.isConnected) :
      super(adapter);
}

class AdapterDiscoveringStateChangedEvent extends AdapterEvent {
  final bool isDiscovering;

  AdapterDiscoveringStateChangedEvent(BluetoothAdapter adapter, this.isDiscovering) :
      super(adapter);
}

class BluetoothAdapter {
  final ServiceObject object;

  Interface _adapter;

  BluetoothAdapter(this.object) {
    _adapter = object.getInterface("org.bluez.Adapter1");
  }

  Future<bool> exists() async {
    return await object.exists() && await _adapter.exists();
  }

  Future<String> getName() async => await _adapter.readProperty("Name");
  Future<String> getAddress() async => await _adapter.readProperty("Address");

  Future<bool> isDiscoverable() async =>
    await _adapter.readProperty("Discoverable");

  Future<bool> isDiscovering() async =>
    await _adapter.readProperty("Discovering");

  Future<List<String>> listUuids() async =>
    await _adapter.readProperty("UUIDs");

  Future<bool> isPairable() async =>
    await _adapter.readProperty("Pairable");

  Future<bool> isPowered() async =>
    await _adapter.readProperty("Powered");

  Future<List<BluetoothDevice>> listDevices() async {
    var children = await object.listChildNames(interface: "org.bluez.Device1");
    var list = <BluetoothDevice>[];
    for (var name in children) {
      list.add(new BluetoothDevice(
        await object
          .service
          .getObject("${object.path}/${name}")
          .verify()
      ));
    }
    return list;
  }

  Future<BluetoothDevice> getDeviceByAddress(String address) async {
    var objectName = "dev_${address.replaceAll(':', '_')}";
    var devObject = await object
      .service
      .getObject("${object.path}/${objectName}")
      .verify();

    var device = new BluetoothDevice(devObject);

    if (!(await device.exists())) {
      throw new Exception("Device with address ${address} does not exist.");
    }

    return device;
  }

  Future startDiscovery() async {
    await _adapter.invoke("StartDiscovery", const []);
  }

  Future stopDiscovery() async {
    await _adapter.invoke("StopDiscovery", const []);
  }

  Stream<AdapterEvent> events() async* {
    await for (var record in _adapter.object.service.createMonitor([]).records) {
      if (record.interface != "org.freedesktop.DBus.Properties") {
        continue;
      }

      if (record.member == "InterfacesAdded") {
        var map = record.arguments[1].normalized;
        if (map["org.bluez.Device1"] is Map) {
          var address = map["org.bluez.Device1"]["Address"];

          if (address is String) {
            yield new DeviceAddedEvent(this, await getDeviceByAddress(address));
          }
        }
      } else if (record.member == "InterfacesRemoved") {
        if (record.arguments[1].normalized.contains("org.bluez.Device")) {
          var name = record
            .arguments[0]
            .toString()
            .split("/")
            .last
            .substring(4)
            .replaceAll("_", ":");

          yield new DeviceRemovedEvent(this, name);
        }
      } else if (record.member == "PropertiesChanged" &&
        record.arguments[0].normalized == "org.bluez.Adapter1" &&
        record.arguments[1].normalized["Discovering"] is bool) {
        var discovering = record.arguments[1].normalized["Discovering"] == true;

        yield new AdapterDiscoveringStateChangedEvent(this, discovering);
      } else if (record.member == "PropertiesChanged" &&
        record.arguments[0].normalized == "org.bluez.Device1" &&
        record.arguments[1].normalized["Connected"] is bool) {
        var devObject = await object
          .service
          .getObject(record.path)
          .verify();

        var device = new BluetoothDevice(devObject);

        yield new DeviceConnectionStateChangedEvent(
          this,
          device,
          record.arguments[1].normalized["Connected"] == true
        );
      } else if (record.member == "PropertiesChanged" &&
        record.arguments[0].normalized == "org.bluez.MediaControl1" &&
        record.arguments[1].normalized["Connected"] is bool) {
        var devObject = await object
          .service
          .getObject((record.path.split("/")..removeLast()).join("/"))
          .verify();

        var device = new BluetoothDevice(devObject);

        yield new MediaControlConnectionStateChangedEvent(
          this,
          device,
          record.arguments[1].normalized["Connected"] == true
        );
      }
    }
  }
}

class BluetoothDevice {
  final ServiceObject object;

  Interface _device;

  BluetoothDevice(this.object) {
    _device = object.getInterface("org.bluez.Device1");
  }

  Future<bool> exists() async {
    return await object.exists() && await _device.exists();
  }

  Future<String> getName() async => await _device.readProperty("Name");

  Future<String> getAlias() async => await _device.readProperty("Alias");
  Future<String> getAddress() async => await _device.readProperty("Address");

  Future<bool> isPaired() async => await _device.readProperty("Paired");
  Future<bool> isTrusted() async => await _device.readProperty("Trusted");
  Future<bool> isBlocked() async => await _device.readProperty("Blocked");
  Future<bool> isConnected() async => await _device.readProperty("Connected");

  Future<bool> areServicesResolved() async =>
    await _device.readProperty("ServicesResolved");

  Future<List<String>> listUuids() async => await _device.readProperty("UUIDs");

  Future<BluetoothAdapter> getAdapter() async {
    return new BluetoothAdapter(
      _device.object.service.getObject(await _device.readProperty("Adapter"))
    );
  }

  Future connect() async => await _device.invoke("Connect", const []);
  Future disconnect() async => await _device.invoke("Disconnect", const []);

  Future connectProfile(String uuid) async => await _device.invoke("ConnectProfile", [
    new DString(uuid)
  ]);

  Future disconnectProfile(String uuid) async => await _device.invoke("DisconnectProfile", [
    new DString(uuid)
  ]);

  Future<MediaControl> getMediaControl() async {
    var control = new MediaControl(object);

    if (!(await control.exists())) {
      throw new Exception("Device does not have Media Control support.");
    }

    return control;
  }

  Future pair() async => await _device.invoke("Pair", const []);
  Future cancelPairing() async =>
    await _device.invoke("CancelPairing", const []);
}

class MediaPlayer {
  final ServiceObject object;

  Interface _player;

  MediaPlayer(this.object) {
    _player = object.getInterface("org.bluez.MediaPlayer1");
  }

  Future<bool> exists() async {
    return await _player.exists();
  }

  Future play() async {
    await _player.invoke("Play", const []);
  }

  Future stop() async {
    await _player.invoke("Stop", const []);
  }

  Future pause() async {
    await _player.invoke("Pause", const []);
  }

  Future next() async {
    await _player.invoke("Next", const []);
  }

  Future previous() async {
    await _player.invoke("Previous", const []);
  }

  Future fastForward() async {
    await _player.invoke("FastForward", const []);
  }

  Future rewind() async {
    await _player.invoke("Rewind", const []);
  }

  Future<TrackInfo> getTrackInfo() async {
    var result = (await _player.getProperty("Track")).normalized;

    return TrackInfo.decode(result);
  }
}

class MediaControl {
  final ServiceObject object;

  Interface _player;

  MediaControl(this.object) {
    _player = object.getInterface("org.bluez.MediaControl1");
  }

  Future<bool> exists() async {
    return await _player.exists();
  }

  Future play() async {
    await _player.invoke("Play", const []);
  }

  Future stop() async {
    await _player.invoke("Stop", const []);
  }

  Future pause() async {
    await _player.invoke("Pause", const []);
  }

  Future next() async {
    await _player.invoke("Next", const []);
  }

  Future previous() async {
    await _player.invoke("Previous", const []);
  }

  Future fastForward() async {
    await _player.invoke("FastForward", const []);
  }

  Future rewind() async {
    await _player.invoke("Rewind", const []);
  }

  Future increaseVolume() async {
    await _player.invoke("VolumeUp", const []);
  }

  Future decreaseVolume() async {
    await _player.invoke("VolumeDown", const []);
  }

  Future<bool> isConnected() async {
    return await _player.readProperty("Connected");
  }

  Future<MediaPlayer> getMediaPlayer() async {
    var path = await _player.readProperty("Player");

    return new MediaPlayer(object.service.getObject(path));
  }
}

class TrackInfo {
  final String title;
  final String artist;
  final String album;

  TrackInfo({
    this.title,
    this.album,
    this.artist
  });

  static TrackInfo decode(Map<String, dynamic> map) {
    return new TrackInfo(
      title: map["Title"],
      album: map["Album"],
      artist: map["Artist"]
    );
  }

  @override
  String toString() => "${title} by ${artist}";
}
