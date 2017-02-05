library dbus.services.common;

import "package:dbus/dbus.dart";

Bus useSystemBus() => new Bus(useSystemBus: true);
