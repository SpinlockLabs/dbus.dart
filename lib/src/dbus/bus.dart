part of dbus;

class Bus {
  final bool useSystemBus;
  final String address;
  final String peer;

  Bus({this.useSystemBus: false, this.address, this.peer});

  Future<DObject> invoke(
    String service,
    String path,
    String message,
    List<DObject> args) async {
    if (!path.startsWith("/")) {
      path = "/${path}";
    }

    var argv = <String>[];

    if (useSystemBus) {
      argv.add("--system");
    } else if (address != null) {
      argv.add("--bus=${address}");
    } else if (peer != null) {
      argv.add("--peer=${peer}");
    } else {
      argv.add("--session");
    }

    argv.add("--type=method_call");
    argv.add("--print-reply");
    argv.add("--dest=${service}");
    argv.add(path);
    argv.add(message);

    argv.addAll(args.map((x) {
      return "${x.type}:${x.toString()}";
    }));

    var result = await Process.run("dbus-send", argv);

    if (result.exitCode != 0) {
      throw new Exception(
        "dbus failed with exit code ${result.exitCode}"
          "\n${result.stdout}\n${result.stderr}".trim()
      );
    }

    return parseDObjectFromString(
      result.stdout.toString().split("\n").skip(1).join("\n")
    );
  }

  Future<List<String>> listNames() async {
    List<String> names = (await invoke(
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus.ListNames",
      const []
    )).normalized;

    return names;
  }

  Future<DObject> getProperty(String service, String path, String iface, String name) async {
    var result = await invoke(
      service,
      path,
      "org.freedesktop.DBus.Properties.Get",
      [new DString(iface), new DString(name)]
    );

    return result;
  }

  Future<List<String>> listChildrenNames(String service, String path, {
    String interface
  }) async {
    var node = await introspect(service, path);
    var list = <String>[];

    for (var child in node.children) {
      var full = await introspect(service, child.path);

      if (interface != null && !full.interfaces.any((x) => x.name == interface)) {
        continue;
      }

      list.add(full.name);
    }

    return list;
  }

  Future<List<String>> listServices() async {
    var names = await listNames();

    return names.where((x) => !x.startsWith(":")).toList();
  }

  Future<IntrospectionNode> introspect(String service, [String path = "/"]) async {
    var result = (await invoke(
      service,
      path,
      "org.freedesktop.DBus.Introspectable.Introspect",
      const []
    )).normalized;

    return IntrospectionNode.parseText(result, service, path);
  }

  Service getService(String service) {
    return new Service(this, service);
  }

  Monitor createMonitor(List<String> expressions) {
    return new Monitor(this, expressions);
  }

  ServiceObject getPath(String service, String path) {
    return getService(service).getObject(path);
  }

  Interface getInterface(String service, String path, String iface) {
    return getPath(service, path).getInterface(iface);
  }
}
