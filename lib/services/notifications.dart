library dbus.services.notifications;

import "package:dbus/dbus.dart";
export "common.dart";

class NotificationService {
  final Bus bus;

  Service _notify;

  NotificationService(this.bus) {
    _notify = bus.getService("org.freedesktop.Notifications");
  }
}
