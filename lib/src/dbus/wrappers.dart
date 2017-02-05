part of dbus;

class Service {
  final Bus bus;
  final String name;

  Service(this.bus, this.name);

  Future<DObject> invoke(String path, String interface, String method, List<DObject> args) async {
    return await bus.invoke(name, path, "${interface}.${method}", args);
  }

  Future<DObject> getProperty(String path, String interface, String property) async {
    return await bus.getProperty(name, path, interface, property);
  }

  Future<List<String>> listChildrenNames(String path, {
    String interface
  }) async {
    return await bus.listChildrenNames(name, path, interface: interface);
  }

  ServiceObject getObject(String path) => new ServiceObject(this, path);
  Interface getInterface(String path, String iface) => getObject(path)
    .getInterface(iface);

  Monitor createMonitor(List<String> expressions) {
    var expr = new List<String>.from(expressions);
    expr.add("sender='${name}'");
    return bus.createMonitor(expr);
  }

  Future<bool> exists() async {
    try {
      await bus.introspect(name);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Service> verify() async {
    if (!(await exists())) {
      throw new Exception("Service ${name} does not exist.");
    }
    return this;
  }
}

class ServiceObject {
  final Service service;
  final String path;

  String get name => path.substring(path.lastIndexOf("/") + 1);

  ServiceObject(this.service, this.path);

  Future<DObject> invoke(String interface, String method, List<DObject> args) async {
    return await service.invoke(path, interface, method, args);
  }

  Future<DObject> getProperty(String interface, String property) async {
    return await service.getProperty(path, interface, property);
  }

  Future<List<String>> listChildNames({
    String interface
  }) async {
    return await service.listChildrenNames(path, interface: interface);
  }

  Interface getInterface(String name) => new Interface(this, name);

  Monitor createMonitor(List<String> expressions) {
    var expr = new List<String>.from(expressions);
    expr.add("path='${path}'");
    return service.createMonitor(expr);
  }

  Future<bool> exists() async {
    try {
      await service.bus.introspect(service.name, path);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<ServiceObject> verify() async {
    if (!(await exists())) {
      throw new Exception(
        "Object ${path} does not exist on service ${service.name}"
      );
    }
    return this;
  }
}

class Interface {
  final String name;
  final ServiceObject object;

  Interface(this.object, this.name);

  Future<DObject> invoke(String method, List<DObject> args) async {
    return await object.invoke(name, method, args);
  }

  Future<DObject> getProperty(String property) async {
    return await object.getProperty(name, property);
  }

  Future<dynamic> readProperty(String property) async {
    return (await getProperty(property)).normalized;
  }

  Future<Map<String, dynamic>> readProperties(List<String> properties) async {
    var m = <String, dynamic>{};
    for (var name in properties) {
      m[name] = await readProperty(name);
    }
    return m;
  }

  Future<Map<String, dynamic>> readAllProperties() async {
    return (await object.invoke("org.freedesktop.DBus.Properties", "GetAll", [
      new DString(name)
    ])).normalized;
  }

  Monitor createMonitor(List<String> expressions) {
    var expr = new List<String>.from(expressions);
    expr.add("interface='${name}'");
    return object.createMonitor(expr);
  }

  Future<bool> exists() async {
    try {
      var node = await object.service.bus.introspect(
        object.service.name,
        object.path
      );
      return node.interfaces.any((i) => i.name != name);
    } catch (e) {
      return false;
    }
  }

  Stream<dynamic> watchProperty(String name) async* {
    var monitor = object.createMonitor([
      "interface='org.freedesktop.DBus.Properties'"
      "member='PropertiesChanged'"
    ]);

    await for (var record in monitor.records) {
      if (record.member != "PropertiesChanged") {
        continue;
      }

      Map m = record.arguments[1].normalized;
      if (m.containsKey(name)) {
        yield m[name];
      }
    }
  }

  Future<Interface> verify() async {
    if (!(await exists())) {
      throw new Exception(
        "Object ${object.path} does not have the"
          " interface ${name} on service ${object.service.name}"
      );
    }
    return this;
  }
}
