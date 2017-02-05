part of dbus;

class Monitor {
  static const List<String> _types = const <String>[
    "signal",
    "error",
    "method"
  ];

  final Bus bus;
  final List<String> expressions;

  Process _process;
  StreamController<MonitorRecord> _records;
  Stream<MonitorRecord> get records => _records.stream;

  Monitor(this.bus, [this.expressions]) {
    _records = new StreamController<MonitorRecord>.broadcast(
      onListen: () {
        start();
      },
      onCancel: () {
        stop();
      }
    );
  }

  Future start() async {
    await stop();

    var args = [];

    if (bus.useSystemBus) {
      args.add("--system");
    } else if (bus.address != null) {
      args.add("--address");
      args.add(bus.address);
    } else {
      args.add("--session");
    }

    if (expressions != null) {
      args.add(expressions.join(","));
    }

    _process = await Process.start("dbus-monitor", args);

    _process.stdout.listen((bytes) {
      var str = UTF8.decode(bytes);

      var lines = str.split("\n");
      var sec = null;

      for (var line in lines) {
        if (sec == null) {
          sec = line;
        } else if (_types.any((x) => line.startsWith("${x} "))) {
          if (sec.isNotEmpty) {
            _parse(sec.trim());
            sec = line;
          }
        } else {
          sec += "\n${line}";
        }
      }

      sec = sec.trim();
      if (sec.isNotEmpty) {
        _parse(sec);
      }
    });
  }

  void _parse(String str) {
    if (!_types.any((x) => str.startsWith("${x} "))) {
      return;
    }
    var lines = str.split("\n");
    var firstLine = lines.first;
    var parts = firstLine.split(";");
    var rparts = parts.first.split("=");
    var path = rparts.last;
    var sender = rparts[2].split(" ")[0];
    var destination = firstLine
      .split("destination=")[1]
      .split("serial=")
      .first.trim();
    var iface = parts[1].split("=").last;
    var member = parts[2].split("=").last;

    var sections = [];

    for (var l in lines.sublist(1)) {
      if (sections.isNotEmpty && (l.startsWith("    ") || l.trim() == "]")) {
        sections[sections.length - 1] = sections.last + "\n" + l;
      } else if (l.trim().isEmpty) {
      } else {
        sections.add(l);
      }
    }

    var record = new MonitorRecord(
      sender,
      destination,
      path,
      iface,
      member,
      sections.map(parseDObjectFromString).toList()
    );

    _records.add(record);
  }

  Future stop() async {
    if (_process != null) {
      _process.kill();
      _process = null;
    }
  }
}

class MonitorRecord {
  final String sender;
  final String destination;
  final String path;
  final String interface;
  final String member;

  final List<DObject> arguments;

  MonitorRecord(
    this.sender,
    this.destination,
    this.path,
    this.interface,
    this.member,
    this.arguments);

  @override
  String toString() => "Record(${sender} -> ${destination} at ${path} on ${interface} as ${member} with ${arguments})";
}
