part of dbus;

class IntrospectionNode {
  final String name;
  final List<IntrospectionInterface> interfaces;
  final List<IntrospectionNode> children;
  final String service;
  final String path;

  IntrospectionNode(this.name, this.interfaces, this.children, [
    this.service,
    this.path
  ]);

  bool get isPopulated => name == null;

  static IntrospectionNode parse(Xml.XmlElement e, [String service, String path]) {
    var interfaces = e
      .findElements("interface")
      .map(IntrospectionInterface.parse)
      .toList();

    var rmnp = path == null ? "/" : path;

    if (!rmnp.endsWith("/")) {
      rmnp += "/";
    }

    var children = e
      .findElements("node")
      .map((e) => IntrospectionNode.parse(e, service, rmnp + e.getAttribute("name")))
      .toList();

    var name = e.getAttribute("name");

    if (path != null) {
      name = path.split("/").last;
    }

    return new IntrospectionNode(
      name,
      interfaces,
      children,
      service,
      path
    );
  }

  static IntrospectionNode parseText(input, [String service, String path]) {
    if (input is DObject) {
      input = input.normalized;
    }

    if (input is! String) {
      input = input.toString();
    }

    return IntrospectionNode.parse(
      Xml.parse(input).findElements("node").first,
      service,
      path
    );
  }

  @override
  String toString() {
    var str = "node(${name == null ? '' : name}) {";

    if (interfaces.isNotEmpty || children.isNotEmpty) {
      str += "\n";

      for (var iface in interfaces) {
        str += "  ${iface.toString(2)}\n";
      }

      for (var node in children) {
        str += "  ${node}\n";
      }
    }
    str += "}";
    return str;
  }
}

class IntrospectionInterface {
  final String name;
  final List<IntrospectionMethod> methods;
  final List<IntrospectionProperty> properties;

  IntrospectionInterface(this.name, this.methods, this.properties);

  static IntrospectionInterface parse(Xml.XmlElement e) {
    var name = e.getAttribute("name");
    var methods = e
      .findElements("method")
      .map(IntrospectionMethod.parse)
      .toList();
    var properties = e
      .findElements("property")
      .map(IntrospectionProperty.parse)
      .toList();
    return new IntrospectionInterface(name, methods, properties);
  }

  @override
  String toString([int indent = 0]) {
    var buff = new StringBuffer();
    buff.writeln("interface(${name}) {");

    for (var method in methods) {
      buff.writeln("${' ' * indent}  ${method}");
    }

    buff.writeln("${' ' * indent}}");
    return buff.toString().trim();
  }
}

class IntrospectionMethod {
  final String name;

  IntrospectionMethod(this.name);

  static IntrospectionMethod parse(Xml.XmlElement e) {
    var name = e.getAttribute("name");

    return new IntrospectionMethod(name);
  }

  @override
  String toString() => "method(${name})";
}

class IntrospectionProperty {
  final String name;

  IntrospectionProperty(this.name);

  static IntrospectionProperty parse(Xml.XmlElement e) {
    return new IntrospectionProperty(e.getAttribute("name"));
  }

  @override
  String toString() => "property(${name})";
}
