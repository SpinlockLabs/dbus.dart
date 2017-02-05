import "package:dbus/dbus.dart";
import "dart:convert" show JsonEncoder;

main() async {
  var bus = new Bus(useSystemBus: true);

  encode(x) {
    var n = {};

    if (x is IntrospectionNode) {
      for (var iface in x.interfaces) {
        n[iface.name] = encode(iface);
      }

      var i = 1;
      for (var c in x.children) {
        n[c.name == null ? '${i.toString()}' : c.name] = encode(c);
        i++;
      }
    } else if (x is IntrospectionInterface) {
      n["name"] = x.name;
      n["methods"] = x.methods.map(encode).toList();
    } else if (x is IntrospectionMethod) {
      n["name"] = x.name;
    }

    return n;
  }

  buildCombinedTree(IntrospectionNode root) {
    var out = {};

    visit(IntrospectionNode node) {
      var m = out[node.path] = {};
      for (var iface in node.interfaces) {
        for (var method in iface.methods) {
          m["${iface.name}/${method.name}"] = {
            "type": "method",
            "name": method.name
          };
        }

        for (var prop in iface.properties) {
          m["${iface.name}/${prop.name}"] = {
            "type": "property",
            "name": prop.name
          };
        }
      }

      for (var c in node.children) {
        visit(c);
      }
    }

    visit(root);

    return out;
  }

  rebuildTree(IntrospectionNode node) async {
    if (!node.isPopulated) {
      node = await bus.introspect(node.service, node.path);
    }

    var childs = [];
    for (var c in node.children) {
      childs.add(await rebuildTree(c));
    }

    return new IntrospectionNode(
      node.name,
      node.interfaces,
      childs,
      node.service,
      node.path
    );
  }

  var out = {};

  for (var service in await bus.listServices()) {
    try {
      var node = await rebuildTree(
        await bus.introspect(service)
      );

      var x = buildCombinedTree(node);
      out[service] = x;
    } catch (e) {
    }
  }

  print(new JsonEncoder.withIndent("  ", (x) {
    return x;
  }).convert(out));
}
